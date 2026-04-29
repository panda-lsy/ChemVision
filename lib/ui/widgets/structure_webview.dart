import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
import '../../utils/js_utils.dart';

class StructureWebView extends StatefulWidget {
  const StructureWebView({
    super.key,
    required this.smiles,
    this.onAtomSelected,
    this.onSmilesUpdated,
    this.onWebViewReady,
  });

  final String smiles;
  final void Function(String atomId, String? element)? onAtomSelected;
  final ValueChanged<String>? onSmilesUpdated;
  final ValueChanged<InAppWebViewController>? onWebViewReady;

  @override
  State<StructureWebView> createState() => _StructureWebViewState();
}

class _StructureWebViewState extends State<StructureWebView> {
  InAppWebViewController? _controller;
  bool _pageReady = false;

  @override
  void didUpdateWidget(covariant StructureWebView oldWidget) {
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
        widget.onWebViewReady?.call(controller);
      },
      onLoadStop: (controller, url) {
        _pageReady = true;
        _sendSmiles(widget.smiles);
      },
    );
  }
}
