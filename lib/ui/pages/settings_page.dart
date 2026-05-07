import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/ai_models.dart';
import '../../config/app_config.dart';
import '../../services/ai_settings_store.dart';
import '../../services/name_resolver_client.dart';
import '../../services/vivo_aigc_client.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';

const String _customModelValue = '__custom__';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _resolverUrlController = TextEditingController();

  final AiSettingsStore _settingsStore = AiSettingsStore();
  final VivoAigcClient _client = VivoAigcClient();
  final NameResolverClient _resolverClient = NameResolverClient();

  String? _selectedTextModel;
  String? _selectedEmbeddingModel;
  String? _selectedRerankModel;
  bool _obscureKey = true;
  bool _isTesting = false;
  bool _isResolverTesting = false;
  bool _hasLoaded = false;
  Timer? _saveDebounce;
  ConnectionTestResult? _testResult;
  ResolverTestResult? _resolverTestResult;

  bool get _isCustomModel => _selectedTextModel == _customModelValue;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _apiKeyController.dispose();
    _customModelController.dispose();
    _baseUrlController.dispose();
    _resolverUrlController.dispose();
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
    _resolverUrlController.text = settings.nameResolverBaseUrl;
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
      _resolverTestResult = null;
    });
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
    final resolverUrl = _resolveResolverUrl();

    await _settingsStore.save(
      AiSettings(
        apiKey: apiKey,
        textModel: textModel,
        baseUrl: baseUrl,
        nameResolverBaseUrl: resolverUrl,
        embeddingModel: _selectedEmbeddingModel,
        rerankModel: _selectedRerankModel,
      ),
    );
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

  String _resolveResolverUrl() {
    final raw = _resolverUrlController.text.trim();
    return raw.isEmpty ? AppConfig.nameResolverBaseUrl : raw;
  }

  Future<void> _runConnectionTest() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testResult = null;
    });

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

  Future<void> _runResolverTest() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resolverTestResult = null;
    });

    final resolverUrl = _resolveResolverUrl();
    if (resolverUrl.trim().isEmpty) {
      setState(() {
        _resolverTestResult = ResolverTestResult.failure('名称解析后端地址不能为空');
      });
      return;
    }

    await _persistSettings();

    setState(() {
      _isResolverTesting = true;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final result = await _resolverClient.resolve(
        'benzoic acid',
        baseUrl: resolverUrl,
      );
      stopwatch.stop();
      setState(() {
        _resolverTestResult = ResolverTestResult.success(
          smiles: result.canonicalSmiles,
          formula: result.molecularFormula,
          weight: result.molecularWeight,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      });
    } catch (error) {
      stopwatch.stop();
      setState(() {
        _resolverTestResult = ResolverTestResult.failure('$error');
      });
    } finally {
      setState(() {
        _isResolverTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 6),
              Text('连接设置', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const AccentPill(label: '云端配置'),
            ],
          ),
          const SizedBox(height: 16),
          if (_apiKeyController.text.trim().isEmpty)
            GlassPanel(
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '请配置 API Key 以启用云端生成',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (_apiKeyController.text.trim().isEmpty)
            const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API Key', style: Theme.of(context).textTheme.titleMedium),
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
                  'Key 仅本地存储，不上传至服务器',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Text('文本生成模型',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedTextModel,
                  isExpanded: true,
                  dropdownColor: AppColors.navy,
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
                PrimaryButton(
                  label: _isTesting ? '正在测试...' : '连接测试',
                  onPressed: _isTesting ? null : _runConnectionTest,
                ),
                const SizedBox(height: 12),
                _buildTestResult(context),
              ],
            ),
          ),
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
                  dropdownColor: AppColors.navy,
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
                  dropdownColor: AppColors.navy,
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
                const SizedBox(height: 16),
                Text('名称解析后端',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _resolverUrlController,
                  onChanged: (_) => _scheduleSave(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'http://localhost:9001',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _isResolverTesting ? '正在测试...' : '解析服务测试',
                  onPressed: _isResolverTesting ? null : _runResolverTest,
                ),
                const SizedBox(height: 12),
                _buildResolverTestResult(context),
              ],
            ),
          ),
          const SizedBox(height: 12),
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

  Widget _buildResolverTestResult(BuildContext context) {
    if (_isResolverTesting) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('正在测试解析服务...',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    final result = _resolverTestResult;
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
                result.success ? '解析服务可用' : '解析服务失败',
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
          if (result.success && result.smiles != null)
            Text(
              'SMILES: ${result.smiles}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (result.success && result.formula != null)
            Text(
              '分子式: ${result.formula}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (result.success && result.weight != null)
            Text(
              '分子量: ${result.weight!.toStringAsFixed(2)}',
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

class ResolverTestResult {
  final bool success;
  final String? smiles;
  final String? formula;
  final double? weight;
  final String? errorMessage;
  final int? latencyMs;

  const ResolverTestResult._({
    required this.success,
    this.smiles,
    this.formula,
    this.weight,
    this.errorMessage,
    this.latencyMs,
  });

  factory ResolverTestResult.success({
    required String smiles,
    String? formula,
    double? weight,
    required int latencyMs,
  }) {
    return ResolverTestResult._(
      success: true,
      smiles: smiles,
      formula: formula,
      weight: weight,
      latencyMs: latencyMs,
    );
  }

  factory ResolverTestResult.failure(String errorMessage) {
    return ResolverTestResult._(
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
