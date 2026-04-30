class AiModelOption {
  final String name;
  final String description;

  const AiModelOption({required this.name, required this.description});
}

const String defaultAigcBaseUrl = 'https://api-ai.vivo.com.cn';

const List<AiModelOption> textGenerationModels = [
  AiModelOption(name: 'Doubao-Seedream-4.5', description: '通用文本生成'),
];

const List<String> embeddingModels = [
  'm3e-base',
  'bge-base-zh-v1.5',
];

const List<String> rerankModels = [
  'bge-reranker-large',
];
