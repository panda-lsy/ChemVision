import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  bool _bridgeReady = false;
  JsmeEditorController? _viewController;
  String? _cachedHtml;
  Timer? _loadTimeout;
  String _lastSentTheme = '';

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
    _loadTimeout?.cancel();
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
        _bridgeReady = true;
        _loadTimeout?.cancel();
        _lastSentTheme = '';
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
    if (normalized == _lastSentTheme) return;
    _lastSentTheme = normalized;
    await controller.evaluateJavascript(source: "setTheme('$normalized');");
  }

  bool _isRecoverableAssetError(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('deferredjs/') ||
        lower.contains('.cache.js') ||
        lower.contains('clear.cache.gif');
  }

  Future<void> _triggerWebAssetRecovery(String url, String reason) async {
    final controller = _controller;
    if (controller == null) return;
    final escapedUrl = escapeForSingleQuotedJs(url);
    final escapedReason = escapeForSingleQuotedJs(reason);
    await controller.evaluateJavascript(
      source:
          "if(window.__chemvisionRecoverMissingAsset){window.__chemvisionRecoverMissingAsset('$escapedUrl','$escapedReason');}"
          "if(window.__chemvisionEnsureJsmeCore){window.__chemvisionEnsureJsmeCore('$escapedReason');}",
    );
  }

  Future<void> _loadEditorHtml(InAppWebViewController controller) async {
    try {
      debugPrint('[JSME][mobile] loading editor via loadData with theme...');
      final rawHtml = _cachedHtml ??= await rootBundle.loadString(
        AppConfig.localJsmeEditorEntry,
      );
      final theme =
          widget.themeMode.toLowerCase() == 'light' ? 'light' : 'dark';
      // Inject theme before any script runs so initial render uses correct palette
      final themedHtml = rawHtml.replaceFirst(
        '<head>',
        '<head><script>window.__chemvisionTheme = \'$theme\';</script>',
      );
      await controller.loadData(
        data: themedHtml,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('file:///android_asset/flutter_assets/assets/web/'),
      );
      debugPrint('[JSME][mobile] loadData with theme=$theme completed');
    } catch (e) {
      debugPrint('[JSME][mobile] loadData failed: $e');
      widget.onError?.call('无法加载编辑器: $e');
    }
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
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: false,
            cacheEnabled: false,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            allowFileAccess: true,
            allowContentAccess: true,
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
            _loadEditorHtml(controller);
          },
          onLoadStart: (controller, url) {
            debugPrint('[JSME][mobile] onLoadStart: $url');
          },
          onLoadStop: (controller, url) {
            debugPrint('[JSME][mobile] onLoadStop: $url');
            // Inject opaque background as fallback in case CSS variables fail to load
            final isDark = widget.themeMode.toLowerCase() != 'light';
            final bgColor = isDark ? '#0f172a' : '#f4f8ff';
            final panelBg = isDark ? 'rgba(20,29,46,0.82)' : 'rgba(255,255,255,0.95)';
            controller.evaluateJavascript(source:
              "document.body.style.background='$bgColor';"
              "var r=document.getElementById('jsme-root');if(r)r.style.background='$bgColor';"
              "var c=document.getElementById('editor-card');if(c)c.style.background='$panelBg';",
            );
            // 主题和 SMILES 由 onBridgeReady 统一发送，避免 onLoadStop 时序问题
            _loadTimeout?.cancel();
            _loadTimeout = Timer(const Duration(seconds: 10), () {
              if (_bridgeReady) return;
              debugPrint('[JSME][mobile] TIMEOUT: GWT/JSME failed to initialize within 10s');
              widget.onError?.call('JSME 编辑器加载超时（GWT 脚本可能未成功加载）');
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint(
              '[JSME][mobile][console] ${consoleMessage.messageLevel}: ${consoleMessage.message}',
            );
          },
          onReceivedError: (controller, request, error) {
            final url = request.url?.toString();
            debugPrint(
              '[JSME][mobile] onReceivedError: ${error.type} ${error.description} (${request.url})',
            );
            if (_isRecoverableAssetError(url)) {
              _triggerWebAssetRecovery(
                url!,
                'mobile-onReceivedError-${error.type}',
              );
            }
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
