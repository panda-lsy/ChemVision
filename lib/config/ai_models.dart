import 'app_config.dart';

class AiModelOption {
  final String name;
  final String description;

  const AiModelOption({required this.name, required this.description});
}

const String defaultAigcBaseUrl = AppConfig.vivoTextGenerationUrl;

const List<AiModelOption> textGenerationModels = [
  AiModelOption(name: 'Doubao-Seed-2.0-pro', description: '高质量回答'),
  AiModelOption(name: 'Volc-DeepSeek-V3.2', description: '深度推理'),
  AiModelOption(name: 'Doubao-Seed-2.0-mini', description: '轻量快速'),
  AiModelOption(name: 'Doubao-Seed-2.0-lite', description: '轻量通用'),
  AiModelOption(name: 'qwen3.5-plus', description: '通用推理'),
];

const List<String> embeddingModels = [
  'm3e-base',
  'bge-base-zh-v1.5',
];

const List<String> rerankModels = [
  'bge-reranker-large',
];
