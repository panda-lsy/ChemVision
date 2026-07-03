import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
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
  InAppWebViewController? _webViewController;
  KetcherEditorController? _controller;
  bool _ready = false;

  /// ketcher 最近一次通过 onSmilesUpdated 回报的 SMILES。
  /// 用于在 didUpdateWidget 中阻断规范化回音循环。
  String? _lastReceivedSmiles;

  @override
  void didUpdateWidget(covariant KetcherEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSmiles != widget.initialSmiles && _ready) {
      // 如果目标 SMILES 与 ketcher 刚才回报的一致，说明这是规范化回音，
      // 跳过 setMolecule 以避免死循环。
      if (widget.initialSmiles == _lastReceivedSmiles) return;
      _sendCommand('setMolecule', {'data': widget.initialSmiles});
    }
  }

  void _sendCommand(String type, Map<String, dynamic> payload) {
    final message = jsonEncode({
      'channel': 'mobile',
      'type': type,
      'payload': payload,
    });
    _webViewController?.evaluateJavascript(
      source: "window.postMessage($message, '*');",
    );
  }

  void _ensureController() {
    if (_controller != null) return;
    _controller = KetcherEditorController(
      setMolecule: (data) async {
        _sendCommand('setMolecule', {'data': data});
      },
      getSmiles: () async {
        final result = await _webViewController?.evaluateJavascript(
          source: '''
            (async () => {
              const k = window.ketcher;
              if (!k) return '';
              return await k.getSmiles();
            })()
          ''',
        );
        return result?.toString();
      },
      getRxn: () async {
        final result = await _webViewController?.evaluateJavascript(
          source: '''
            (async () => {
              const k = window.ketcher;
              if (!k) return '';
              return await k.getRxn();
            })()
          ''',
        );
        return result?.toString();
      },
      exportSvg: ({String? data}) async {
        final structData = data ?? '';
        final result = await _webViewController?.evaluateJavascript(
          source: '''
            (async () => {
              const k = window.ketcher;
              if (!k || !k.generateImage) return null;
              return await k.generateImage('$structData', { outputFormat: 'svg' });
            })()
          ''',
        );
        return result?.toString();
      },
      exportPng: ({String? data}) async {
        final structData = data ?? '';
        final result = await _webViewController?.evaluateJavascript(
          source: '''
            (async () => {
              const k = window.ketcher;
              if (!k || !k.generateImage) return null;
              return await k.generateImage('$structData', { outputFormat: 'png', backgroundColor: '#0b0f1a' });
            })()
          ''',
        );
        return result?.toString();
      },
      triggerSave: () {
        _sendCommand('triggerSave', {});
      },
    );
    widget.onControllerReady?.call(_controller!);
  }

  /// ketcher → flutter_inappwebview 桥接转发。
  /// 环境无关的 UI 适配（触摸转发、双指缩放、滚动条、SMILES 防抖）
  /// 已内置在 ketcher/index.html 中。
  static const String _injectScript = r'''
  (function () {
    if (window._chemvisionInjected) return;
    window._chemvisionInjected = true;

    // ── ketcher → Flutter 回桥 ──
    window.addEventListener('message', function (e) {
      var d = e && e.data;
      if (!d) return;
      var fv = window.flutter_inappwebview;
      if (!fv || !fv.callHandler) return;
      try {
        if (d.eventType === 'init' || d.type === 'init') {
          fv.callHandler('onBridgeReady', {});
          return;
        }
        if (d.type === 'onSmilesUpdated' && d.payload) {
          fv.callHandler('onSmilesUpdated', d.payload);
          return;
        }
        if (d.type === 'onError' && d.payload) {
          fv.callHandler('onError', d.payload);
          return;
        }
      } catch (_) {}
    });

    // safePostMessage 在 window.parent===window 时不发 init，
    // 故轮询 ketcher 就绪后主动通知 Flutter
    if (!window._ketcherReadyPoll) {
      window._ketcherReadyPoll = setInterval(function () {
        if (window.ketcher && typeof window.ketcher.getSmiles === 'function') {
          clearInterval(window._ketcherReadyPoll);
          window._ketcherReadyPoll = null;
          try {
            window.flutter_inappwebview &&
              window.flutter_inappwebview.callHandler &&
              window.flutter_inappwebview.callHandler('onBridgeReady', {});
          } catch (_) {}
        }
      }, 250);
    }
  })();
  ''';

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: AppConfig.ketcherEntry,
      // 不声明 gestureRecognizers：flutter_inappwebview 默认混合合成，画布触摸
      // 原生送达 webview，由注入脚本转为鼠标事件供 ketcher 绘制长碳链。
      onWebViewCreated: (controller) {
        _webViewController = controller;

        controller.addJavaScriptHandler(
          handlerName: 'onBridgeReady',
          callback: (_) {
            _ready = true;
            _ensureController();
            if (widget.initialSmiles.isNotEmpty) {
              _sendCommand('setMolecule', {'data': widget.initialSmiles});
            }
            if (widget.readOnly) {
              _sendCommand('setReadOnly', {'readOnly': true});
            }
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onSmilesUpdated',
          callback: (args) {
            if (args.isNotEmpty) {
              final data = args[0];
              final smiles = data is Map ? data['smiles']?.toString() : null;
              if (smiles != null && smiles.isNotEmpty) {
                _lastReceivedSmiles = smiles;
                widget.onSmilesUpdated?.call(smiles);
              }
            }
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onError',
          callback: (args) {
            if (args.isNotEmpty) {
              final data = args[0];
              final message = data is Map ? data['message']?.toString() : null;
              if (message != null) {
                widget.onError?.call(message);
              }
            }
          },
        );
      },
      onLoadStop: (controller, uri) async {
        await controller.evaluateJavascript(source: _injectScript);
      },
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          transparentBackground: true,
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
      ),
    );
  }
}