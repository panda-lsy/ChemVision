import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_auth_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _authService = SupabaseAuthService.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  Future<bool>? _ownerCheck;
  bool _isSigningUp = false;
  bool _isBusy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    if (!SupabaseAuthService.isInitialized) return;

    _user = _authService.currentUser;
    _updateOwnerCheck();
    _authSubscription = _authService.authStateChanges.listen((authState) {
      if (!mounted) return;
      setState(() {
        _user = authState.session?.user;
        _message = null;
        _updateOwnerCheck();
      });
    });
  }

  void _updateOwnerCheck() {
    _ownerCheck = _user == null ? null : _checkOwner();
  }

  Future<bool> _checkOwner() async {
    try {
      return await _authService.isCurrentUserOwner();
    } catch (_) {
      // 未部署数据库迁移或当前账号不具备 Owner 身份时不显示管理入口。
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      if (_isSigningUp) {
        final response = await _authService.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (response.session == null && mounted) {
          _showMessage('注册已提交，请打开邮箱中的确认链接完成验证。');
        }
      } else {
        await _authService.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } catch (error) {
      if (mounted) _showMessage('认证请求失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signInWithGitHub() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      final launched = await _authService.signInWithGitHub();
      if (!launched && mounted) {
        _showMessage('未能打开 GitHub 登录页面，请检查系统浏览器设置。',
            isError: true);
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } catch (error) {
      if (mounted) _showMessage('GitHub 登录失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await _authService.signOut();
    } catch (error) {
      if (mounted) _showMessage('退出登录失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与管理')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!SupabaseAuthService.isConfigured ||
                  !SupabaseAuthService.isInitialized)
                _buildNotConfigured()
              else if (_user == null)
                _buildSignInForm()
              else
                _buildSignedInAccount(),
              if (_message != null) ...[
                const SizedBox(height: 16),
                _MessageBanner(
                  message: _message!,
                  isError: _messageIsError,
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                '学习记录仍保存在当前设备；登录账号用于身份验证和管理员权限。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotConfigured() {
    final failure = SupabaseAuthService.initializationFailure;
    final description = !SupabaseAuthService.isConfigured
        ? '登录后端尚未配置。请按仓库 docs/backend-auth.md 创建 Supabase 项目、应用数据库迁移，并通过 --dart-define 提供项目 URL 和 Publishable Key。'
        : 'Supabase 初始化失败：$failure';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 32),
            const SizedBox(height: 12),
            Text('登录服务未就绪',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SelectableText(description),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.science_outlined,
                  size: 36, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                _isSigningUp ? '创建 ChemVision 账号' : '登录 ChemVision',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                enabled: !_isBusy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(email)) {
                    return '请输入有效邮箱地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                enabled: !_isBusy,
                obscureText: true,
                autofillHints: _isSigningUp
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: '密码（至少 8 位）',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 8) return '密码至少需要 8 位';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isBusy ? null : _submitEmail,
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.email_outlined),
                label: Text(_isSigningUp ? '邮箱注册' : '邮箱登录'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _signInWithGitHub,
                icon: const Icon(Icons.code),
                label: const Text('使用 GitHub 登录 / 注册'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() {
                          _isSigningUp = !_isSigningUp;
                          _message = null;
                        }),
                child: Text(_isSigningUp ? '已有账号？返回登录' : '还没有账号？邮箱注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignedInAccount() {
    final user = _user!;
    final githubUsername = user.userMetadata?['user_name'] ??
        user.userMetadata?['preferred_username'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_user_outlined, size: 34),
            const SizedBox(height: 12),
            Text(
              user.email ?? (githubUsername?.toString() ?? '已登录用户'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '登录方式：${user.appMetadata['providers'] is List ? (user.appMetadata['providers'] as List).join('、') : '邮箱'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: _ownerCheck,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.data != true) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.tonalIcon(
                    onPressed: _isBusy ? null : _openAdminPage,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('管理员页面'),
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdminPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const _pageSize = 50;
  final _authService = SupabaseAuthService.instance;
  int _page = 1;
  late Future<AdminUsersPageData> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  Future<AdminUsersPageData> _fetchUsers() {
    return _authService.listUsers(page: _page, perPage: _pageSize);
  }

  void _reload() {
    setState(() => _usersFuture = _fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<AdminUsersPageData>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AdminError(
              message: '读取用户列表失败：${snapshot.error}',
              onRetry: _reload,
            );
          }

          final result = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('第 ${result.page} 页 · ${result.users.length} 位用户'),
                ),
              ),
              Expanded(
                child: result.users.isEmpty
                    ? const Center(child: Text('暂无用户'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: result.users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _AdminAccountTile(account: result.users[index]),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _page > 1
                            ? () => setState(() {
                                  _page -= 1;
                                  _usersFuture = _fetchUsers();
                                })
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一页'),
                      ),
                      OutlinedButton.icon(
                        onPressed: result.hasMore
                            ? () => setState(() {
                                  _page += 1;
                                  _usersFuture = _fetchUsers();
                                })
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('下一页'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminAccountTile extends StatelessWidget {
  const _AdminAccountTile({required this.account});

  final AdminAccount account;

  @override
  Widget build(BuildContext context) {
    final details = <String>['登录方式：${account.providerLabel}'];
    if (account.githubUsername != null) {
      details.add('GitHub：${account.githubUsername}');
    }
    if (account.createdAt != null) {
      details.add('注册：${_formatDate(account.createdAt!)}');
    }
    if (account.lastSignInAt != null) {
      details.add('最近登录：${_formatDate(account.lastSignInAt!)}');
    }

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(account.email ?? '无邮箱账号'),
        subtitle: Text(details.join('\n')),
        isThreeLine: details.length >= 3,
      ),
    );
  }

  String _formatDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
