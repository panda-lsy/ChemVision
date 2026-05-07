import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/structure_controller.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/pulse_dots.dart';
import 'result_page.dart';

class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key, required this.query, this.mode});

  final String query;
  final String? mode;

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(structureControllerProvider.notifier)
          .generate(widget.query, mode: widget.mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StructureState>(structureControllerProvider, (prev, next) {
      if (prev?.status == next.status) {
        return;
      }

      if (next.status == StructureStatus.success && next.result != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultPage(query: widget.query, result: next.result!),
          ),
        );
      } else if (next.status == StructureStatus.failure) {
        final message = next.errorMessage ?? '解析失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop();
      }
    });

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              const AccentPill(label: '结构推理中'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                radius: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.aqua, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      '正在解析...',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '端侧意图识别 · 延迟 <100ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    const PulseDots(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
