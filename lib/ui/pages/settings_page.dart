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
import '../../services/openai_compatible_client.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/favorites_export.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/compliance/privacy_compliance_panel.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_management_section.dart';
import 'account_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _asrApiKeyController = TextEditingController();
  final TextEditingController _textModelController = TextEditingController();
  final TextEditingController _embeddingModelController =
      TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _ocsrEndpointController = TextEditingController();

  final AiSettingsStore _settingsStore = AiSettingsStore();
  final OpenAiCompatibleClient _client = OpenAiCompatibleClient();

  bool _obscureKey = true;
  bool _obscureAsrKey = true;
  bool _isTesting = false;
  bool _hasLoaded = false;
  bool _useLocalModel = false;
  bool _useChemVisionAi = true;
  bool _quotaLoading = false;
  ChemVisionAiQuota? _hostedAiQuota;
  String? _quotaError;
  final TextEditingController _modelPathController =
      TextEditingController(text: '/sdcard/1225/1.7.0.4_1225_mtk9500');
  Timer? _saveDebounce;
  ConnectionTestResult? _testResult;

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
    _asrApiKeyController.dispose();
    _textModelController.dispose();
    _embeddingModelController.dispose();
    _baseUrlController.dispose();
    _ocsrEndpointController.dispose();
    _modelPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.load();
    _apiKeyController.text = settings.apiKey;
    _asrApiKeyController.text = settings.asrApiKey;
    _textModelController.text = settings.textModel;
    _embeddingModelController.text = settings.embeddingModel ?? '';
    _baseUrlController.text = settings.baseUrl;
    _ocsrEndpointController.text = settings.ocsrEndpoint;
    _useChemVisionAi = settings.useChemVisionAi;

    if (_baseUrlController.text.trim().isEmpty) {
      _baseUrlController.text = defaultOpenAiCompatibleBaseUrl;
    }

    if (!mounted) return;
    setState(() {
      _hasLoaded = true;
      _testResult = null;
    });
    unawaited(_refreshHostedAiQuota());
  }

  Future<void> _loadBlueLmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useLocalModel = prefs.getBool('bluelm_use_local') ?? false;
      _modelPathController.text = prefs.getString('bluelm_model_path') ??
          '/sdcard/1225/1.7.0.4_1225_mtk9500';
    });
  }

  Future<void> _saveBlueLmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bluelm_use_local', _useLocalModel);
    await prefs.setString(
        'bluelm_model_path', _modelPathController.text.trim());
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
    final asrApiKey = _asrApiKeyController.text.trim();
    final textModel = _resolveTextModel();
    final baseUrl = _resolveBaseUrl();
    final ocsrEndpoint = _resolveOcsrEndpoint();

    await _settingsStore.save(
      AiSettings(
        apiKey: apiKey,
        asrApiKey: asrApiKey,
        textModel: textModel,
        baseUrl: baseUrl,
        ocsrEndpoint: ocsrEndpoint,
        embeddingModel: _optionalModel(_embeddingModelController.text),
        useChemVisionAi: _useChemVisionAi,
      ),
    );
    await _saveBlueLmSettings();
  }

  String _resolveTextModel() {
    return _textModelController.text.trim();
  }

  String? _optionalModel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _resolveBaseUrl() {
    final raw = _baseUrlController.text.trim();
    return raw.isEmpty ? defaultOpenAiCompatibleBaseUrl : raw;
  }

  String _resolveOcsrEndpoint() {
    final raw = _ocsrEndpointController.text.trim();
    return raw;
  }

  Future<void> _refreshHostedAiQuota() async {
    final auth = SupabaseAuthService.instance;
    if (!SupabaseAuthService.isInitialized ||
        !auth.hasSupportedAiSignInProvider) {
      if (!mounted) return;
      setState(() {
        _quotaLoading = false;
        _hostedAiQuota = null;
        _quotaError = null;
      });
      return;
    }

    setState(() {
      _quotaLoading = true;
      _quotaError = null;
    });
    try {
      final quota = await auth.getChemVisionAiQuota();
      if (!mounted) return;
      setState(() {
        _hostedAiQuota = quota;
        _quotaLoading = false;
        _quotaError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hostedAiQuota = null;
        _quotaLoading = false;
        _quotaError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _openAccountPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
    if (!mounted) return;
    await _refreshHostedAiQuota();
  }

  Widget _buildHostedAiPanel(BuildContext context) {
    final auth = SupabaseAuthService.instance;
    final isSignedIn = SupabaseAuthService.isInitialized &&
        auth.hasSupportedAiSignInProvider;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DeepSeek 官方模型',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '使用 ChemVision 托管的 DeepSeek AI，输入内容会发送给 DeepSeek 处理。普通邮箱/GitHub账号共 5 次成功模型调用额度，不按月重置；Owner 管理员不限量。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (!isSignedIn) ...[
            Text(
              '当前为游客模式，不能调用 ChemVision AI。登录或注册后即可使用；游客仍可切换到“自带 API”。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openAccountPage,
              icon: const Icon(Icons.login),
              label: const Text('登录 / 注册'),
            ),
          ] else if (_quotaLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text('正在读取账号额度…',
                style: Theme.of(context).textTheme.bodySmall),
          ] else if (_quotaError != null) ...[
            Text(
              _quotaError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_refreshHostedAiQuota()),
              icon: const Icon(Icons.refresh),
              label: const Text('重新读取额度'),
            ),
          ] else if (_hostedAiQuota case final quota?) ...[
            Row(
              children: [
                Icon(
                  quota.unlimited ? Icons.all_inclusive : Icons.bolt,
                  color: quota.unlimited ? AppColors.aqua : AppColors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quota.unlimited
                        ? 'Owner 管理员：不限量'
                        : '剩余 ${quota.remaining ?? 0} / ${quota.limit ?? 5} 次模型调用（已用 ${quota.used} 次）',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: '刷新额度',
                  onPressed: () => unawaited(_refreshHostedAiQuota()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
              responseText:
                  '端侧模型连接成功: ${response.substring(0, response.length.clamp(0, 50))}...',
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
    // Key is optional for local OpenAI-compatible servers; validate the model.
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
              Text('ChemVision', style: Theme.of(context).textTheme.labelLarge),
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
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.dayBluePrimary,
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
          Text('用户', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          const UserManagementSection(),
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
                    selected: !_useLocalModel, onTap: () {
                  setState(() => _useLocalModel = false);
                  _scheduleSave();
                }),
                _buildModelTab(context, isDark,
                    label: '端侧模型',
                    icon: Icons.phone_android,
                    selected: _useLocalModel, onTap: () {
                  setState(() => _useLocalModel = true);
                  _scheduleSave();
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 端侧模型配置 ──
          if (_useLocalModel) ...[
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模型路径', style: Theme.of(context).textTheme.titleSmall),
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

          // ── 云端 AI 配置 ──
          if (!_useLocalModel) ...[
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
                      label: 'ChemVision AI',
                      icon: Icons.auto_awesome,
                      selected: _useChemVisionAi, onTap: () {
                    setState(() => _useChemVisionAi = true);
                    unawaited(_persistSettings());
                    unawaited(_refreshHostedAiQuota());
                  }),
                  _buildModelTab(context, isDark,
                      label: '自带 API',
                      icon: Icons.key_outlined,
                      selected: !_useChemVisionAi, onTap: () {
                    setState(() => _useChemVisionAi = false);
                    unawaited(_persistSettings());
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_useChemVisionAi)
              _buildHostedAiPanel(context)
            else
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('文本生成模型',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textModelController,
                    onChanged: (_) => _scheduleSave(),
                    decoration: const InputDecoration(
                      hintText: '输入服务商提供的模型 ID',
                    ),
                  ),
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
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
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
                    'Key 保存在本机，并会随请求作为 Bearer Token 发往 Base URL。',
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
              title:
                  Text('高级设置', style: Theme.of(context).textTheme.titleMedium),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Text('语音识别 API Key',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _asrApiKeyController,
                  obscureText: _obscureAsrKey,
                  onChanged: (_) => _scheduleSave(),
                  decoration: InputDecoration(
                    hintText: '语音识别服务使用的 Key',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureAsrKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureAsrKey = !_obscureAsrKey;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '独立用于语音识别，不会发送给文本模型 API。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('文本向量模型', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _embeddingModelController,
                  onChanged: (_) => _scheduleSave(),
                  decoration: const InputDecoration(
                    hintText: '可选；输入服务商提供的 Embedding 模型 ID',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '向量检索只比较用同一模型生成的知识条目；未配置时使用关键词检索。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('OpenAI 兼容 API Base URL',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _baseUrlController,
                  onChanged: (_) => _scheduleSave(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '支持 /v1/chat/completions 与 /v1/embeddings。Web 端使用时，目标服务需要允许当前站点跨域访问（CORS）。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('OCSR 服务地址',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '结构式识别（DECIMER）服务地址，留空使用默认值。默认通过 agent.shengxia.me 域名访问自部署的 DECIMER 服务（阿里云 ECS + Nginx 反代 + Cloudflare SSL 代理）。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ocsrEndpointController,
                  onChanged: (_) => _scheduleSave(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://agent.shengxia.me/decimer',
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
              title:
                  Text('数据管理', style: Theme.of(context).textTheme.titleMedium),
              childrenPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildStorageSection(context, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 隐私与合规 ──
          Text('隐私与合规', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const PrivacyCompliancePanel(),
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
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已清除 $count 条缓存')),
              );
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
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('所有数据已清除')),
              );
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
        color: isDark ? AppColors.glassStrong : AppColors.dayGlassStrong,
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

      if (!context.mounted) return;
      ref.invalidate(favoritesControllerProvider);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $count 条收藏')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
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
                  Text('ChemVision',
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
                  color:
                      isDark ? AppColors.glassStrong : AppColors.dayGlassStrong,
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
          Text('© 2026 ChemVision Team',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  )),
          const SizedBox(height: 4),
          Text('基于 AI 大模型',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  )),
        ],
      ),
    );
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
                    : const LinearGradient(colors: [
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
          Text('正在连接测试...', style: Theme.of(context).textTheme.bodySmall),
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
