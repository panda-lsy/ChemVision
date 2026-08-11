import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'models/adapters/agent_session_record_adapter.dart';
import 'models/adapters/app_user_adapter.dart';
import 'models/adapters/edit_history_item_adapter.dart';
import 'models/adapters/error_book_item_adapter.dart';
import 'models/adapters/favorite_item_adapter.dart';
import 'models/adapters/learning_record_adapter.dart';
import 'models/adapters/reaction_equation_adapter.dart';
import 'models/adapters/reaction_favorite_item_adapter.dart';
import 'models/adapters/scan_history_item_adapter.dart';
import 'models/adapters/structure_candidate_adapter.dart';
import 'models/adapters/structure_result_adapter.dart';
import 'providers/favorites_provider.dart';
import 'providers/edit_history_provider.dart';
import 'providers/reaction_favorites_provider.dart';
import 'providers/scan_history_provider.dart';
import 'services/agent_session_store.dart';
import 'services/error_book_service.dart';
import 'services/favorites_service.dart';
import 'services/edit_history_service.dart';
import 'services/learning_record_service.dart';
import 'providers/learning_profile_provider.dart';
import 'services/reaction_favorites_service.dart';
import 'services/scan_history_service.dart';
import 'services/search_history_service.dart';
import 'services/app_version_service.dart';
import 'services/user_service.dart';

// 导出 provider 供其他文件使用
export 'providers/favorites_provider.dart';

// 全局搜索历史服务实例
final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService();
});

class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController(this._service) : super(const []) {
    load();
  }

  final SearchHistoryService _service;

  void load() {
    state = _service.getAll();
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final next = [
      trimmed,
      ...state.where((item) => item != trimmed),
    ].take(20).toList();
    state = next;

    final persisted = await _service.add(trimmed);
    state = persisted;
  }

  Future<void> remove(String query) async {
    final next = state.where((item) => item != query).toList();
    state = next;

    final persisted = await _service.remove(query);
    state = persisted;
  }

  Future<void> clear() async {
    state = const [];
    await _service.clear();
  }
}

// 搜索历史列表 Provider - 用于 UI 同步
final searchHistoryListProvider =
    StateNotifierProvider<SearchHistoryController, List<String>>((ref) {
  final service = ref.watch(searchHistoryServiceProvider);
  return SearchHistoryController(service);
}, dependencies: [searchHistoryServiceProvider]);

// 全局搜索词控制器 Provider
final searchQueryControllerProvider = StateProvider<String>((ref) => '');

// 底部导航当前 tab 索引 Provider（用于跨页面切换 tab）
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 立即启动应用，减少首帧渲染时间
  runApp(const ProviderScope(
    child: _InitializationWrapper(),
  ));
}

/// 初始化包装器 - 在后台异步完成初始化
class _InitializationWrapper extends StatefulWidget {
  const _InitializationWrapper();

  @override
  State<_InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<_InitializationWrapper> {
  UserService? _userService;
  FavoritesService? _favoritesService;
  ReactionFavoritesService? _reactionFavoritesService;
  EditHistoryService? _editHistoryService;
  SearchHistoryService? _searchHistoryService;
  ScanHistoryService? _scanHistoryService;
  LearningRecordService? _learningRecordService;
  AgentSessionStore? _agentSessionStore;
  ErrorBookService? _errorBookService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  /// 用指定 userId 初始化所有数据 Service
  Future<void> _initServicesForUser(String userId) async {
    _favoritesService ??= FavoritesService();
    await _favoritesService!.init(userId: userId);

    _reactionFavoritesService ??= ReactionFavoritesService();
    await _reactionFavoritesService!.init(userId: userId);

    _editHistoryService ??= EditHistoryService();
    await _editHistoryService!.init(userId: userId);

    _searchHistoryService ??= SearchHistoryService();
    await _searchHistoryService!.init(userId: userId);

    _scanHistoryService ??= ScanHistoryService();
    await _scanHistoryService!.init(userId: userId);

    _learningRecordService ??= LearningRecordService();
    await _learningRecordService!.init(userId: userId);

    _agentSessionStore ??= AgentSessionStore();
    await _agentSessionStore!.init(userId: userId);

    _errorBookService ??= ErrorBookService();
    await _errorBookService!.init(userId: userId);
  }

  Future<void> _initializeAsync() async {
    // 在后台线程初始化
    await Future.microtask(() async {
      try {
        // 请求权限（非阻塞）
        if (!kIsWeb) {
          await _requestPermissions();
        }

        // 初始化 Hive
        await Hive.initFlutter();

        // 注册适配器
        Hive.registerAdapter(StructureResultAdapter());
        Hive.registerAdapter(StructureCandidateAdapter());
        Hive.registerAdapter(FavoriteItemAdapter());
        Hive.registerAdapter(ReactionMoleculeAdapter());
        Hive.registerAdapter(ArrowTypeAdapter());
        Hive.registerAdapter(ReactionEquationAdapter());
        Hive.registerAdapter(EditHistoryItemAdapter());
        Hive.registerAdapter(ReactionFavoriteItemAdapter());
        Hive.registerAdapter(ScanHistoryItemAdapter());
        Hive.registerAdapter(LearningRecordAdapter());
        Hive.registerAdapter(AgentSessionRecordAdapter());
        Hive.registerAdapter(AgentSessionSectionAdapter());
        Hive.registerAdapter(ErrorBookItemAdapter());
        Hive.registerAdapter(AppUserAdapter());

        // 先初始化 UserService(管理多用户)
        _userService = UserService();
        await _userService!.init();

        // 用当前用户的 userId 初始化所有数据 Service
        final userId = _userService!.currentUserId;
        await _initServicesForUser(userId);

        // 注册切换用户时的重新初始化回调
        _userService!.registerReinitCallback((newUserId) async {
          await _initServicesForUser(newUserId);
        });

        // 初始化版本服务
        await AppVersionService().init();
      } catch (e) {
        debugPrint('初始化失败：$e');
      }
    });

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // 显示简单的加载指示器
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        userServiceProvider.overrideWithValue(_userService!),
        favoritesServiceProvider.overrideWithValue(_favoritesService!),
        editHistoryServiceProvider.overrideWithValue(_editHistoryService!),
        reactionFavoritesServiceProvider.overrideWithValue(_reactionFavoritesService!),
        searchHistoryServiceProvider.overrideWithValue(_searchHistoryService!),
        scanHistoryServiceProvider.overrideWithValue(_scanHistoryService!),
        learningRecordServiceProvider.overrideWithValue(_learningRecordService!),
        agentSessionStoreProvider.overrideWithValue(_agentSessionStore!),
        errorBookServiceProvider.overrideWithValue(_errorBookService!),
      ],
      child: const ChemVisionApp(),
    );
  }
}

/// 请求应用所需的权限
Future<void> _requestPermissions() async {
  // Web 平台不支持某些权限
  if (kIsWeb) {
    debugPrint('Web 平台：跳过权限请求');
    return;
  }
  
  try {
    // 请求麦克风权限（用于语音识别）
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      await Permission.microphone.request();
    }
    
    // 请求相机权限（用于图像识别）
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      await Permission.camera.request();
    }
    
    // 注意：storage 权限在 Android 10+ 已废弃，Web 平台不支持
    // 如果需要文件访问，使用 image_picker 或 file_picker
  } catch (e) {
    debugPrint('权限请求失败：$e');
  }
}
