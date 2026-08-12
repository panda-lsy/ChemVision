/// 初次启动引导 — 设置头像、昵称、学段
///
/// 触发条件:首次启动(SharedPreferences 标记 'onboarding_completed' 未设置)。
/// 完成后更新当前用户并写入标记,避免重复显示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

/// 学段选项
const _stageOptions = <String>['middle', 'highschool', 'college', 'research'];

String _stageLabel(String stage) => switch (stage) {
      'middle' => '初中',
      'highschool' => '高中',
      'college' => '大学本科/研究生/博士',
      'research' => '科研工作',
      _ => stage,
    };

const _onboardingKey = 'onboarding_completed';

/// 是否已完成 onboarding(用于判断是否要显示引导)
Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingKey) ?? false;
}

/// Onboarding 引导页
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final TextEditingController _nicknameController = TextEditingController();
  String? _avatarPath;
  String _selectedStage = 'highschool';
  bool _saving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _avatarPath = image.path);
    }
  }

  Future<void> _complete() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final userService = ref.read(userServiceProvider);
      final currentUser = userService.currentUser;
      if (currentUser != null) {
        await userService.updateUser(currentUser.copyWith(
          nickname: nickname,
          stage: _selectedStage,
          avatarPath: _avatarPath,
        ));
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);

      if (mounted) {
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.aqua : AppColors.dayBluePrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyDeep : AppColors.dayBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头部
              Icon(
                Icons.science,
                size: 48,
                color: accent,
              ),
              const SizedBox(height: 12),
              Text(
                '欢迎使用 ChemEdu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '先设置你的基本信息,以便 Agent 提供个性化的化学学习辅导。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // 头像选择
              GestureDetector(
                onTap: _pickAvatar,
                child: Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _avatarPath != null
                          ? Image.network(
                              _avatarPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarPlaceholder(accent, isDark),
                            )
                          : _avatarPlaceholder(accent, isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击选择头像(可选)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                ),
              ),
              const SizedBox(height: 24),

              // 昵称
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: '昵称',
                  hintText: '请输入你的昵称',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: isDark ? AppColors.glass : AppColors.dayGlass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 16),

              // 学段
              Text(
                '学段',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stageOptions.map((stage) {
                  final selected = stage == _selectedStage;
                  return ChoiceChip(
                    label: Text(_stageLabel(stage)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedStage = stage),
                    selectedColor: accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? accent
                          : (isDark ? AppColors.textSecondary : AppColors.dayTextSecondary),
                    ),
                    side: BorderSide(
                      color: selected ? accent : accent.withValues(alpha: 0.2),
                    ),
                    backgroundColor: isDark ? AppColors.glass : AppColors.dayGlass,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // 完成按钮
              FilledButton(
                onPressed: _saving ? null : _complete,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isDark ? AppColors.ink : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '开始使用',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                '你可以在「我的」页面随时修改这些信息。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(Color accent, bool isDark) {
    return Container(
      color: isDark ? AppColors.glass : AppColors.dayGlass,
      child: Icon(
        Icons.camera_alt,
        color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
      ),
    );
  }
}
