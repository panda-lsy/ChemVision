import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
import '../../theme/app_colors.dart';
import '../../utils/js_utils.dart';
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
  InAppWebViewController? _controller;
  bool _pageReady = false;
  JsmeEditorController? _viewController;

  void _markPageReady() {
    if (_pageReady || !mounted) return;
    setState(() {
      _pageReady = true;
    });
  }

  @override
  void didUpdateWidget(covariant JsmeEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smiles != widget.smiles && _pageReady) {
      _sendSmiles(widget.smiles);
    }
    if (oldWidget.themeMode != widget.themeMode && _pageReady) {
      _sendTheme(widget.themeMode);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    _viewController = null;
    if (controller != null) {
      controller.stopLoading();
    }
    super.dispose();
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onBridgeReady',
      callback: (args) {
        _markPageReady();
        _sendSmiles(widget.smiles);
        _sendTheme(widget.themeMode);
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onSmilesUpdated',
      callback: (args) {
        if (args.isEmpty || widget.onSmilesUpdated == null) return null;
        final raw = args.first;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final smiles = data['smiles']?.toString();
          if (smiles != null) {
            widget.onSmilesUpdated?.call(smiles);
          }
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onEditorActionError',
      callback: (args) {
        if (args.isEmpty || widget.onError == null) return null;
        final raw = args.first;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final message = data['message']?.toString();
          if (message != null && message.isNotEmpty) {
            widget.onError?.call(message);
          }
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onDebugLog',
      callback: (args) {
        if (args.isNotEmpty && args.first is Map) {
          final data = Map<String, dynamic>.from(args.first);
          final ts = data['ts']?.toString() ?? '';
          final level = data['level']?.toString() ?? 'info';
          final message = data['message']?.toString() ?? '';
          final extra = data['extra'];
          debugPrint(
            '[JSME][mobile][$level] $ts $message${extra == null ? '' : ' | $extra'}',
          );
          widget.onDebugLog?.call(
            '[mobile][$level] $ts $message${extra == null ? '' : ' | $extra'}',
          );
        }
        return null;
      },
    );
  }

  Future<void> _sendSmiles(String smiles) async {
    final controller = _controller;
    if (controller == null) return;
    final escaped = escapeForSingleQuotedJs(smiles);
    await controller.evaluateJavascript(source: "setSmiles('$escaped');");
  }

  Future<void> _sendTheme(String mode) async {
    final controller = _controller;
    if (controller == null) return;
    final normalized = mode.toLowerCase() == 'light' ? 'light' : 'dark';
    await controller.evaluateJavascript(source: "setTheme('$normalized');");
  }

  void _ensureController(InAppWebViewController controller) {
    if (_viewController != null) return;
    _viewController = JsmeEditorController(
      setSmiles: (smiles) async {
        final escaped = escapeForSingleQuotedJs(smiles);
        await controller.evaluateJavascript(source: "setSmiles('$escaped');");
      },
      getSmiles: () async {
        final result =
            await controller.evaluateJavascript(source: 'getSmiles();');
        return result?.toString();
      },
    );
    widget.onControllerReady?.call(_viewController!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        InAppWebView(
          initialFile: AppConfig.localJsmeEditorEntry,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
            cacheEnabled: false,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            supportZoom: false,
            disableVerticalScroll: true,
            disableHorizontalScroll: true,
            useHybridComposition: true,
          ),
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onWebViewCreated: (controller) {
            _controller = controller;
            debugPrint('[JSME][mobile] onWebViewCreated');
            _registerHandlers(controller);
            _ensureController(controller);
          },
          onLoadStart: (controller, url) {
            debugPrint('[JSME][mobile] onLoadStart: $url');
          },
          onLoadStop: (controller, url) {
            debugPrint('[JSME][mobile] onLoadStop: $url');
            _markPageReady();
            _sendSmiles(widget.smiles);
            _sendTheme(widget.themeMode);
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint(
              '[JSME][mobile][console] ${consoleMessage.messageLevel}: ${consoleMessage.message}',
            );
          },
        ),
        if (!_pageReady)
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.22)
                  : AppColors.dayBluePrimary.withValues(alpha: 0.08),
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
    );
  }
}
