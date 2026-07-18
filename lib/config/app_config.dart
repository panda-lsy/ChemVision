class AppConfig {
  static const bool useMockService = false;
  static const Duration mockDelay = Duration(milliseconds: 900);
  static const String renderEngineName = 'WebView + smiles-drawer';
  static const String localWebEntry = 'assets/web/index.html';

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
  static const String cloudflareWorkerUrl = 'http://localhost:8787';

  /// Web 端默认使用 Cloudflare Worker 代理，本地开发时可用 localhost:8787
  static const String webProxyBaseUrl = cloudflareWorkerUrl;

  /// OPSIN 代理地址（Web 端需要代理避免 CORS）
  static const String opsinProxyBaseUrl = '$proxyBaseUrl/opsin';

  /// Web 端 OPSIN 代理地址（需部署 Cloudflare Worker 后配置）
  static const String webOpsinProxyBaseUrl = '$cloudflareWorkerUrl/opsin';

  /// DECIMER OCSR 默认端点（用户需自部署 FastAPI 包装器，详见 tools/decimer_server.py）
  /// 走 Cloudflare Worker 的 /decimer 子路径代理（见 cloudflare-worker/worker.js）
  /// 完整请求路径为：{decimerBaseUrl}/process_image → Worker 转发到 env.DECIMER_UPSTREAM/process_image
  static const String decimerBaseUrl = '$cloudflareWorkerUrl/decimer';

  /// DECIMER 处理图片路径（POST + multipart/form-data，字段名 image）
  static const String decimerProcessPath = '/process_image';

  /// DECIMER 完整处理 URL
  static const String decimerProcessUrl = '$decimerBaseUrl$decimerProcessPath';

  /// Web 端 DECIMER 代理地址（与 CF Worker 复用同一域名）
  static const String webDecimerBaseUrl = decimerBaseUrl;
}
