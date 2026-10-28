/// "我的"页面 — 用户日常配置入口
///
/// 功能:
/// - 顶部卡片展示当前本机学习档案，并进入统一的账户中心
/// - 学情画像入口
/// - 设置入口(模型/主题等)
/// - 关于
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import 'account_page.dart';
import '../../theme/app_colors.dart';
import '../widgets/avatar_image_provider.dart';
import '../widgets/glass_panel.dart';
import 'learning_profile_page.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userService = ref.watch(userServiceProvider);
    final currentUser =
        ref.watch(currentUserProvider) ?? userService.currentUser;

    return AppScaffoldWidget(
      isDark: isDark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // 顶部标题
          Text(
            '我的',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // 当前本机学习档案(点击进入统一账户中心)
          if (currentUser != null)
            _UserCard(
              user: currentUser,
              isDark: isDark,
              onTap: () => _openAccountCenter(context),
            ),
          const SizedBox(height: 16),

          // 功能入口
          _MenuGroup(
            isDark: isDark,
            items: [
              _MenuItem(
                icon: Icons.account_circle_outlined,
                iconColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                title: '账户中心',
                subtitle: '在线登录 / 本机学习档案 / 管理员入口',
                onTap: () => _openAccountCenter(context),
              ),
              _MenuItem(
                icon: Icons.radar,
                iconColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                title: '学情画像',
                subtitle: '雷达图查看掌握度分布与薄弱点',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LearningProfilePage(),
                  ),
                ),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                iconColor: isDark ? AppColors.amber : const Color(0xFFE07B00),
                title: '设置',
                subtitle: '模型配置 / 主题 / 隐私合规',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 关于
          _MenuGroup(
            isDark: isDark,
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                iconColor: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
                title: '关于 ChemVision',
                subtitle: '版本与说明',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAccountCenter(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.navy
            : Colors.white,
        title: const Text('关于 ChemVision'),
        content: const Text(
          'ChemVision — 面向化学的个性化学习 Agent\n'
          '支持结构识别、性质编辑、学情诊断、作业辅导等能力。\n'
          '学情数据仅本地存储,不上传。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 简化版 AppScaffold 包装(避免和 settings_page 的 AppScaffold 重名)
class AppScaffoldWidget extends StatelessWidget {
  const AppScaffoldWidget({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.navyDeep : AppColors.dayBackground,
      body: SafeArea(child: child),
    );
  }
}

/// 顶部用户卡片
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isDark,
    required this.onTap,
  });

  final AppUser user;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            _Avatar(
              avatarPath: user.avatarPath,
              nickname: user.nickname,
              isDark: isDark,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.dayTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.stageLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.aqua
                            : AppColors.dayBluePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '本机学习档案 · 点击进入账户中心',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.dayTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单组
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.isDark, required this.items});
  final bool isDark;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      radius: 16,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.06,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }
}

/// 头像渲染，兼容数据 URI、远程 URL 和旧版本地文件路径。
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarPath,
    required this.nickname,
    required this.isDark,
    required this.size,
  });

  final String? avatarPath;
  final String nickname;
  final bool isDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = avatarImageProvider(avatarPath);
    if (imageProvider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _default(),
        ),
      );
    }
    return _default();
  }

  Widget _default() {
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.aqua, AppColors.lime]
              : [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}
