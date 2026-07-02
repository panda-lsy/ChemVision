import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../providers/theme_mode_provider.dart';
import '../../config/ai_models.dart';
import '../../services/ai_settings_store.dart';
import '../../services/app_version_service.dart';
import '../../services/bluelm_service.dart';
import '../../services/structure_cache_store.dart';
import '../../services/vivo_aigc_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/favorites_export.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';

const String _customModelValue = '__custom__';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  final AiSettingsStore _settingsStore = AiSettingsStore();
  final VivoAigcClient _client = VivoAigcClient();

  String? _selectedTextModel;
  String? _selectedEmbeddingModel;
  String? _selectedRerankModel;
  bool _obscureKey = true;
  bool _isTesting = false;
  bool _hasLoaded = false;
  bool _useLocalModel = false;
  final TextEditingController _modelPathController =
      TextEditingController(text: '/sdcard/1225/1.7.0.4_1225_mtk9500');
  Timer? _saveDebounce;
  ConnectionTestResult? _testResult;

  bool get _isCustomModel => _selectedTextModel == _customModelValue;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBlueLmSettings();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _apiKeyController.dispose();
    _customModelController.dispose();
    _baseUrlController.dispose();
    _modelPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.load();
    final textModel = settings.textModel;
    final knownModel = textGenerationModels
        .where((model) => model.name == textModel)
        .map((model) => model.name)
        .firstOrNull;

    _apiKeyController.text = settings.apiKey;
    _baseUrlController.text = settings.baseUrl;
    _selectedEmbeddingModel = settings.embeddingModel;
    _selectedRerankModel = settings.rerankModel;

    if (knownModel != null) {
      _selectedTextModel = knownModel;
    } else if (textModel.trim().isNotEmpty) {
      _selectedTextModel = _customModelValue;
      _customModelController.text = textModel;
    } else if (textGenerationModels.isNotEmpty) {
      _selectedTextModel = textGenerationModels.first.name;
    } else {
      _selectedTextModel = _customModelValue;
    }

    if (_baseUrlController.text.trim().isEmpty) {
      _baseUrlController.text = defaultAigcBaseUrl;
    }

    setState(() {
      _hasLoaded = true;
      _testResult = null;
    });
  }

  Future<void> _loadBlueLmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useLocalModel = prefs.getBool('bluelm_use_local') ?? false;
      _modelPathController.text =
          prefs.getString('bluelm_model_path') ?? '/sdcard/1225/1.7.0.4_1225_mtk9500';
    });
  }

  Future<void> _saveBlueLmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bluelm_use_local', _useLocalModel);
    await prefs.setString('bluelm_model_path', _modelPathController.text.trim());
  }

  void _scheduleSave() {
    if (!_hasLoaded) {
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persistSettings());
    });
  }

  Future<void> _persistSettings() async {
    final apiKey = _apiKeyController.text.trim();
    final textModel = _resolveTextModel();
    final baseUrl = _resolveBaseUrl();

    await _settingsStore.save(
      AiSettings(
        apiKey: apiKey,
        textModel: textModel,
        baseUrl: baseUrl,
        embeddingModel: _selectedEmbeddingModel,
        rerankModel: _selectedRerankModel,
      ),
    );
    await _saveBlueLmSettings();
  }

  String _resolveTextModel() {
    if (_isCustomModel) {
      return _customModelController.text.trim();
    }
    return _selectedTextModel?.trim() ?? '';
  }

  String _resolveBaseUrl() {
    final raw = _baseUrlController.text.trim();
    return raw.isEmpty ? defaultAigcBaseUrl : raw;
  }

  Future<void> _runConnectionTest() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testResult = null;
    });

    if (_useLocalModel) {
      setState(() {
        _isTesting = true;
      });
      try {
        final service = BlueLmService();
        final ok = await service.init(
          modelPath: _modelPathController.text.trim(),
        );
        if (ok) {
          final response = await service.generate('测试');
          setState(() {
            _testResult = ConnectionTestResult.success(
                responseText: '端侧模型连接成功: ${response.substring(0, response.length.clamp(0, 50))}...',
                latencyMs: 0,
            );
          });
          await service.release();
        } else {
          setState(() {
            _testResult = ConnectionTestResult.failure('端侧模型初始化失败');
          });
        }
      } catch (e) {
        setState(() {
          _testResult = ConnectionTestResult.failure('端侧模型测试失败: $e');
        });
      }
      setState(() {
        _isTesting = false;
      });
      return;
    }

    final apiKey = _apiKeyController.text.trim();
    final textModel = _resolveTextModel();
    if (apiKey.isEmpty) {
      setState(() {
        _testResult = ConnectionTestResult.failure('API Key 不能为空');
      });
      return;
    }
    if (textModel.isEmpty) {
      setState(() {
        _testResult = ConnectionTestResult.failure('请选择或输入模型名称');
      });
      return;
    }

    await _persistSettings();

    setState(() {
      _isTesting = true;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final responseText = await _client.generateText(
        apiKey: apiKey,
        model: textModel,
        prompt: '用一句话回答：水的化学式是什么？',
        baseUrl: _resolveBaseUrl(),
      );
      stopwatch.stop();
      setState(() {
        _testResult = ConnectionTestResult.success(
          responseText: responseText,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      });
    } catch (error) {
      stopwatch.stop();
      setState(() {
        _testResult = ConnectionTestResult.failure('$error');
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode != ThemeMode.light;
    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              const AccentPill(label: '云端配置'),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: isDark ? AppColors.textSecondary : AppColors.dayBluePrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '界面主题（夜间 / 日间）',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch.adaptive(
                  value: !isDark,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).setMode(
                          value ? ThemeMode.light : ThemeMode.dark,
                        );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('模型设置', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),

          // ── 模型类型切换 ──
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.glassStrong : AppColors.dayGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.dayBluePrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                _buildModelTab(context, isDark,
                    label: '云端 API',
                    icon: Icons.cloud_outlined,
                    selected: !_useLocalModel,
                    onTap: () {
                  setState(() => _useLocalModel = false);
                  _scheduleSave();
                }),
                _buildModelTab(context, isDark,
                    label: '端侧 BlueLM',
                    icon: Icons.phone_android,
                    selected: _useLocalModel,
                    onTap: () {
                  setState(() => _useLocalModel = true);
                  _scheduleSave();
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 端侧 BlueLM 配置 ──
          if (_useLocalModel) ...[
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模型路径',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelPathController,
                    decoration: const InputDecoration(
                      hintText: '/sdcard/1225/1.7.0.4_1225_mtk9500',
                      isDense: true,
                    ),
                    onChanged: (_) => _scheduleSave(),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _isTesting ? '正在测试...' : '测试连接',
                    onPressed: _isTesting ? null : _runConnectionTest,
                  ),
                  const SizedBox(height: 8),
                  _buildTestResult(context),
                ],
              ),
            ),
          ],

          // ── 云端 API 配置 ──
          if (!_useLocalModel) ...[
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('文本生成模型',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedTextModel,
                    isExpanded: true,
                    dropdownColor:
                        isDark ? AppColors.navy : AppColors.daySurface,
                    items: _buildTextModelItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTextModel = value;
                      });
                      _scheduleSave();
                    },
                  ),
                  if (_isCustomModel) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customModelController,
                      onChanged: (_) => _scheduleSave(),
                      decoration: const InputDecoration(
                        hintText: '输入自定义模型名称',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('API Key',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    onChanged: (_) => _scheduleSave(),
                    decoration: InputDecoration(
                      hintText: '请输入 API Key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureKey = !_obscureKey;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Key 仅本地存储，不上传至服务器',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _isTesting ? '正在测试...' : '连接测试',
                    onPressed: _isTesting ? null : _runConnectionTest,
                  ),
                  const SizedBox(height: 12),
                  _buildTestResult(context),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              collapsedIconColor: AppColors.textSecondary,
              iconColor: AppColors.aqua,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text('高级设置',
                  style: Theme.of(context).textTheme.titleMedium),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Text('文本向量模型',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedEmbeddingModel ?? '',
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.navy : AppColors.daySurface,
                  items: _buildOptionalItems(embeddingModels),
                  onChanged: (value) {
                    setState(() {
                      _selectedEmbeddingModel = _normalizeOptional(value);
                    });
                    _scheduleSave();
                  },
                ),
                const SizedBox(height: 16),
                Text('Rerank 模型',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedRerankModel ?? '',
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.navy : AppColors.daySurface,
                  items: _buildOptionalItems(rerankModels),
                  onChanged: (value) {
                    setState(() {
                      _selectedRerankModel = _normalizeOptional(value);
                    });
                    _scheduleSave();
                  },
                ),
                const SizedBox(height: 16),
                Text('自定义 Base URL',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _baseUrlController,
                  onChanged: (_) => _scheduleSave(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://api-ai.vivo.com.cn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 存储管理 ──
          Text('存储管理', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              collapsedIconColor: AppColors.textSecondary,
              iconColor: AppColors.aqua,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text('数据管理',
                  style: Theme.of(context).textTheme.titleMedium),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildStorageSection(context, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 关于 ──
          Text('关于', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _buildAboutSection(context, isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 存储管理区 ──

  Widget _buildStorageSection(BuildContext context, bool isDark) {
    final favoritesService = ref.read(favoritesServiceProvider);
    final historyService = ref.read(searchHistoryServiceProvider);
    final favCount = favoritesService.count;
    final historyCount = historyService.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 数据统计
        Row(
          children: [
            _buildStatChip(context, isDark, '收藏', favCount),
            const SizedBox(width: 10),
            _buildStatChip(context, isDark, '历史', historyCount),
          ],
        ),
        const SizedBox(height: 16),
        // 导出收藏
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.upload_outlined,
              color: isDark ? AppColors.aqua : AppColors.dayBluePrimary),
          title: const Text('导出收藏数据'),
          subtitle: const Text('导出为 JSON 文件，可分享或备份'),
          onTap: () => _exportFavorites(context),
        ),
        // 导入收藏
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download_outlined,
              color: isDark ? AppColors.aqua : AppColors.dayBluePrimary),
          title: const Text('导入收藏数据'),
          subtitle: const Text('从 JSON 文件导入收藏'),
          onTap: () => _importFavorites(context),
        ),
        const Divider(height: 24),
        // 清除搜索历史
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: AppColors.amber),
          title: const Text('清除搜索历史'),
          subtitle: Text('当前 $historyCount 条记录'),
          onTap: historyCount > 0
              ? () => _confirmClear(
                    context,
                    title: '清除搜索历史',
                    message: '将删除全部 $historyCount 条搜索记录，此操作不可撤销。',
                    onConfirm: () async {
                      await historyService.clear();
                      ref.invalidate(searchHistoryListProvider);
                      if (mounted) setState(() {});
                    },
                  )
              : null,
        ),
        // 清除结构缓存
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cached, color: AppColors.amber),
          title: const Text('清除结构缓存'),
          subtitle: const Text('清除已缓存的结构解析结果'),
          onTap: () => _confirmClear(
            context,
            title: '清除结构缓存',
            message: '将清除所有缓存的结构解析结果，下次查询需重新请求。',
            onConfirm: () async {
              final cache = StructureCacheStore();
              final count = await cache.clearAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已清除 $count 条缓存')),
                );
              }
            },
          ),
        ),
        const Divider(height: 24),
        // 清除所有数据
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: Text('清除所有数据',
              style: TextStyle(color: Colors.redAccent.shade200)),
          subtitle: const Text('收藏、历史、缓存全部清除'),
          onTap: () => _confirmClear(
            context,
            title: '清除所有数据',
            message: '将删除全部收藏（$favCount 条）、搜索历史（$historyCount 条）和结构缓存。此操作不可撤销！',
            isDangerous: true,
            onConfirm: () async {
              await favoritesService.clearAll();
              await historyService.clear();
              final cache = StructureCacheStore();
              await cache.clearAll();
              ref.invalidate(favoritesControllerProvider);
              ref.invalidate(searchHistoryListProvider);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有数据已清除')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(
      BuildContext context, bool isDark, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.glassStrong
            : AppColors.dayGlassStrong,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.dayTextSecondary,
                  )),
          const SizedBox(width: 8),
          Text('$count',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  )),
        ],
      ),
    );
  }

  Future<void> _exportFavorites(BuildContext context) async {
    final service = ref.read(favoritesServiceProvider);
    final json = service.exportToJson();
    await exportFavorites(json, context);
  }

  Future<void> _importFavorites(BuildContext context) async {
    try {
      final jsonString = await pickFavoritesFile();
      if (jsonString == null) return;

      final service = ref.read(favoritesServiceProvider);
      final count = await service.importFromJson(jsonString);

      if (mounted) {
        ref.invalidate(favoritesControllerProvider);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 条收藏')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _confirmClear(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: isDangerous
                ? TextButton.styleFrom(foregroundColor: Colors.redAccent)
                : null,
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  // ── 关于区 ──

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    final versionService = AppVersionService();
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 28,
                  color: isDark ? AppColors.aqua : AppColors.dayBluePrimary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ChemVISION',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(versionService.fullVersion,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.glassStrong
                      : AppColors.dayGlassStrong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(versionService.platformInfo,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('化学结构式智能生成、编辑与学习助手',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            '输入化学名称、分子式或用途描述，自动生成可编辑的结构式。'
            '支持语音输入、图片识别、反应方程式补全、印刷体结构识别等功能。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.dayTextSecondary,
                ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text('© 2026 ChemVISION Team',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  )),
          const SizedBox(height: 4),
          Text('基于 vivo 蓝心大模型（BlueLM）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  )),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildTextModelItems() {
    final items = textGenerationModels
        .map(
          (model) => DropdownMenuItem(
            value: model.name,
            child: Text('${model.name} · ${model.description}'),
          ),
        )
        .toList();

    items.add(
      const DropdownMenuItem(
        value: _customModelValue,
        child: Text('自定义 · 手动输入模型名'),
      ),
    );

    return items;
  }

  Widget _buildModelTab(
    BuildContext context,
    bool isDark, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? (isDark
                    ? const LinearGradient(
                        colors: [AppColors.aqua, Color(0xFF9EF5D2)])
                    : const LinearGradient(
                        colors: [
                            AppColors.dayBluePrimary,
                            AppColors.dayBlueAccent
                          ]))
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? (isDark ? AppColors.ink : Colors.white)
                      : (isDark
                          ? AppColors.textSecondary
                          : AppColors.dayTextSecondary)),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? (isDark ? AppColors.ink : Colors.white)
                            : (isDark
                                ? AppColors.textSecondary
                                : AppColors.dayTextSecondary),
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildOptionalItems(List<String> models) {
    return [
      const DropdownMenuItem(value: '', child: Text('不使用')),
      ...models.map(
        (model) => DropdownMenuItem(
          value: model,
          child: Text(model),
        ),
      ),
    ];
  }

  String? _normalizeOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  Widget _buildTestResult(BuildContext context) {
    if (_isTesting) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('正在连接测试...',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    final result = _testResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final color = result.success ? AppColors.aqua : Colors.redAccent;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.cancel,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? '连接成功' : '连接失败',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: color),
              ),
              const Spacer(),
              if (result.latencyMs != null)
                Text(
                  '${result.latencyMs} ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (result.success && result.responseText != null)
            Text(
              result.responseText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!result.success && result.errorMessage != null)
            Text(
              result.errorMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.redAccent.shade100),
            ),
        ],
      ),
    );
  }

}

class ConnectionTestResult {
  final bool success;
  final String? responseText;
  final String? errorMessage;
  final int? latencyMs;

  const ConnectionTestResult._({
    required this.success,
    this.responseText,
    this.errorMessage,
    this.latencyMs,
  });

  factory ConnectionTestResult.success({
    required String responseText,
    required int latencyMs,
  }) {
    return ConnectionTestResult._(
      success: true,
      responseText: responseText,
      latencyMs: latencyMs,
    );
  }

  factory ConnectionTestResult.failure(String errorMessage) {
    return ConnectionTestResult._(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
