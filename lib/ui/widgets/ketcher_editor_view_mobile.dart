import 'dart:async';
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
  });

  final String initialSmiles;
  final ValueChanged<KetcherEditorController>? onControllerReady;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<String>? onError;
  final bool readOnly;

  @override
  State<KetcherEditorView> createState() => _KetcherEditorViewState();
}

class _KetcherEditorViewState extends State<KetcherEditorView> {
  InAppWebViewController? _webViewController;
  KetcherEditorController? _controller;
  bool _ready = false;

  @override
  void didUpdateWidget(covariant KetcherEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSmiles != widget.initialSmiles && _ready) {
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
        final requestId = DateTime.now().microsecondsSinceEpoch.toString();
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
    );
    widget.onControllerReady?.call(_controller!);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: AppConfig.ketcherEntry,
      onWebViewCreated: (controller) {
        _webViewController = controller;

        // 注入 JS 回调监听
        controller.addJavaScriptHandler(
          handlerName: 'onBridgeReady',
          callback: (_) {
            _ready = true;
            _ensureController();
            if (widget.initialSmiles.isNotEmpty) {
              _sendCommand('setMolecule', {'data': widget.initialSmiles});
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
      onLoadStop: (controller, url) async {
        // Inject bridge script
        await controller.evaluateJavascript(source: '''
          if (!window._bridgeInjected) {
            window._bridgeInjected = true;
            // For mobile, use FlutterChannel for callbacks
            window.postToHost = function(type, payload) {
              if (window.FlutterChannel) {
                window.FlutterChannel.postMessage(JSON.stringify({
                  channel: 'mobile', type: type, payload: payload
                }));
              }
            };
          }
        ''');
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
