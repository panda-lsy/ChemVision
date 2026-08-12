/// "我的"页面 — 用户日常配置入口
///
/// 功能:
/// - 顶部用户卡片(头像/昵称/学段,点击进入用户管理 sheet)
/// - 学情画像入口
/// - 设置入口(模型/主题等)
/// - 关于
///
/// "设置"页保留对用户管理区块的查看能力(参见 settings_page.dart)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/learning_profile_provider.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../providers/scan_history_provider.dart';
import '../../providers/error_book_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import 'learning_profile_page.dart';
import 'settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userService = ref.watch(userServiceProvider);
    final currentUser = userService.currentUser;

    return AppScaffoldWidget(
      isDark: isDark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // 顶部标题
          Text(
            '我的',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),

          // 用户卡片(点击进入用户管理 sheet)
          if (currentUser != null)
            _UserCard(
              user: currentUser,
              isDark: isDark,
              onTap: () => _showUserManagementSheet(context, ref),
            ),
          const SizedBox(height: 16),

          // 功能入口
          _MenuGroup(
            isDark: isDark,
            items: [
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
                icon: Icons.people_outline,
                iconColor: isDark ? AppColors.lime : const Color(0xFF2E7D32),
                title: '用户管理',
                subtitle: '多用户切换 / 创建 / 编辑',
                onTap: () => _showUserManagementSheet(context, ref),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                iconColor: isDark ? AppColors.amber : const Color(0xFFE07B00),
                title: '设置',
                subtitle: '模型配置 / 主题 / 隐私合规',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
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
                iconColor: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                title: '关于 ChemEdu',
                subtitle: '版本与说明',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserManagementSheet(BuildContext context, WidgetRef ref) {
    // 复用 settings_page 中的 UserManagementSection 的 sheet 弹窗
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UserManagementSheet(),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.navy
            : Colors.white,
        title: const Text('关于 ChemEdu'),
        content: const Text(
          'ChemEdu — 面向化学的个性化学习 Agent\n'
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
      backgroundColor:
          isDark ? AppColors.navyDeep : AppColors.dayBackground,
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
                      color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.stageLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '点击管理用户',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? AppColors.textMuted : AppColors.dayTextMuted,
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
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
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
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }
}

/// 头像渲染(复用 user_management_section 的逻辑,本地路径用 Image.file/network 兼容)
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
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarPath!,
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

/// 用户管理底部弹窗(复用 UserManagementSection 的内部 sheet)
///
/// 直接用 UserManagementSection 触发的同款 sheet,保持一致性。
class _UserManagementSheet extends StatelessWidget {
  const _UserManagementSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.navy : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 20,
                  color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  '用户管理',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          Divider(
            color: isDark
                ? Colors.white12
                : AppColors.dayBluePrimary.withValues(alpha: 0.08),
          ),
          Expanded(
            child: UserManagementList(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

/// 暴露一个可独立使用的用户列表(避免修改 UserManagementSection 的私有类)
/// 通过直接调用 UserService 渲染。
class UserManagementList extends ConsumerWidget {
  const UserManagementList({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userService = ref.watch(userServiceProvider);
    final users = userService.allUsers;
    final currentUserId = userService.currentUserId;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isCurrent = user.id == currentUserId;
        return _UserRow(
          user: user,
          isCurrent: isCurrent,
          isDark: isDark,
          onTap: () async {
            if (!isCurrent) {
              await userService.switchUser(user.id);
              _refreshAllProviders(ref);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已切换到 ${user.nickname}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _refreshAllProviders(WidgetRef ref) {
    ref.invalidate(scanHistoryControllerProvider);
    ref.invalidate(favoritesControllerProvider);
    ref.invalidate(reactionFavoritesControllerProvider);
    ref.invalidate(errorBookControllerProvider);
    ref.invalidate(learningProfileControllerProvider);
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isCurrent,
    required this.isDark,
    required this.onTap,
  });

  final AppUser user;
  final bool isCurrent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                .withValues(alpha: 0.08)
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(
                color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                    .withValues(alpha: 0.3),
              )
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: _Avatar(
          avatarPath: user.avatarPath,
          nickname: user.nickname,
          isDark: isDark,
          size: 40,
        ),
        title: Row(
          children: [
            Text(
              user.nickname,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '当前',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(user.stageLabel),
      ),
    );
  }
}
