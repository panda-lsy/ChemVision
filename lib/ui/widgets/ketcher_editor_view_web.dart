import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import 'ketcher_editor_controller.dart';

class KetcherEditorView extends StatefulWidget {
  const KetcherEditorView({
    super.key,
    this.initialSmiles = '',
    this.onControllerReady,
    this.onSmilesUpdated,
    this.onError,
    this.readOnly = false,
    this.themeMode = ThemeMode.dark,
  });

  final String initialSmiles;
  final ValueChanged<KetcherEditorController>? onControllerReady;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<String>? onError;
  final bool readOnly;
  final ThemeMode themeMode;

  @override
  State<KetcherEditorView> createState() => _KetcherEditorViewState();
}

class _KetcherEditorViewState extends State<KetcherEditorView> {
  late final String _channel;
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;
  KetcherEditorController? _controller;
  bool _pageReady = false;
  final Map<String, Completer<String?>> _pending = {};

  @override
  void initState() {
    super.initState();
    _channel = 'chemvision-ketcher-${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'chemvision-ketcher-$_channel';
    _registerViewFactory();
    _messageSub = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant KetcherEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSmiles != widget.initialSmiles && _pageReady) {
      _postMessage('setMolecule', {'data': widget.initialSmiles});
    }
    // 主题变化时通知 iframe
    if (oldWidget.themeMode != widget.themeMode && _pageReady) {
      final mode = widget.themeMode == ThemeMode.dark ? 'dark' : 'light';
      _postMessage('setTheme', {'mode': mode});
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  String get _themeParam {
    final mode = widget.themeMode == ThemeMode.dark ? 'dark' : 'light';
    return '&theme=$mode';
  }

  void _registerViewFactory() {
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'assets/assets/web/ketcher/index.html?channel=$_channel$_themeParam'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      _iframe = iframe;
      return iframe;
    });
  }

  void _ensureController() {
    if (_controller != null) return;
    _controller = KetcherEditorController(
      setMolecule: (data) async {
        _postMessage('setMolecule', {'data': data});
      },
      getSmiles: () async {
        final requestId = DateTime.now().microsecondsSinceEpoch.toString();
        final completer = Completer<String?>();
        _pending[requestId] = completer;
        _postMessage('getSmiles', {'requestId': requestId});
        return completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      },
      getRxn: () async {
        final requestId = DateTime.now().microsecondsSinceEpoch.toString();
        final completer = Completer<String?>();
        _pending[requestId] = completer;
        _postMessage('getRxn', {'requestId': requestId});
        return completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      },
      exportSvg: ({String? data}) async {
        final completer = Completer<String?>();
        late StreamSubscription sub;
        sub = html.window.onMessage.listen((event) {
          final d = event.data;
          if (d is Map &&
              d['channel'] == _channel &&
              d['type'] == 'exportSvgResult') {
            completer.complete(d['payload']?['svgString'] as String?);
            sub.cancel();
          }
        });
        _postMessage('exportSvg', {'data': data});
        return completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      },
      exportPng: ({String? data}) async {
        final completer = Completer<String?>();
        late StreamSubscription sub;
        sub = html.window.onMessage.listen((event) {
          final d = event.data;
          if (d is Map &&
              d['channel'] == _channel &&
              d['type'] == 'exportPngResult') {
            completer.complete(d['payload']?['dataUrl'] as String?);
            sub.cancel();
          }
        });
        _postMessage('exportPng', {'data': data});
        return completer.future.timeout(
          const Duration(seconds: 5),
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
      _pageReady = true;
      _ensureController();
      // 通知主题
      final mode = widget.themeMode == ThemeMode.dark ? 'dark' : 'light';
      _postMessage('setTheme', {'mode': mode});
      // 延迟传入 SMILES，等待 Ketcher 内部 Redux store 完全就绪
      if (widget.initialSmiles.isNotEmpty) {
        _sendSmilesWithRetry(widget.initialSmiles, retries: 3);
      }
      if (widget.readOnly) {
        _postMessage('setReadOnly', {'readOnly': true});
      }
      return;
    }

    if (type == 'onSetMoleculeSuccess' && payload is Map) {
      final smiles = payload['smiles']?.toString();
      if (smiles != null && smiles.isNotEmpty) {
        widget.onSmilesUpdated?.call(smiles);
      }
      return;
    }

    if (type == 'onSmilesUpdated' && payload is Map) {
      final smiles = payload['smiles']?.toString();
      if (smiles != null && smiles.isNotEmpty) {
        widget.onSmilesUpdated?.call(smiles);
      }
      return;
    }

    if (type == 'onError' && payload is Map) {
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        widget.onError?.call(message);
      }
      return;
    }

    if (type == 'getSmilesResult' && payload is Map) {
      final requestId = payload['requestId']?.toString();
      final smiles = payload['smiles']?.toString();
      final completer = requestId == null ? null : _pending.remove(requestId);
      completer?.complete(smiles);
      return;
    }

    if (type == 'getRxnResult' && payload is Map) {
      final requestId = payload['requestId']?.toString();
      final rxn = payload['rxn']?.toString();
      final completer = requestId == null ? null : _pending.remove(requestId);
      completer?.complete(rxn);
      return;
    }
  }

  /// 带重试的 SMILES 传入
  void _sendSmilesWithRetry(String smiles, {int retries = 3}) {
    var attempt = 0;
    void trySend() {
      attempt++;
      _postMessage('setMolecule', {'data': smiles});
      // 等待确认，如果 2s 内没有成功确认且还有重试次数，则重试
      if (attempt < retries) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _pageReady) {
            // 检查是否已收到成功确认（通过 _lastSmilesUpdated 判断）
            trySend();
          }
        });
      }
    }
    // 首次延迟 2s 等待 Redux store 就绪
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) trySend();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
