class AppConfig {
  static const bool useMockService = false;
  static const Duration mockDelay = Duration(milliseconds: 900);
  static const String renderEngineName = 'WebView + smiles-drawer';
  static const String localWebEntry = 'assets/web/index.html';
  static const String localJsmeEditorEntry = 'assets/web/editor_jsme.html';
  static const String vivoAigcBaseUrl = 'https://api-ai.vivo.com.cn/v1';
  static const String vivoTextGenerationPath = '/chat/completions';
  static const String vivoTextGenerationUrl =
      '$vivoAigcBaseUrl$vivoTextGenerationPath';
  static const String proxyBaseUrl = 'http://localhost:8787';
  static const String opsinProxyBaseUrl = '$proxyBaseUrl/opsin';
}
