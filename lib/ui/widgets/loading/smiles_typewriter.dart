import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class SmilesTypewriter extends StatefulWidget {
  const SmilesTypewriter({
    super.key,
    required this.smiles,
    this.active = false,
    this.charDuration = const Duration(milliseconds: 55),
  });

  final String smiles;
  final bool active;
  final Duration charDuration;

  @override
  State<SmilesTypewriter> createState() => _SmilesTypewriterState();
}

class _SmilesTypewriterState extends State<SmilesTypewriter>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller?.dispose();
    _controller = null;
    _charCount = 0;
    if (widget.smiles.isEmpty) return;

    final totalDuration = widget.charDuration * widget.smiles.length;
    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    )..addListener(() {
        final newCount =
            (_controller!.value * widget.smiles.length).floor();
        if (newCount != _charCount) {
          setState(() {
            _charCount = newCount.clamp(0, widget.smiles.length);
          });
        }
      });

    if (widget.active) {
      _controller!.forward();
    }
  }

  @override
  void didUpdateWidget(SmilesTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.smiles != widget.smiles ||
        oldWidget.active != widget.active) {
      _initController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayText = widget.active
        ? widget.smiles.substring(0, _charCount)
        : widget.smiles;

    return AnimatedOpacity(
      opacity: displayText.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      child: AnimatedSlide(
        offset:
            displayText.isNotEmpty ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 350),
        child: Text(
          displayText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'Courier New',
                fontFamilyFallback: ['monospace'],
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                letterSpacing: 0.5,
                fontSize: 13,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
