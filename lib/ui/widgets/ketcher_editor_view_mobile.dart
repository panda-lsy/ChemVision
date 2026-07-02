import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

  /// 注入移动端适配脚本：桥接 postMessage → flutter_inappwebview、抑制隐藏
  /// cliparea 弹出输入法、画布触摸手势、以及工具条超出视野等移动端显示问题。
  /// 这些修复以注入方式作用于已有的 ketcher 构建产物，无需重新构建 ketcher。
  static const String _injectScript = r'''
  (function () {
    if (window._chemvisionInjected) return;
    window._chemvisionInjected = true;

    // ── 1. ketcher → Flutter 回桥 ──
    // ketcher 通过 window.parent.postMessage 向宿主发送事件(onSmilesUpdated/onError 等)；
    // 移动端是顶层 InAppWebView，window.parent === window，事件回传到 window 自身。
    // 这里监听 window message，把这些事件转发给 flutter_inappwebview 的 JS 处理器。
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

    // ketcher 的 safePostMessage 在 window.parent===window 时会直接 return（不发 init 事件），
    // 因此移动端需要主动轮询 window.ketcher 就绪后再通知 Flutter。
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
    // ketcher 的 cliparea 是 contentEditable+autoFocus 的隐藏 textarea，用于剪贴板
    // 与快捷键；移动端一旦获得焦点就弹出软键盘。置为只读并禁用编辑可阻止 IME，
    // 仍保留 select()/execCommand('copy') 等剪贴板能力。
    function neutralizeCliparea() {
      var el = document.querySelector('.cliparea');
      if (!el) return false;
      var patched = el.getAttribute('data-cv-clip');
      if (!patched) {
        try { el.readOnly = true; } catch (_) {}
        try { el.setAttribute('contenteditable', 'false'); } catch (_) {}
        try { el.setAttribute('inputmode', 'none'); } catch (_) {}
        el.setAttribute('data-cv-clip', '1');
        patched = '1';
      }
      // 每次尝试重新聚焦 cliparea 时，若是软键盘弹出则隐藏
      return patched === '1';
    }
    neutralizeCliparea();
    // cliparea 元素由 React 异步渲染，用 MutationObserver 兜底
    var clipObs = new MutationObserver(function () { neutralizeCliparea(); });
    clipObs.observe(document.documentElement, { childList: true, subtree: true });
    // 失焦时强制收起键盘：聚焦 cliparea 立即 blur 会破坏剪贴板，这里改为
    // 在画布/工具条用户交互时让 cliparea 保持 readOnly，浏览器不会为只读元素弹 IME。

    // ── 3. 移动端画布触摸手势 ──
    // 让画布/SVG/编辑区接收触摸拖拽(绘制长碳链)，避免浏览器把拖拽当作滚动/缩放。
    var style = document.createElement('style');
    style.textContent =
      'html,body,#root{height:100%!important;width:100%!important;margin:0!important;padding:0!important;overflow:hidden!important;}'
      + 'body{position:fixed!important;inset:0!important;}'
      + '.cliparea,.cliparea *{touch-action:none!important;}'
      + '[class*="StructEditor"],[class*="StructEditor"] svg,[class*="StructEditor"] canvas,'
      + '[class*="cliparea"] svg,[class*="Canvas"],svg[class*="struct"],'
      + '.drawn-structures,svg.drawn-structures{touch-action:none!important;}'
      // 工具条不抢占拖拽，但按钮可点
      + '[class*="LeftToolbar"],[class*="RightToolbar"],[class*="TopToolbar"],[class*="BottomToolbar"]{touch-action:manipulation!important;}'
      // 顶部工具条在窄屏可横向滚动而不撑破布局
      + '[class*="TopToolbar"]{max-width:100vw!important;overflow-x:auto!important;overflow-y:hidden!important;}';
    document.head.appendChild(style);
  })();
  ''';

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: AppConfig.ketcherEntry,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
      },
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
        // 注入桥接与移动端适配脚本
        await controller.evaluateJavascript(source: _injectScript);
      },
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          transparentBackground: true,
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        android: AndroidInAppWebViewOptions(
          // 允许混合内容（ketcher 本地资源），并尽量让 webview 占满可用区域
          allowContentAccess: true,
        ),
      ),
    );
  }
}
