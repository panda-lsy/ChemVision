import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/download_web.dart' if (dart.library.io) '../../utils/download_io.dart';

/// 导出图片页面。Web 端通过 [Navigator.push] 推入为全屏路由，
/// 让 Flutter Web 把本路由渲染到 Ketcher iframe（HtmlElementView）
/// 之上，避免 platform-view 层级吃掉点击事件。
class ExportImageDialog extends StatefulWidget {
  const ExportImageDialog({
    super.key,
    required this.exportSvg,
    required this.exportPng,
    this.onClose,
  });

  final Future<String?> Function(String bgColor) exportSvg;
  final Future<String?> Function(String bgColor) exportPng;
  final VoidCallback? onClose;

  @override
  State<ExportImageDialog> createState() => _ExportImageDialogState();
}

class _ExportImageDialogState extends State<ExportImageDialog> {
  String _format = 'png';
  String _bgMode = 'transparent';
  // 默认背景由 didChangeDependencies 根据 ChemVision 主题决定（夜间→#0b0f1a；日间→#ffffff）；透明仅作为可选项
  bool _bgInitDone = false;
  String? _dataUrl;
  // 解码后的元素：png 是字节，svg 是文本。预览采用对应 widget。
  Uint8List? _pngBytes;
  String? _svgText;
  bool _loading = false;
  String? _error;
  // 自增序号，丢弃过期（用户已切换）的异步结果，防止旧响应覆盖新选择
  int _loadSeq = 0;

  static const _bgList = [
    {'key': 'transparent', 'label': '透明', 'icon': Icons.grid_on},
    {'key': '#ffffff', 'label': '日间', 'icon': Icons.wb_sunny},
    {'key': '#0b0f1a', 'label': '夜间', 'icon': Icons.nightlight_round},
  ];

  static const Map<String, Color?> _bgColors = {
    'transparent': null,
    '#ffffff': Color(0xFFFFFFFF),
    '#0b0f1a': Color(0xFF0b0f1a),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bgInitDone) {
      _bgInitDone = true;
      _bgMode = Theme.of(context).brightness == Brightness.dark ? '#0b0f1a' : '#ffffff';
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final format = _format;
    final bg = _bgMode;
    debugPrint('export[$seq]: request format=$format bg=$bg');
    setState(() { _loading = true; _error = null; });
    String? url;
    try {
      if (format == 'svg') {
        url = await widget.exportSvg(bg);
      } else {
        url = await widget.exportPng(bg);
      }
      debugPrint('export[$seq]: result len=${url?.length ?? 0} head=${url == null ? 'null' : url.substring(0, url.length > 60 ? 60 : url.length)}');
    } catch (e, st) {
      debugPrint('export[$seq]: throw $e\n$st');
      if (!mounted) return;
      setState(() { _dataUrl = null; _pngBytes = null; _svgText = null; _loading = false; _error = '导出异常: $e'; });
      return;
    }
    if (!mounted || seq != _loadSeq) {
      debugPrint('export[$seq]: stale, dropped (current seq=$_loadSeq)');
      return;
    }
    final bool isDataUrl = url != null && url.startsWith('data:');
    final bool isBareSvg = url != null && url.trimLeft().startsWith('<svg');
    if (url == null || !isDataUrl && !isBareSvg || (isDataUrl && url.length <= 32)) {
      setState(() {
        _dataUrl = null;
        _pngBytes = null;
        _svgText = null;
        _loading = false;
        _error = url == null ? '导出返回空（画板可能未加载完成）' : '返回内容无效: ${url.length} 字节';
      });
      return;
    }
    try {
      if (format == 'svg') {
        _pngBytes = null;
        if (isBareSvg) {
          _svgText = url;
          _dataUrl = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(url))}';
        } else {
          _dataUrl = url;
          _svgText = utf8.decode(base64Decode(url.split(',').last));
        }
      } else {
        // PNG 走 data URL 的 base64 路径
        _dataUrl = url;
        _pngBytes = base64Decode(url.split(',').last);
        _svgText = null;
      }
      setState(() { _loading = false; _error = null; });
    } catch (e) {
      debugPrint('export[$seq]: decode failed: $e');
      setState(() { _pngBytes = null; _svgText = null; _loading = false; _error = '解码失败: $e'; });
    }
  }

  void _close() {
    widget.onClose?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _download() async {
    if (_dataUrl == null) return;
    final fileName = 'chemvision_${DateTime.now().millisecondsSinceEpoch}.$_format';
    try {
      downloadDataUrl(_dataUrl!, fileName);
      _showSuccessToast('已开始下载：$fileName');
    } catch (e) {
      debugPrint('export: download failed: $e');
      _showErrorToast(kIsWeb ? '下载未触发，请长按图片保存' : '请长按图片保存');
    }
  }

  void _showSuccessToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: const Color(0xFF2bad7e),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _showErrorToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ]),
          backgroundColor: const Color(0xFF6b3fa0),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool useChecker = _bgColors[_bgMode] == null;
    final Color? solidBg = useChecker ? null : _bgColors[_bgMode];

    // 预览内容：必须能在有限约束下计算尺寸。放在 Expanded 里，
    // 避免 SingleChildScrollView 的无限高让 Stack 崩溃。
    Widget preview;
    if (_loading) {
      preview = const Center(child: CircularProgressIndicator());
    } else if (_pngBytes != null) {
      preview = Stack(fit: StackFit.expand, children: [
        if (useChecker) _checkerboard(),
        Center(child: Image.memory(_pngBytes!, fit: BoxFit.contain, errorBuilder: (_, e, __) => _errorBox('PNG 解码失败: $e'))),
      ]);
    } else if (_svgText != null) {
      preview = Stack(fit: StackFit.expand, children: [
        if (useChecker) _checkerboard(),
        Center(child: SvgPicture.string(_svgText!, fit: BoxFit.contain)),
      ]);
    } else {
      preview = Stack(fit: StackFit.expand, children: [
        if (useChecker) _checkerboard(),
        Center(child: _errorBox(_error ?? '无法生成预览')),
      ]);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0d1627) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 固定头部 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close), onPressed: _close),
                const SizedBox(width: 4),
                Text('导出图片', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '重新生成',
                  onPressed: _loading ? null : _load,
                ),
              ]),
            ),
            // ===== 固定控制条（可横向滚动以兼容窄屏）=====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('格式', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(children: [
                  _pillBtn('PNG', 'png', Icons.image),
                  const SizedBox(width: 10),
                  _pillBtn('SVG', 'svg', Icons.code),
                ]),
                const SizedBox(height: 12),
                Text('背景', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(children: _bgList.map((b) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: b['key'] != _bgList.last['key'] ? 8 : 0),
                    child: _bgCard(b['label'] as String, b['key'] as String, b['icon'] as IconData),
                  ),
                )).toList()),
              ]),
            ),
            // ===== 预览区：有限高度，Stack 不再炸 =====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: solidBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preview,
                ),
              ),
            ),
            // ===== 固定底栏 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 20),
                  label: Text('下载 ${_format.toUpperCase()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38d5c1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_dataUrl != null && !_loading) ? _download : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkerboard() {
    return SizedBox.expand(child: CustomPaint(painter: _CheckerPainter()));
  }

  Widget _errorBox(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 40, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.withValues(alpha: 0.85), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pillBtn(String label, String value, IconData icon) {
    final sel = _format == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : () { if (!sel) { setState(() => _format = value); _load(); } },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF38d5c1).withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? const Color(0xFF38d5c1) : Colors.white24, width: sel ? 2 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: sel ? const Color(0xFF38d5c1) : (isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF38d5c1) : (isDark ? Colors.white70 : Colors.black87))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bgCard(String label, String value, IconData icon) {
    final sel = _bgMode == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _bgColors[value];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _loading ? null : () { if (!sel) { setState(() => _bgMode = value); _load(); } },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF38d5c1).withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? const Color(0xFF38d5c1) : Colors.white24, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: c ?? (isDark ? const Color(0xFF1a1a2e) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: c == null ? Icon(icon, size: 14, color: Colors.white54) : null,
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF38d5c1) : (isDark ? Colors.white70 : Colors.black87))),
          ]),
        ),
      ),
    );
  }
}

/// 透明效果用的棋盘格背景，24px 一格，深浅灰交替。
class _CheckerPainter extends CustomPainter {
  static const _size = 24.0;
  static const _light = Color(0xFFd9dde3);
  static const _dark = Color(0xFFaab1bd);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _light);
    final darkPaint = Paint()..color = _dark;
    for (var y = 0.0; y < size.height; y += _size) {
      for (var x = 0.0; x < size.width; x += _size) {
        if (((x ~/ _size) + (y ~/ _size)) % 2 == 1) {
          canvas.drawRect(Rect.fromLTWH(x, y, _size, _size), darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) => false;
}
