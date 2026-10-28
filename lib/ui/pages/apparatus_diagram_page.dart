import 'dart:math' as math;

import 'package:diagram_editor/diagram_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/svg_export.dart';

class ApparatusDefinition {
  const ApparatusDefinition({
    required this.id,
    required this.name,
    required this.asset,
    required this.size,
    required this.iconSize,
  });

  final String id;
  final String name;
  final String asset;
  final Size size;
  final Size iconSize;

  static const catalogue = <ApparatusDefinition>[
    ApparatusDefinition(
      id: 'beaker',
      name: '烧杯',
      asset: 'assets/lab_diagram/equipment/beaker.svg',
      size: Size(104, 132),
      iconSize: Size(88, 104),
    ),
    ApparatusDefinition(
      id: 'erlenmeyer-flask',
      name: '锥形瓶',
      asset: 'assets/lab_diagram/equipment/erlenmeyer-flask.svg',
      size: Size(104, 132),
      iconSize: Size(84, 106),
    ),
    ApparatusDefinition(
      id: 'round-bottom-flask',
      name: '圆底烧瓶',
      asset: 'assets/lab_diagram/equipment/round-bottom-flask.svg',
      size: Size(104, 132),
      iconSize: Size(84, 104),
    ),
    ApparatusDefinition(
      id: 'dropper',
      name: '玻璃滴管',
      asset: 'assets/lab_diagram/equipment/dropper-glass.svg',
      size: Size(76, 144),
      iconSize: Size(42, 116),
    ),
    ApparatusDefinition(
      id: 'support-stand',
      name: '铁架台',
      asset: 'assets/lab_diagram/equipment/support-stand.svg',
      size: Size(108, 150),
      iconSize: Size(86, 120),
    ),
    ApparatusDefinition(
      id: 'clamp',
      name: '铁夹',
      asset: 'assets/lab_diagram/equipment/clamp.svg',
      size: Size(124, 100),
      iconSize: Size(108, 70),
    ),
    ApparatusDefinition(
      id: 'scissor-jack',
      name: '升降台',
      asset: 'assets/lab_diagram/equipment/scissor-jack.svg',
      size: Size(126, 104),
      iconSize: Size(108, 72),
    ),
    ApparatusDefinition(
      id: 'burner',
      name: '酒精灯',
      asset: 'assets/lab_diagram/equipment/burner.svg',
      size: Size(82, 138),
      iconSize: Size(62, 112),
    ),
  ];

  static ApparatusDefinition fromId(String id) => catalogue.firstWhere(
    (item) => item.id == id,
    orElse: () => catalogue.first,
  );
}

class ApparatusDiagramPage extends StatefulWidget {
  const ApparatusDiagramPage({super.key});

  @override
  State<ApparatusDiagramPage> createState() => _ApparatusDiagramPageState();
}

class _ApparatusDiagramPageState extends State<ApparatusDiagramPage> {
  static const _draftKey = 'chemvision.apparatus_diagram.draft.v1';
  late final DiagramController<ApparatusDefinition, void> _controller;
  bool _connectMode = false;
  bool _isRestoring = true;
  String? _pendingSourceId;
  String? _selectedComponentId;
  String? _selectedLinkId;

  @override
  void initState() {
    super.initState();
    _controller = DiagramController<ApparatusDefinition, void>(
      canvasConfig: const CanvasConfig(
        backgroundColor: Color(0xFFF8FAFC),
        minScale: 0.35,
        maxScale: 3.5,
      ),
      componentDataCodec: JsonCodec<ApparatusDefinition>(
        encode: (item) => {'id': item.id},
        decode: (json) => ApparatusDefinition.fromId(json['id'] as String),
      ),
    );
    _restoreDraft();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedDraft = preferences.getString(_draftKey);
      if (savedDraft != null && savedDraft.isNotEmpty) {
        _controller.deserialize(savedDraft);
      }
    } catch (_) {
      _controller.removeAllComponents();
      if (mounted) _showMessage('本地草稿无法读取，已为你打开空白画布');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _saveDraft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_draftKey, _controller.serialize());
      if (mounted) _showMessage('装置图已保存在本机');
    } catch (_) {
      if (mounted) _showMessage('保存失败，请检查设备存储空间');
    }
  }

  Future<void> _clearCanvas() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空装置图？'),
        content: const Text('画布内容和本机保存的草稿都会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;

    _controller.removeAllComponents();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_draftKey);
    } catch (_) {
      if (mounted) _showMessage('画布已清空，但本机草稿未能删除');
    }
    if (!mounted) return;
    setState(() {
      _pendingSourceId = null;
      _selectedComponentId = null;
      _selectedLinkId = null;
    });
  }

  void _addEquipment(ApparatusDefinition definition) {
    var slot = 0;
    late Offset position;
    while (true) {
      position = Offset(56 + (slot % 3) * 164, 48 + (slot ~/ 3) * 172);
      final candidate = Rect.fromLTWH(
        position.dx,
        position.dy,
        definition.size.width,
        definition.size.height,
      );
      final overlaps = _controller.components.values.any((component) {
        final existing = Rect.fromLTWH(
          component.position.dx,
          component.position.dy,
          component.size.width,
          component.size.height,
        );
        return candidate.overlaps(existing);
      });
      if (!overlaps) break;
      slot++;
    }
    final component = ComponentData<ApparatusDefinition>(
      position: position,
      size: definition.size,
      minSize: definition.size,
      type: definition.id,
      data: definition,
    );
    _controller.addComponent(component);
    setState(() {
      _pendingSourceId = null;
      _selectedComponentId = component.id;
      _selectedLinkId = null;
    });
  }

  void _onComponentTap(String componentId) {
    if (_connectMode) {
      if (_pendingSourceId == null) {
        setState(() => _pendingSourceId = componentId);
        _showMessage('已选起点，再点一个器材连接导管');
        return;
      }

      if (_pendingSourceId == componentId) {
        setState(() => _pendingSourceId = null);
        _showMessage('已取消选择');
        return;
      }

      final sourceId = _pendingSourceId!;
      final exists = _controller.links.values.any(
        (link) =>
            (link.sourceComponentId == sourceId &&
                link.targetComponentId == componentId) ||
            (link.sourceComponentId == componentId &&
                link.targetComponentId == sourceId),
      );
      if (exists) {
        setState(() => _pendingSourceId = null);
        _showMessage('这两个器材已经连接');
        return;
      }

      final linkId = _controller.connect(
        sourceComponentId: sourceId,
        targetComponentId: componentId,
        linkStyle: const LinkStyle(
          color: Color(0xFF0F766E),
          lineWidth: 3,
          arrowType: ArrowType.none,
        ),
      );
      _controller.showLinkJoints(linkId);
      setState(() {
        _pendingSourceId = null;
        _selectedComponentId = null;
        _selectedLinkId = linkId;
      });
      _showMessage('导管已连接；拖动连线可添加弯折点并调整走向');
      return;
    }

    setState(() {
      _selectedComponentId = componentId;
      _selectedLinkId = null;
    });
  }

  void _deleteSelection() {
    final componentId = _selectedComponentId;
    final linkId = _selectedLinkId;
    if (componentId != null && _controller.componentExists(componentId)) {
      _controller.removeComponent(componentId);
    } else if (linkId != null && _controller.linkExists(linkId)) {
      _controller.removeLink(linkId);
    }
    setState(() {
      _selectedComponentId = null;
      _selectedLinkId = null;
      _pendingSourceId = null;
    });
  }

  Widget _buildComponent(
    BuildContext context,
    ComponentData<ApparatusDefinition> component,
  ) {
    final definition =
        component.data ??
        ApparatusDefinition.fromId(component.type ?? 'beaker');
    final selected = component.id == _selectedComponentId;
    final isPending = component.id == _pendingSourceId;

    return SizedBox.fromSize(
      size: component.size,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending
                ? const Color(0xFFF59E0B)
                : selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFCBD5E1),
            width: selected || isPending ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: SvgPicture.asset(
                definition.asset,
                width: definition.iconSize.width,
                height: definition.iconSize.height,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const Icon(
                  Icons.science_outlined,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            Text(
              definition.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSvg() async {
    if (_controller.components.isEmpty) {
      _showMessage('先从器材栏添加实验器材');
      return;
    }

    try {
      final svg = await _buildSvgDocument();
      await downloadSvg(
        svg,
        'chemvision-apparatus.svg',
        shareText: 'ChemVision 实验装置图 SVG',
      );
      if (mounted) _showMessage('矢量图已导出');
    } catch (_) {
      if (mounted) _showMessage('导出失败，请稍后重试');
    }
  }

  Future<String> _buildSvgDocument() async {
    final components = _controller.componentsSorted;
    final links = _controller.links.values.toList();
    final points = <Offset>[];
    for (final component in components) {
      points
        ..add(component.position)
        ..add(
          component.position +
              Offset(component.size.width, component.size.height),
        );
    }
    for (final link in links) {
      points.addAll(link.linkPoints);
    }

    final minX = points.map((point) => point.dx).reduce(math.min) - 36;
    final minY = points.map((point) => point.dy).reduce(math.min) - 36;
    final maxX = points.map((point) => point.dx).reduce(math.max) + 36;
    final maxY = points.map((point) => point.dy).reduce(math.max) + 36;
    final width = math.max(1, maxX - minX);
    final height = math.max(1, maxY - minY);
    final result = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>')
      ..write(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="${width.ceil()}" height="${height.ceil()}" '
        'viewBox="$minX $minY $width $height">',
      )
      ..write(
        '<rect x="$minX" y="$minY" width="$width" height="$height" fill="#ffffff"/>',
      );

    for (final link in links) {
      if (link.linkPoints.length < 2) continue;
      final path = StringBuffer(
        'M ${_number(link.linkPoints.first.dx)} ${_number(link.linkPoints.first.dy)}',
      );
      for (final point in link.linkPoints.skip(1)) {
        path.write(' L ${_number(point.dx)} ${_number(point.dy)}');
      }
      result.write(
        '<path d="${path.toString()}" fill="none" '
        'stroke="${_colorHex(link.linkStyle.color)}" '
        'stroke-width="${_number(link.linkStyle.lineWidth)}" '
        'stroke-linecap="round" stroke-linejoin="round"/>',
      );
    }

    for (final component in components) {
      final definition =
          component.data ??
          ApparatusDefinition.fromId(component.type ?? 'beaker');
      final source = await rootBundle.loadString(definition.asset);
      final svgRoot = RegExp(
        r'<svg\b([^>]*)>([\s\S]*?)</svg\s*>',
      ).firstMatch(source);
      if (svgRoot == null) {
        throw FormatException('Invalid SVG asset: ${definition.asset}');
      }
      final viewBox = RegExp(
        r'''viewBox\s*=\s*["']([^"']+)["']''',
      ).firstMatch(svgRoot.group(1) ?? '')?.group(1);
      if (viewBox == null) {
        throw FormatException('SVG viewBox is missing: ${definition.asset}');
      }

      final iconX = component.position.dx + 7;
      final iconY = component.position.dy + 5;
      final iconWidth = math.max(1, component.size.width - 14).toDouble();
      final iconHeight = math.max(1, component.size.height - 29).toDouble();
      final prefix =
          'component_${component.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_';
      final inner = _prefixSvgIds(svgRoot.group(2) ?? '', prefix);
      result.write(
        '<svg x="${_number(iconX)}" y="${_number(iconY)}" '
        'width="${_number(iconWidth)}" height="${_number(iconHeight)}" '
        'viewBox="${_escapeAttribute(viewBox)}" preserveAspectRatio="xMidYMid meet">'
        '$inner</svg>',
      );

      final labelX = component.position.dx + component.size.width / 2;
      final labelY = component.position.dy + component.size.height - 8;
      result.write(
        '<text x="${_number(labelX)}" y="${_number(labelY)}" '
        'text-anchor="middle" font-family="sans-serif" font-size="11" '
        'font-weight="600" fill="#334155">${_escapeText(definition.name)}</text>',
      );
    }

    result.write('</svg>');
    return result.toString();
  }

  String _prefixSvgIds(String content, String prefix) {
    final ids = <String>[];
    var result = content.replaceAllMapped(RegExp(r'\bid="([^"]+)"'), (match) {
      final id = match.group(1)!;
      ids.add(id);
      return 'id="$prefix$id"';
    });
    for (final id in ids) {
      result = result
          .replaceAll('url(#$id)', 'url(#$prefix$id)')
          .replaceAll('href="#$id"', 'href="#$prefix$id"')
          .replaceAll('xlink:href="#$id"', 'xlink:href="#$prefix$id"');
    }
    return result;
  }

  String _colorHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String _number(double value) => value.isFinite
      ? value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')
      : '0';

  String _escapeText(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _escapeAttribute(String value) =>
      _escapeText(value).replaceAll('"', '&quot;');

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedComponentId != null || _selectedLinkId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('实验装置图'),
        actions: [
          IconButton(
            tooltip: '保存本机草稿',
            onPressed: _isRestoring ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: '删除选中项',
            onPressed: selected ? _deleteSelection : null,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: '清空画布',
            onPressed: _isRestoring ? null : _clearCanvas,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: '导出 SVG 矢量图',
            onPressed: _isRestoring ? null : _exportSvg,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isRestoring
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectMode
                              ? (_pendingSourceId == null
                                    ? '连接导管：先点起点器材，再点终点器材'
                                    : '已选起点：再点一个器材完成连接')
                              : '把器材拖到画布上；拖动器材可调整位置',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('选择 / 移动'),
                              avatar: const Icon(Icons.open_with, size: 17),
                              selected: !_connectMode,
                              onSelected: (_) => setState(() {
                                _connectMode = false;
                                _pendingSourceId = null;
                              }),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('连接导管'),
                              avatar: const Icon(Icons.linear_scale, size: 17),
                              selected: _connectMode,
                              onSelected: (_) => setState(() {
                                _connectMode = true;
                                _pendingSourceId = null;
                                _selectedComponentId = null;
                                _selectedLinkId = null;
                              }),
                            ),
                            const Spacer(),
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) => Text(
                                '${_controller.components.length} 件器材 · ${_controller.links.length} 根导管',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DiagramEditor<ApparatusDefinition, void>(
                        controller: _controller,
                        componentBuilder: _buildComponent,
                        onComponentTap: _onComponentTap,
                        onLinkTapUp: (id, _) {
                          setState(() {
                            _selectedComponentId = null;
                            _selectedLinkId = id;
                          });
                        },
                        linksOnTop: true,
                      ),
                    ),
                  ),
                  _buildEquipmentPalette(context),
                ],
              ),
      ),
    );
  }

  Widget _buildEquipmentPalette(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('添加器材', style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: ApparatusDefinition.catalogue.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = ApparatusDefinition.catalogue[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _addEquipment(item),
                  child: Container(
                    width: 78,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SvgPicture.asset(
                            item.asset,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
