import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 认证与管理员 API 的薄封装。
///
/// 客户端只接收公开 publishable key；service_role key 仅配置在 Edge Function。
class SupabaseAuthService {
  SupabaseAuthService._();

  static const _projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _nativeRedirectUri =
      'com.chemvision.chemvision://auth-callback/';

  static bool _initialized = false;
  static Object? _initializationFailure;

  static bool get isConfigured =>
      _projectUrl.startsWith('https://') && _publishableKey.isNotEmpty;

  static bool get isInitialized => _initialized;

  static Object? get initializationFailure => _initializationFailure;

  static SupabaseAuthService get instance => SupabaseAuthService._();

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) return;

    try {
      await Supabase.initialize(
        url: _projectUrl,
        publishableKey: _publishableKey,
      );
      _initialized = true;
      _initializationFailure = null;
    } catch (error) {
      _initializationFailure = error;
      debugPrint('[SupabaseAuthService] 初始化失败：$error');
    }
  }

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase 尚未配置或初始化失败');
    }
    return Supabase.instance.client;
  }

  User? get currentUser => _initialized ? client.auth.currentUser : null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  String get _redirectUri {
    if (!kIsWeb) return _nativeRedirectUri;

    final currentUri = Uri.base;
    final path = currentUri.path.endsWith('/')
        ? currentUri.path
        : '${currentUri.path}/';
    return '${currentUri.origin}$path';
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _redirectUri,
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> signInWithGitHub() {
    return client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: _redirectUri,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _redirectUri,
    );
  }

  Future<void> signOut() => client.auth.signOut();

  /// Owner 由服务端根据已验证的 GitHub identity 判定，不读取客户端 metadata。
  Future<bool> isCurrentUserOwner() async {
    final result = await client.rpc('is_chemvision_owner');
    return result == true;
  }

  Future<AdminUsersPageData> listUsers({
    required int page,
    int perPage = 50,
  }) async {
    final response = await client.functions.invoke(
      'admin-users',
      body: {'page': page, 'perPage': perPage},
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError('管理员接口返回 HTTP ${response.status}');
    }

    final payload = response.data;
    if (payload is! Map || payload['users'] is! List) {
      throw const FormatException('管理员接口返回格式无效');
    }

    final users = (payload['users'] as List)
        .whereType<Map>()
        .map((user) => AdminAccount.fromJson(
              Map<String, dynamic>.from(user),
            ))
        .toList(growable: false);

    return AdminUsersPageData(
      users: users,
      page: payload['page'] is int ? payload['page'] as int : page,
      perPage:
          payload['perPage'] is int ? payload['perPage'] as int : perPage,
      hasMore: payload['hasMore'] == true,
    );
  }
}

class AdminUsersPageData {
  const AdminUsersPageData({
    required this.users,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });

  final List<AdminAccount> users;
  final int page;
  final int perPage;
  final bool hasMore;
}

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.lastSignInAt,
    required this.providers,
    required this.githubUsername,
  });

  final String id;
  final String? email;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final List<String> providers;
  final String? githubUsername;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) => value is String
        ? DateTime.tryParse(value)?.toLocal()
        : null;

    final rawProviders = json['providers'];
    final rawUsername = json['githubUsername'];

    return AdminAccount(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      createdAt: parseDate(json['createdAt']),
      lastSignInAt: parseDate(json['lastSignInAt']),
      providers: rawProviders is List
          ? rawProviders.whereType<String>().toList(growable: false)
          : const [],
      githubUsername: rawUsername is String ? rawUsername : null,
    );
  }

  String get providerLabel {
    final labels = providers.map((provider) {
      return switch (provider) {
        'github' => 'GitHub',
        'email' => '邮箱',
        _ => provider,
      };
    }).toSet();
    return labels.isEmpty ? '未知' : labels.join('、');
  }
}
