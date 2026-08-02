/// 知识点掌握度雷达图 — 自定义 CustomPainter
///
/// 对应赛题"学情诊断 Agent"评审加分项:用雷达图直观展示知识点掌握度分布。
/// 每个轴代表一个化学分类(有机/无机/物理/分析/生化学),显示平均掌握度。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 雷达图数据点
class RadarEntry {
  const RadarEntry({
    required this.label,
    required this.value,
    this.subtitle,
  });

  /// 轴标签(如"有机化学")
  final String label;

  /// 数值 0.0~1.0
  final double value;

  /// 副标题(如该分类下知识点数)
  final String? subtitle;
}

/// 掌握度雷达图
class MasteryRadarChart extends StatelessWidget {
  const MasteryRadarChart({
    super.key,
    required this.entries,
    this.size = 280,
    this.maxValue = 1.0,
  });

  final List<RadarEntry> entries;

  /// 图表尺寸(正方形)
  final double size;

  /// 数值上限(默认 1.0,即 100%)
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarChartPainter(
          entries: entries,
          isDark: isDark,
          maxValue: maxValue,
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.entries,
    required this.isDark,
    required this.maxValue,
  });

  final List<RadarEntry> entries;
  final bool isDark;
  final double maxValue;

  static const int _gridLevels = 4;
  static const double _labelPadding = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - _labelPadding;
    final axisCount = entries.length;
    if (axisCount < 3) {
      _drawEmpty(canvas, center, radius);
      return;
    }

    // 1. 绘制网格(同心多边形)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white12 : const Color(0x223D77DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var level = 1; level <= _gridLevels; level++) {
      final r = radius * level / _gridLevels;
      final path = Path();
      for (var i = 0; i < axisCount; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / axisCount;
        final point = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 2. 绘制轴线
    final axisPaint = Paint()
      ..color = isDark ? Colors.white10 : const Color(0x113D77DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < axisCount; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / axisCount;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, point, axisPaint);
    }

    // 3. 绘制数据多边形(填充 + 边框)
    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (var i = 0; i < axisCount; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / axisCount;
      final v = (entries[i].value / maxValue).clamp(0.0, 1.0);
      final r = radius * v;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      dataPoints.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..color = (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
          .withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    final strokePaint = Paint()
      ..color = isDark ? AppColors.aqua : AppColors.dayBluePrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // 4. 绘制数据点
    final pointPaint = Paint()
      ..color = isDark ? AppColors.lime : AppColors.dayBlueAccent
      ..style = PaintingStyle.fill;
    for (final p in dataPoints) {
      canvas.drawCircle(p, 3.5, pointPaint);
      // 外圈白色描边
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = isDark ? AppColors.navy : Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(p, 2.5, pointPaint);
    }

    // 5. 绘制刻度标签(25%/50%/75%/100%)
    final scalePainter = TextPainter(textDirection: TextDirection.ltr);
    for (var level = 1; level <= _gridLevels; level++) {
      final v = maxValue * level / _gridLevels;
      final label = '${(v * 100).round()}%';
      scalePainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
        ),
      );
      scalePainter.layout();
      // 标签放在垂直轴上(即 0 度方向,顶部)
      scalePainter.paint(
        canvas,
        Offset(center.dx - scalePainter.width / 2 + 2,
            center.dy - radius * level / _gridLevels - 6),
      );
    }

    // 6. 绘制轴标签(分类名)
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < axisCount; i++) {
      final entry = entries[i];
      final angle = -math.pi / 2 + 2 * math.pi * i / axisCount;
      final labelOffset = radius + 12;
      final labelPoint = Offset(
        center.dx + labelOffset * math.cos(angle),
        center.dy + labelOffset * math.sin(angle),
      );

      // 主标签
      labelPainter.text = TextSpan(
        text: entry.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
        ),
      );
      labelPainter.layout();
      // 根据 x 位置对齐
      final alignment = _labelAlignment(angle);
      final dx = labelPoint.dx -
          labelPainter.width / 2 +
          alignment * labelPainter.width / 2;
      labelPainter.paint(canvas, Offset(dx, labelPoint.dy - 6));

      // 副标签(数值或详情)
      if (entry.subtitle != null) {
        final subPainter = TextPainter(textDirection: TextDirection.ltr);
        subPainter.text = TextSpan(
          text: entry.subtitle,
          style: TextStyle(
            fontSize: 10,
            color: _valueColor(entry.value, isDark),
          ),
        );
        subPainter.layout();
        final subDx = labelPoint.dx -
            subPainter.width / 2 +
            alignment * subPainter.width / 2;
        subPainter.paint(canvas, Offset(subDx, labelPoint.dy + 8));
      }
    }
  }

  /// 标签水平对齐:-1 左对齐 / 0 居中 / 1 右对齐
  double _labelAlignment(double angle) {
    final cos = math.cos(angle);
    if (cos > 0.3) return 1;
    if (cos < -0.3) return -1;
    return 0;
  }

  Color _valueColor(double value, bool isDark) {
    if (value < 0.6) return const Color(0xFFEF5350);
    if (value < 0.8) return isDark ? AppColors.amber : const Color(0xFFE07B00);
    return isDark ? AppColors.lime : const Color(0xFF3D8E3D);
  }

  void _drawEmpty(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.6, paint);
  }

  @override
  bool shouldRepaint(_RadarChartPainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.isDark != isDark ||
      oldDelegate.maxValue != maxValue;
}
