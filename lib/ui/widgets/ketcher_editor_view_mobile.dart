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

  /// 注入移动端适配脚本：桥接 postMessage → flutter_inappwebview、抑制隐藏 cliparea
  /// 弹输入法、画布触摸→鼠标事件转发、以及工具条溢出/滚动问题。
  /// 这些修复以注入方式作用于已有的 ketcher 构建产物，无需重新构建 ketcher。
  static const String _injectScript = r'''
  (function () {
    if (window._chemvisionInjected) return;
    window._chemvisionInjected = true;

    // ── 1. ketcher → Flutter 回桥 ──
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
    // safePostMessage 在 window.parent===window 时不发 init，故轮询 ketcher 就绪后主动通知
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

    // ── 2. 抑制隐藏 cliparea 触发输入法 ──
    function neutralizeCliparea() {
      var el = document.querySelector('.cliparea');
      if (!el || el.getAttribute('data-cv-clip')) return;
      try { el.readOnly = true; } catch (_) {}
      try { el.setAttribute('contenteditable', 'false'); } catch (_) {}
      try { el.setAttribute('inputmode', 'none'); } catch (_) {}
      el.setAttribute('data-cv-clip', '1');
    }
    neutralizeCliparea();
    new MutationObserver(function () { neutralizeCliparea(); })
      .observe(document.documentElement, { childList: true, subtree: true });

    // ── 3. 移动端布局/手势 CSS ──
    var style = document.createElement('style');
    style.textContent =
      'html,body,#root{height:100%!important;width:100%!important;margin:0!important;padding:0!important;overflow:hidden!important;}'
      + 'body{position:fixed!important;inset:0!important;}'
      + '.cliparea,.cliparea *{touch-action:none!important;}'
      // 画布接收触摸拖拽绘制长碳链
      + '[class*="StructEditor"],[class*="StructEditor"] svg,[class*="StructEditor"] canvas,'
      + 'svg.drawn-structures,.drawn-structures{touch-action:none!important;}'
      // 横向工具条不换行，改为横向滚动；按钮组不压缩以保留可点击宽度
      + '[class*="TopToolbar"],[class*="BottomToolbar"]{flex-wrap:nowrap!important;'
        + 'overflow-x:auto!important;overflow-y:hidden!important;'
        + 'max-width:100vw!important;-webkit-overflow-scrolling:touch;'
        + 'touch-action:pan-x!important;}'
      + '[class*="TopToolbar"] [class*="group"],[class*="BottomToolbar"] [class*="group"]'
      + '{flex-shrink:0!important;white-space:nowrap!important;}'
      // 纵向工具条按钮可点
      + '[class*="LeftToolbar"],[class*="RightToolbar"]{touch-action:manipulation!important;}';
    document.head.appendChild(style);

    // ── 4. 触摸 → 鼠标事件转发（核心：绘制长碳链）──
    // ketcher 用 D3 .on('mousedown'/'mousemove') 监听画布；Android WebView 在 touch
    // drag 时不会合成 mousemove，导致只能点放单个原子而无法拖拽延伸碳链。这里在
    // 画布触摸时主动派发合成 MouseEvent，并 preventDefault 抑制浏览器自身的鼠标
    // 合成以避免重复派发。工具条/弹窗/表单控件的触摸不转发，仍走原生。
    function isInteractive(target) {
      return !!target.closest(
        '[class*="Toolbar"],[class*="toolbar"],[class*="Modal"],[class*="Dialog"],'
        + '[class*="Popover"],[class*="ContextMenu"],[class*="Tooltip"],'
        + 'button,select,input,textarea,a[href],[role="button"]'
      );
    }
    function dispatchMouse(type, touch) {
      var el = document.elementFromPoint(touch.clientX, touch.clientY);
      if (!el) return;
      try {
        var ev = new MouseEvent(type, {
          bubbles: true,
          cancelable: true,
          view: window,
          clientX: touch.clientX,
          clientY: touch.clientY,
          button: 0,
          buttons: type === 'mouseup' ? 0 : 1,
          relatedTarget: null,
        });
        el.dispatchEvent(ev);
      } catch (_) {}
    }
    var touching = false;
    document.addEventListener('touchstart', function (e) {
      if (e.touches.length !== 1) return;
      if (isInteractive(e.target)) return;
      touching = true;
      e.preventDefault();
      dispatchMouse('mousedown', e.touches[0]);
    }, { passive: false });
    document.addEventListener('touchmove', function (e) {
      if (!touching || e.touches.length !== 1) return;
      e.preventDefault();
      dispatchMouse('mousemove', e.touches[0]);
    }, { passive: false });
    document.addEventListener('touchend', function (e) {
      if (!touching) return;
      touching = false;
      e.preventDefault();
      dispatchMouse('mouseup', e.changedTouches[0]);
    }, { passive: false });
    document.addEventListener('touchcancel', function () { touching = false; });
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