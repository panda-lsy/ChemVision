import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'jsme_editor_controller.dart';

class JsmeEditorView extends StatefulWidget {
  const JsmeEditorView({
    super.key,
    required this.smiles,
    this.themeMode = 'dark',
    this.onSmilesUpdated,
    this.onControllerReady,
    this.onError,
    this.onDebugLog,
  });

  final String smiles;
  final String themeMode;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<JsmeEditorController>? onControllerReady;
  final ValueChanged<String>? onError;
  final ValueChanged<String>? onDebugLog;

  @override
  State<JsmeEditorView> createState() => _JsmeEditorViewState();
}

class _JsmeEditorViewState extends State<JsmeEditorView> {
  late final String _channel;
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;
  JsmeEditorController? _controller;
  bool _pageReady = false;
  final Map<String, Completer<String?>> _pending = {};

  void _markPageReady() {
    if (_pageReady || !mounted) return;
    setState(() {
      _pageReady = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _channel = 'chemvision-jsme-${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'chemvision-jsme-view-$_channel';
    _registerViewFactory();
    _messageSub = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant JsmeEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smiles != widget.smiles && _pageReady) {
      _postMessage('setSmiles', {'smiles': widget.smiles});
    }
    if (oldWidget.themeMode != widget.themeMode && _pageReady) {
      _postMessage('setTheme', {'mode': widget.themeMode});
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  void _registerViewFactory() {
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final theme = widget.themeMode.toLowerCase() == 'light' ? 'light' : 'dark';
      final iframe = html.IFrameElement()
        ..src = 'assets/web/editor_jsme.html?channel=$_channel&theme=$theme'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      iframe.onLoad.listen((_) {
        _markPageReady();
        _ensureController();
        _postMessage('setSmiles', {'smiles': widget.smiles});
        _postMessage('setTheme', {'mode': widget.themeMode});
      });
      _iframe = iframe;
      return iframe;
    });
  }

  void _ensureController() {
    if (_controller != null) return;
    _controller = JsmeEditorController(
      setSmiles: (smiles) async {
        _postMessage('setSmiles', {'smiles': smiles});
      },
      getSmiles: () async {
        final requestId = DateTime.now().microsecondsSinceEpoch.toString();
        final completer = Completer<String?>();
        _pending[requestId] = completer;
        _postMessage('getSmilesRequest', {'requestId': requestId});
        return completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      },
    );
    widget.onControllerReady?.call(_controller!);
  }

  void _postMessage(String type, Map<String, dynamic> payload) {
    final target = _iframe?.contentWindow;
    if (target == null) return;
    target.postMessage({
      'channel': _channel,
      'type': type,
      'payload': payload,
    }, '*');
  }

  void _handleMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! Map || data['channel'] != _channel) return;
    final type = data['type'];
    final payload = data['payload'];
    if (type == 'onBridgeReady') {
      _markPageReady();
      _postMessage('setSmiles', {'smiles': widget.smiles});
      _postMessage('setTheme', {'mode': widget.themeMode});
      return;
    }
    if (type == 'onSmilesUpdated' && payload is Map) {
      final smiles = payload['smiles']?.toString();
      if (smiles != null) {
        widget.onSmilesUpdated?.call(smiles);
      }
      return;
    }
    if (type == 'onEditorActionError' && payload is Map) {
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        widget.onError?.call(message);
      }
      return;
    }
    if (type == 'onDebugLog' && payload is Map) {
      final ts = payload['ts']?.toString() ?? '';
      final level = payload['level']?.toString() ?? 'info';
      final message = payload['message']?.toString() ?? '';
      final extra = payload['extra'];
      debugPrint(
        '[JSME][web][$level] $ts $message${extra == null ? '' : ' | $extra'}',
      );
      widget.onDebugLog?.call(
        '[web][$level] $ts $message${extra == null ? '' : ' | $extra'}',
      );
      return;
    }
    if (type == 'getSmilesResult' && payload is Map) {
      final requestId = payload['requestId']?.toString();
      final smiles = payload['smiles']?.toString();
      final completer = requestId == null ? null : _pending.remove(requestId);
      completer?.complete(smiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Stack(
        children: [
          HtmlElementView(viewType: _viewType),
          if (!_pageReady)
            Positioned.fill(
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : AppColors.dayBluePrimary.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
