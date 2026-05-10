import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本信息服务
class AppVersionService {
  static final AppVersionService _instance = AppVersionService._internal();
  factory AppVersionService() => _instance;
  AppVersionService._internal();

  String _version = 'Unknown';
  String _buildNumber = 'Unknown';
  bool _initialized = false;

  /// 初始化版本信息
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      if (kIsWeb) {
        _version = 'Web';
        _buildNumber = 'Web';
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('获取版本信息失败：$e');
      _version = 'Unknown';
      _buildNumber = 'Unknown';
      _initialized = true;
    }
  }

  /// 获取版本号（如：1.0.0）
  String get version {
    if (!_initialized) return '...';
    return _version;
  }

  /// 获取构建号（如：1）
  String get buildNumber {
    if (!_initialized) return '...';
    return _buildNumber;
  }

  /// 获取完整版本字符串（如：v1.0.0 (1)）
  String get fullVersion {
    if (!_initialized) return 'v... (...)';
    return 'v$_version ($_buildNumber)';
  }

  /// 获取平台信息
  String get platformInfo {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
