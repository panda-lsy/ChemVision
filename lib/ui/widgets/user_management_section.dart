/// 用户管理区域 — 多用户切换、创建、编辑、删除
///
/// 在设置页中展示当前用户信息,点击进入用户管理底部弹窗。
/// 切换用户后通过 ref.invalidate() 刷新所有数据 Provider。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/learning_profile_provider.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../providers/scan_history_provider.dart';
import '../../providers/error_book_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/glass_panel.dart';

/// 学段选项
const _stageOptions = <String>['middle', 'highschool', 'college', 'research'];

String _stageLabel(String stage) => switch (stage) {
      'middle' => '初中',
      'highschool' => '高中',
      'college' => '大学本科/研究生/博士',
      'research' => '科研工作',
      _ => stage,
    };

class UserManagementSection extends ConsumerWidget {
  const UserManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userService = ref.watch(userServiceProvider);
    final currentUser = userService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return GlassPanel(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUserManagementSheet(context, ref),
        child: Row(
          children: [
            _UserAvatar(
              avatarPath: currentUser.avatarPath,
              nickname: currentUser.nickname,
              isDark: isDark,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.nickname,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stageLabel(currentUser.stage),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
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

  void _showUserManagementSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? AppColors.navy : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖拽指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
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
                    TextButton.icon(
                      onPressed: () => _showCreateUserDialog(context, ref),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('新建'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark
                    ? Colors.white12
                    : AppColors.dayBluePrimary.withValues(alpha: 0.08),
              ),
              // 用户列表
              Expanded(child: _UserList(isDark: isDark)),
            ],
          ),
        );
      },
    );
  }

  void _showCreateUserDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _UserEditDialog(
        isCreate: true,
        onSaved: (nickname, stage, avatarPath) async {
          final userService = ref.read(userServiceProvider);
          await userService.createUser(
            nickname: nickname,
            stage: stage,
            avatarPath: avatarPath,
          );
          if (context.mounted) {
            Navigator.of(context).pop(); // 关闭底部弹窗
          }
        },
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList({required this.isDark});
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
        return _UserListTile(
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
          onEdit: () => _showEditDialog(context, ref, user),
          onDelete: users.length > 1
              ? () => _confirmDelete(context, ref, user)
              : null,
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => _UserEditDialog(
        isCreate: false,
        initialNickname: user.nickname,
        initialStage: user.stage,
        initialAvatarPath: user.avatarPath,
        onSaved: (nickname, stage, avatarPath) async {
          final userService = ref.read(userServiceProvider);
          await userService.updateUser(user.copyWith(
            nickname: nickname,
            stage: stage,
            avatarPath: avatarPath,
          ));
          _refreshAllProviders(ref);
          if (context.mounted) {
            Navigator.of(context).pop(); // 关闭底部弹窗
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('删除用户'),
        content: Text('确定要删除用户「${user.nickname}」吗?\n该用户的所有数据将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userService = ref.read(userServiceProvider);
              await userService.deleteUser(user.id);
              _refreshAllProviders(ref);
              if (context.mounted) {
                Navigator.of(context).pop(); // 关闭底部弹窗
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除用户 ${user.nickname}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE57373)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 切换/编辑/删除用户后刷新所有数据 Provider
  void _refreshAllProviders(WidgetRef ref) {
    ref.invalidate(scanHistoryControllerProvider);
    ref.invalidate(favoritesControllerProvider);
    ref.invalidate(reactionFavoritesControllerProvider);
    ref.invalidate(errorBookControllerProvider);
    ref.invalidate(learningProfileControllerProvider);
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.isCurrent,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  final AppUser user;
  final bool isCurrent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: _UserAvatar(
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
                color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                    color:
                        isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(_stageLabel(user.stage)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
                color: const Color(0xFFE57373),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
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
          errorBuilder: (_, __, ___) => _buildDefault(),
        ),
      );
    }
    return _buildDefault();
  }

  Widget _buildDefault() {
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

/// 创建/编辑用户对话框
class _UserEditDialog extends ConsumerStatefulWidget {
  const _UserEditDialog({
    required this.isCreate,
    required this.onSaved,
    this.initialNickname,
    this.initialStage,
    this.initialAvatarPath,
  });

  final bool isCreate;
  final void Function(String nickname, String stage, String? avatarPath)
      onSaved;
  final String? initialNickname;
  final String? initialStage;
  final String? initialAvatarPath;

  @override
  ConsumerState<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends ConsumerState<_UserEditDialog> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _avatarController;
  late String _selectedStage;

  @override
  void initState() {
    super.initState();
    _nicknameController =
        TextEditingController(text: widget.initialNickname ?? '');
    _avatarController =
        TextEditingController(text: widget.initialAvatarPath ?? '');
    _selectedStage = widget.initialStage ?? 'highschool';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarController.dispose();
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
      _avatarController.text = image.path;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.navy : Colors.white,
      title: Text(widget.isCreate ? '创建新用户' : '编辑用户'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.aqua.withValues(alpha: 0.3)
                          : AppColors.dayBluePrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipOval(
                    child: _avatarController.text.isNotEmpty
                        ? Image.network(
                            _avatarController.text,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildAvatarPlaceholder(isDark),
                          )
                        : _buildAvatarPlaceholder(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击选择头像',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                ),
              ),
              const SizedBox(height: 16),
              // 昵称
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 12),
              // 学段
              DropdownButtonFormField<String>(
                initialValue: _selectedStage,
                decoration: const InputDecoration(
                  labelText: '学段',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _stageOptions.map((stage) {
                  return DropdownMenuItem(
                    value: stage,
                    child: Text(_stageLabel(stage)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStage = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final nickname = _nicknameController.text.trim();
            if (nickname.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入昵称')),
              );
              return;
            }
            final avatarPath = _avatarController.text.trim();
            Navigator.pop(context);
            widget.onSaved(nickname, _selectedStage,
                avatarPath.isEmpty ? null : avatarPath);
          },
          child: Text(widget.isCreate ? '创建' : '保存'),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.glass : AppColors.dayGlass,
      child: Icon(
        Icons.camera_alt,
        color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
      ),
    );
  }
}
