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

  bool get hasSupportedAiSignInProvider {
    final user = currentUser;
    if (user == null) return false;
    final providers = <String>{};
    final appProviders = user.appMetadata['providers'];
    if (appProviders is List) {
      providers.addAll(
        appProviders.whereType<String>().map((value) => value.toLowerCase()),
      );
    }
    final appProvider = user.appMetadata['provider'];
    if (appProvider is String) providers.add(appProvider.toLowerCase());
    final identities = user.identities;
    if (identities != null) {
      providers.addAll(
        identities.map((identity) => identity.provider.toLowerCase()),
      );
    }
    return providers.contains('email') || providers.contains('github');
  }

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

  Future<ChemVisionAiQuota> getChemVisionAiQuota() async {
    if (!hasSupportedAiSignInProvider) {
      return const ChemVisionAiQuota(
        used: 0,
        reserved: 0,
        remaining: 0,
        limit: 5,
        unlimited: false,
      );
    }
    try {
      final response = await client.functions.invoke(
        'chemvision-ai',
        body: {'action': 'usage'},
      );
      final payload = _record(response.data);
      final quota =
          ChemVisionAiQuota.fromJson(_record(payload?['quota']) ?? {});
      if (response.status < 200 || response.status >= 300) {
        throw StateError(_aiErrorMessage(payload?['error']));
      }
      return quota;
    } on FunctionException catch (error) {
      final payload = _record(error.details);
      throw StateError(_aiErrorMessage(payload?['error'], status: error.status));
    }
  }

  Future<String> generateChemVisionAi({
    required String prompt,
    String? imageDataUri,
  }) async {
    if (!hasSupportedAiSignInProvider) {
      throw StateError('请先使用邮箱或 GitHub 登录/注册，才能使用 ChemVision AI。');
    }

    try {
      final response = await client.functions.invoke(
        'chemvision-ai',
        body: {
          'prompt': prompt,
          if (imageDataUri != null) 'imageDataUri': imageDataUri,
        },
      );
      final payload = _record(response.data);
      if (response.status < 200 || response.status >= 300) {
        throw StateError(_aiErrorMessage(payload?['error']));
      }
      final text = payload?['text'];
      if (text is! String || text.trim().isEmpty) {
        throw StateError('ChemVision AI 返回内容为空');
      }
      return text.trim();
    } on FunctionException catch (error) {
      final payload = _record(error.details);
      throw StateError(_aiErrorMessage(payload?['error'], status: error.status));
    }
  }

  Map<String, dynamic>? _record(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _aiErrorMessage(Object? error, {int? status}) {
    return switch (error) {
      'ai_limit_reached' => 'ChemVision AI 的 5 次模型调用额度已用完。',
      'supported_sign_in_required' => '请使用邮箱或 GitHub 登录/注册后再使用 ChemVision AI。',
      'unauthorized' => '登录状态已失效，请重新登录。',
      'ai_service_not_configured' => '官方 AI 服务尚未完成服务器配置。',
      'quota_unavailable' || 'quota_finalize_failed' => '暂时无法确认 AI 额度，请稍后重试。',
      'ai_provider_unavailable' || 'ai_provider_rejected_request' => 'DeepSeek 服务暂时不可用，请稍后重试。',
      'invalid_prompt' || 'invalid_image' => 'AI 请求内容无效，请修改后重试。',
      _ when status == 429 => 'ChemVision AI 的 5 次模型调用额度已用完。',
      _ when status == 401 => '登录状态已失效，请重新登录。',
      _ => 'ChemVision AI 请求失败，请稍后重试。',
    };
  }

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

class ChemVisionAiQuota {
  const ChemVisionAiQuota({
    required this.used,
    required this.reserved,
    required this.remaining,
    required this.limit,
    required this.unlimited,
  });

  final int used;
  final int reserved;
  final int? remaining;
  final int? limit;
  final bool unlimited;

  factory ChemVisionAiQuota.fromJson(Map<String, dynamic> json) {
    int? readInt(Object? value) => value is num ? value.toInt() : null;
    return ChemVisionAiQuota(
      used: readInt(json['used']) ?? 0,
      reserved: readInt(json['reserved']) ?? 0,
      remaining: readInt(json['remaining']),
      limit: readInt(json['limit']),
      unlimited: json['unlimited'] == true,
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
