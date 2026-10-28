import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/asr_provider.dart';
import '../../theme/app_colors.dart';

Future<String?> showVoiceInputOverlay(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(asrControllerProvider.notifier);

  final started = await controller.start();
  if (!context.mounted) {
    await controller.cancel();
    return null;
  }
  if (!started) {
    final error = ref.read(asrControllerProvider).error ?? '语音识别暂不可用';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return null;
  }

  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceInputSheet(),
  );
}

class _VoiceInputSheet extends ConsumerStatefulWidget {
  const _VoiceInputSheet();

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _hasHandledResult = false; // 防止重复处理

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    // Ensure ASR resources are cleaned if the sheet is dismissed unexpectedly
    try {
      ref.read(asrControllerProvider.notifier).cancel();
    } catch (_) {}
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(asrControllerProvider);

    // 处理结果（只处理一次）
    if (!_hasHandledResult) {
      if (state.status == AsrStatus.done && state.finalText != null) {
        _hasHandledResult = true;
        // 使用延迟确保状态已完全更新
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) {
            Navigator.of(context).pop(state.finalText);
          }
        });
      }
      if (state.status == AsrStatus.error && state.error != null) {
        _hasHandledResult = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
            Navigator.of(context).pop();
          }
        });
      }
    }

    final isRecording = state.status == AsrStatus.recording;
    final isProcessing = state.status == AsrStatus.processing;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Microphone icon with pulse
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = isRecording
                        ? 1.0 + _pulseController.value * 0.15
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRecording
                              ? AppColors.aqua.withValues(alpha: 0.2)
                              : AppColors.glassStrong,
                          border: Border.all(
                            color: isRecording
                                ? AppColors.aqua
                                : AppColors.textMuted,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isProcessing ? Icons.hourglass_top : Icons.mic,
                          size: 36,
                          color: isRecording
                              ? AppColors.aqua
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Status text
                Text(
                  isProcessing
                      ? '正在识别...'
                      : isRecording
                      ? '正在录音'
                      : '准备中',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Duration
                Text(
                  _formatDuration(state.elapsedSeconds),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.aqua,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),

                // Partial result
                if (state.partialText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.partialText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          await ref
                              .read(asrControllerProvider.notifier)
                              .cancel();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.aqua,
                          foregroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isRecording
                            ? () async {
                                await ref
                                    .read(asrControllerProvider.notifier)
                                    .stop();
                              }
                            : null,
                        child: Text(isProcessing ? '处理中...' : '完成'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
