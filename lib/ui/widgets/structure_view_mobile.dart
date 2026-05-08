import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
import '../../utils/js_utils.dart';
import 'structure_view_controller.dart';

class StructureView extends StatefulWidget {
  const StructureView({
    super.key,
    required this.smiles,
    this.onAtomSelected,
    this.onSmilesUpdated,
    this.onControllerReady,
    this.compact = false,
    this.readOnly = false,
  });

  final String smiles;
  final void Function(String atomId, String? element)? onAtomSelected;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<StructureViewController>? onControllerReady;
  final bool compact;
  final bool readOnly;

  @override
  State<StructureView> createState() => _StructureViewState();
}

class _StructureViewState extends State<StructureView> {
  InAppWebViewController? _controller;
  bool _pageReady = false;
  StructureViewController? _viewController;
  Completer<String?>? _pngCompleter;

  @override
  void didUpdateWidget(covariant StructureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smiles != widget.smiles && _pageReady) {
      _sendSmiles(widget.smiles);
    }
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onBridgeReady',
      callback: (args) {
        _pageReady = true;
        _sendSmiles(widget.smiles);
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onAtomSelected',
      callback: (args) {
        if (args.isEmpty || widget.onAtomSelected == null) {
          return null;
        }
        final raw = args.first;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final atomId = data['atomId']?.toString() ?? '';
          final element = data['element']?.toString();
          widget.onAtomSelected?.call(atomId, element);
        }
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSmilesUpdated',
      callback: (args) {
        if (args.isEmpty || widget.onSmilesUpdated == null) {
          return null;
        }
        final raw = args.first;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final smiles = data['smiles']?.toString();
          if (smiles != null && smiles.isNotEmpty) {
            widget.onSmilesUpdated?.call(smiles);
          }
        }
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'exportPngResult',
      callback: (args) {
        if (args.isNotEmpty && args.first is Map) {
          final data = Map<String, dynamic>.from(args.first);
          final dataUrl = data['dataUrl'] as String?;
          if (_pngCompleter != null && !_pngCompleter!.isCompleted) {
            _pngCompleter!.complete(dataUrl);
          }
        }
        return null;
      },
    );
  }

  Future<void> _sendSmiles(String smiles) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final escaped = escapeForSingleQuotedJs(smiles);
    await controller.evaluateJavascript(source: "renderSmiles('$escaped');");
  }

  void _ensureController(InAppWebViewController controller) {
    if (_viewController != null) {
      return;
    }
    _viewController = StructureViewController(
      updateAtomElement: (atomId, element) async {
        final safeId = escapeForSingleQuotedJs(atomId);
        final safeElement = escapeForSingleQuotedJs(element);
        await controller.evaluateJavascript(
          source: "updateAtomElement('$safeId', '$safeElement');",
        );
      },
      exportSvg: () async {
        try {
          final result = await controller.evaluateJavascript(
            source: 'window.exportSvg && window.exportSvg();',
          );
          return result is String ? result : null;
        } catch (e) {
          return null;
        }
      },
      exportPng: () async {
        try {
          _pngCompleter = Completer<String?>();
          await controller.evaluateJavascript(
            source: 'window.renderPng && window.renderPng(2);',
          );
          return await _pngCompleter!.future.timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );
        } catch (e) {
          return null;
        }
      },
    );
    widget.onControllerReady?.call(_viewController!);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: AppConfig.localWebEntry,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        _registerHandlers(controller);
        _ensureController(controller);
      },
      onLoadStop: (controller, url) {
        _pageReady = true;
        controller.evaluateJavascript(
          source: 'window.setCompactMode && window.setCompactMode(${widget.compact ? 'true' : 'false'});',
        );
        if (widget.readOnly) {
          controller.evaluateJavascript(
            source: 'window.setReadOnly && window.setReadOnly(true);',
          );
        }
        _sendSmiles(widget.smiles);
      },
    );
  }
}
