class AppConfig {
  static const bool useMockService = false;
  static const Duration mockDelay = Duration(milliseconds: 900);
  static const String renderEngineName = 'WebView + smiles-drawer';
  static const String localWebEntry = 'assets/web/index.html';
  static const String localJsmeEditorEntry = 'assets/web/editor_jsme.html';

  /// Ketcher 编辑器入口（移动端使用 asset 路径）
  static const String ketcherEntry = 'assets/web/ketcher/index.html';

  /// Ketcher 编辑器入口（Web 端，Flutter 构建后实际路径多一层 assets/）
  static const String ketcherWebEntry = 'assets/assets/web/ketcher/index.html';
  static const String vivoAigcBaseUrl = 'https://api-ai.vivo.com.cn/v1';
  static const String vivoTextGenerationPath = '/chat/completions';
  static const String vivoTextGenerationUrl =
      '$vivoAigcBaseUrl$vivoTextGenerationPath';
  static const String proxyBaseUrl = 'http://localhost:8787';

  /// Cloudflare Worker CORS 代理地址（部署后替换为实际 URL）
  /// 部署方式：cd cloudflare-worker && npx wrangler deploy
  static const String cloudflareWorkerUrl = 'https://chemvision.chainguard.qzz.io';

  /// Web 端默认使用 Cloudflare Worker 代理，本地开发时可用 localhost:8787
  static const String webProxyBaseUrl = cloudflareWorkerUrl;

  /// OPSIN 代理地址（Web 端需要代理避免 CORS）
  static const String opsinProxyBaseUrl = '$proxyBaseUrl/opsin';

  /// Web 端 OPSIN 代理地址（需部署 Cloudflare Worker 后配置）
  static const String webOpsinProxyBaseUrl = '$cloudflareWorkerUrl/opsin';
}
