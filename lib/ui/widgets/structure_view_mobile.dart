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
  });

  final String smiles;
  final void Function(String atomId, String? element)? onAtomSelected;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<StructureViewController>? onControllerReady;

  @override
  State<StructureView> createState() => _StructureViewState();
}

class _StructureViewState extends State<StructureView> {
  InAppWebViewController? _controller;
  bool _pageReady = false;
  StructureViewController? _viewController;

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
        _sendSmiles(widget.smiles);
      },
    );
  }
}
