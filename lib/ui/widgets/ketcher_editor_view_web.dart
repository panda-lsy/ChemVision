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
    // 不在 didUpdateWidget 中调用 setMolecule，避免 Ketcher 规范化 SMILES 后的反馈循环
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
      // 时间戳防缓存
      final ts = DateTime.now().millisecondsSinceEpoch;
      final iframe = html.IFrameElement()
        ..src = 'assets/assets/web/ketcher/index.html?channel=$_channel$_themeParam&_t=$ts'
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
      triggerSave: () {
        _postMessage('triggerSave', {});
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
    if (data is! Map) return;

    // 处理 Ketcher 源码发送的 init 事件（无 channel）
    if (data['eventType'] == 'init') {
      _pageReady = true;
      _ensureController();
      final mode = widget.themeMode == ThemeMode.dark ? 'dark' : 'light';
      _postMessage('setTheme', {'mode': mode});
      if (widget.initialSmiles.isNotEmpty) {
        _postMessage('setMolecule', {'data': widget.initialSmiles});
      }
      if (widget.readOnly) {
        _postMessage('setReadOnly', {'readOnly': true});
      }
      return;
    }

    // 处理源码级 SMILES 轮询更新（无 channel）
    if (data['type'] == 'onSmilesUpdated' && data['payload'] is Map) {
      final smiles = data['payload']['smiles']?.toString();
      if (smiles != null && smiles.isNotEmpty) {
        widget.onSmilesUpdated?.call(smiles);
      }
      return;
    }

    // 处理带 channel 的消息
    if (data['channel'] != _channel) return;
    final type = data['type'];
    final payload = data['payload'];

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

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
