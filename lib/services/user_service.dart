import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// 用户数据重新初始化回调
/// 切换用户时调用,让各 Service 用新 userId 重新打开 box
typedef ReinitForUserCallback = Future<void> Function(String userId);

/// 用户管理服务 — 管理用户列表和当前用户,数据按用户隔离
///
/// - 用户列表存储在 `app_users` Hive box(全局共享,不分用户)
/// - 当前用户 ID 存储在 SharedPreferences(轻量 KV,启动时快速读取)
/// - 切换用户时通过 [registerReinitCallback] 通知各 Service 重新初始化
class UserService {
  static const _boxName = 'app_users';
  static const _currentUserIdKey = 'current_user_id';

  Box<AppUser>? _box;
  String? _currentUserId;

  /// 各 Service 注册的重新初始化回调(在切换用户时触发)
  final List<ReinitForUserCallback> _reinitCallbacks = [];

  Future<void> init() async {
    _box = await Hive.openBox<AppUser>(_boxName);

    // 读取当前用户 ID
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_currentUserIdKey);

    // 如果没有用户,创建默认用户
    if (_box!.isEmpty) {
      final defaultUser = AppUser(
        id: 'user_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        nickname: '默认用户',
        stage: 'highschool',
        createdAt: DateTime.now(),
      );
      await _box!.put(defaultUser.id, defaultUser);
      _currentUserId = defaultUser.id;
      await prefs.setString(_currentUserIdKey, _currentUserId!);
    }

    // 如果当前用户 ID 无效,使用第一个用户
    if (_currentUserId == null || !_box!.containsKey(_currentUserId)) {
      _currentUserId = _box!.values.first.id;
      await prefs.setString(_currentUserIdKey, _currentUserId!);
    }

    if (kDebugMode) {
      debugPrint(
          '[UserService] 已加载 ${_box!.length} 个用户,当前: ${currentUser?.nickname}');
    }
  }

  /// 注册重新初始化回调(切换用户时调用)
  void registerReinitCallback(ReinitForUserCallback callback) {
    _reinitCallbacks.add(callback);
  }

  /// 当前用户 ID
  String get currentUserId => _currentUserId ?? 'default';

  /// 当前用户
  AppUser? get currentUser {
    if (_currentUserId == null || _box == null) return null;
    return _box!.get(_currentUserId);
  }

  /// 所有用户列表(按创建时间排序)
  List<AppUser> get allUsers {
    if (_box == null) return const [];
    final list = _box!.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 创建新用户
  Future<AppUser> createUser({
    required String nickname,
    required String stage,
    String? avatarPath,
  }) async {
    final user = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      nickname: nickname,
      stage: stage,
      avatarPath: avatarPath,
      createdAt: DateTime.now(),
    );
    await _box!.put(user.id, user);
    return user;
  }

  /// 更新用户信息
  Future<void> updateUser(AppUser user) async {
    await _box!.put(user.id, user);
  }

  /// 切换当前用户(触发所有 Service 重新初始化)
  Future<void> switchUser(String userId) async {
    if (userId == _currentUserId) return;

    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId);

    // 通知所有 Service 用新 userId 重新打开 box
    for (final callback in _reinitCallbacks) {
      await callback(userId);
    }

    if (kDebugMode) {
      debugPrint('[UserService] 已切换到用户: ${currentUser?.nickname}');
    }
  }

  /// 删除用户(同时清理该用户的隔离数据)
  Future<void> deleteUser(String userId) async {
    if (_box == null) return;
    if (_box!.length <= 1) {
      throw StateError('至少保留一个用户');
    }

    await _box!.delete(userId);

    // 如果删除的是当前用户,切换到第一个
    if (_currentUserId == userId) {
      final nextUser = _box!.values.first;
      await switchUser(nextUser.id);
    }

    // 删除该用户的 Hive box(清理隔离数据)
    final boxNames = [
      '${userId}_favorites',
      '${userId}_reaction_favorites',
      '${userId}_edit_history',
      '${userId}_search_history',
      '${userId}_scan_history',
      '${userId}_learning_records',
      '${userId}_agent_sessions',
      '${userId}_error_book',
    ];
    for (final name in boxNames) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[UserService] 删除 box $name 失败: $e');
        }
      }
    }
  }
}

/// UserService Provider(由 main.dart override 注入已初始化的实例)
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// 当前用户 Provider(响应式,切换用户后自动更新)
final currentUserProvider = StateProvider<AppUser?>((ref) {
  return null;
});
