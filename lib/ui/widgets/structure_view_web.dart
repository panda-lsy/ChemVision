import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

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
  late final String _channel;
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _pageReady = false;
  StructureViewController? _controller;

  @override
  void initState() {
    super.initState();
    _channel = 'chemvision-${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'chemvision-structure-$_channel';
    _registerViewFactory();
    _messageSub = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant StructureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smiles != widget.smiles && _pageReady) {
      _sendSmiles(widget.smiles);
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  void _registerViewFactory() {
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'assets/web/index.html?channel=$_channel&compact=${widget.compact ? 1 : 0}&readOnly=${widget.readOnly ? 1 : 0}'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';

      iframe.onLoad.listen((_) {
        _pageReady = true;
        _ensureController();
        if (widget.compact) {
          _postMessage('setCompactMode', {'compact': true});
        }
        if (widget.readOnly) {
          _postMessage('setReadOnly', {'readOnly': true});
        }
        _sendSmiles(widget.smiles);
      });

      _iframe = iframe;
      return iframe;
    });
  }

  void _ensureController() {
    if (_controller != null) {
      return;
    }
    _controller = StructureViewController(
      updateAtomElement: (atomId, element) async {
        _postMessage('updateAtomElement', {
          'atomId': atomId,
          'element': element,
        });
      },
      exportSvg: () async {
        final iframe = _iframe;
        if (iframe == null) {
          return null;
        }
        try {
          // Use postMessage to request SVG export from iframe
          final completer = Completer<String?>();
          late StreamSubscription sub;
          sub = html.window.onMessage.listen((event) {
            final data = event.data;
            if (data is Map && data['channel'] == _channel && data['type'] == 'exportSvgResult') {
              final result = data['payload']?['svgString'] as String?;
              completer.complete(result);
              sub.cancel();
            }
          });
          _postMessage('exportSvg', {});
          return await completer.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
        } catch (e) {
          return null;
        }
      },
      exportPng: () async {
        final iframe = _iframe;
        if (iframe == null) return null;
        try {
          final completer = Completer<String?>();
          late StreamSubscription sub;
          sub = html.window.onMessage.listen((event) {
            final data = event.data;
            if (data is Map &&
                data['channel'] == _channel &&
                data['type'] == 'exportPngResult') {
              completer.complete(data['payload']?['dataUrl'] as String?);
              sub.cancel();
            }
          });
          _postMessage('renderPng', {});
          return await completer.future.timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );
        } catch (e) {
          return null;
        }
      },
    );
    widget.onControllerReady?.call(_controller!);
  }

  void _sendSmiles(String smiles) {
    _postMessage('renderSmiles', {'smiles': smiles});
  }

  void _postMessage(String type, Map<String, dynamic> payload) {
    final target = _iframe?.contentWindow;
    if (target == null) {
      return;
    }
    target.postMessage(
      {
        'channel': _channel,
        'type': type,
        'payload': payload,
      },
      '*',
    );
  }

  void _handleMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! Map) {
      return;
    }
    if (data['channel'] != _channel) {
      return;
    }
    final type = data['type'];
    final payload = data['payload'];
    if (type == 'onBridgeReady') {
      _pageReady = true;
      _sendSmiles(widget.smiles);
      return;
    }
    if (type == 'onAtomSelected' && payload is Map) {
      final atomId = payload['atomId']?.toString() ?? '';
      final element = payload['element']?.toString();
      widget.onAtomSelected?.call(atomId, element);
      return;
    }
    if (type == 'onSmilesUpdated' && payload is Map) {
      final smiles = payload['smiles']?.toString();
      if (smiles != null && smiles.isNotEmpty) {
        widget.onSmilesUpdated?.call(smiles);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
