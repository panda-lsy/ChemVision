import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/structure_controller.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/loading/molecule_visual_area.dart';
import '../widgets/loading/smiles_typewriter.dart';
import '../widgets/loading/stage_progress_indicator.dart';
import '../widgets/pulse_dots.dart';
import 'result_page.dart';

class _StageInfo {
  const _StageInfo({
    required this.statusText,
    required this.pillText,
    required this.subtle,
  });

  final String statusText;
  final String pillText;
  final String subtle;
}

class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key, required this.query, this.mode});

  final String query;
  final String? mode;

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  bool get _isInfer => widget.mode == 'infer';

  static const _defaultStages = [
    _StageInfo(
      statusText: '意图识别中...',
      pillText: '端侧模型',
      subtle: '端侧路由 · 延迟 <100ms',
    ),
    _StageInfo(
      statusText: 'SMILES 生成中...',
      pillText: '结构推理中',
      subtle: '云端 AI API · 命名解析 → SMILES',
    ),
    _StageInfo(
      statusText: '规则校验中...',
      pillText: '规则校验中',
      subtle: 'RDKit 校验层 · 价态/键合法性验证',
    ),
    _StageInfo(
      statusText: '渲染输出中...',
      pillText: '渲染输出中',
      subtle: 'SVG 键线式图 · 分子属性计算',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(structureControllerProvider.notifier)
          .generate(widget.query, mode: widget.mode);
    });
  }

  _StageInfo _stageInfoFor(LoadingStage stage, int candidateCount) {
    final index = stage.index;
    if (!_isInfer) return _defaultStages[index];
    switch (index) {
      case 1:
        return const _StageInfo(
          statusText: '候选生成中...',
          pillText: '推测推理中',
          subtle: '云端 AI API · 候选名称推理',
        );
      case 2:
        final countText =
            candidateCount > 0 ? ' · 发现 $candidateCount 个候选' : '';
        return _StageInfo(
          statusText: '规则校验中...',
          pillText: '规则校验中',
          subtle: 'PubChem/OPSIN 多候选校验$countText',
        );
      default:
        return _defaultStages[index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(structureControllerProvider);

    ref.listen<StructureState>(structureControllerProvider, (prev, next) {
      if (next.status == StructureStatus.success && next.result != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => ResultPage(
              query: widget.query,
              result: next.result!,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              );
            },
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

    final stage = _stageInfoFor(state.currentStage, state.candidateCount);

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemEdu',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              AccentPill(label: stage.pillText),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoleculeVisualArea(
                      stage: state.currentStage.index,
                      smiles: widget.query,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        stage.statusText,
                        key: ValueKey(stage.statusText),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        stage.subtle,
                        key: ValueKey(stage.subtle),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 28),
                    StageProgressIndicator(
                        currentStage: state.currentStage.index),
                    const SizedBox(height: 16),
                    if (state.currentStage.index >= 1)
                      SmilesTypewriter(
                        smiles: widget.query,
                        active: state.currentStage ==
                            LoadingStage.structureInference,
                      ),
                    const SizedBox(height: 20),
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
