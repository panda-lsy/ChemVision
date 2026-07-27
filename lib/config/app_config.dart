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

  /// Cloudflare Worker CORS 代理地址
  /// 部署方式：cd cloudflare-worker && npx wrangler deploy
  /// 同时代理 vivo/OpenAI/Anthropic/PubChem/Opsin/DECIMER 多路由
  static const String cloudflareWorkerUrl = 'https://api.chemvision.qzz.io';

  /// Web 端默认使用 Cloudflare Worker 代理（生产环境）
  /// 本地开发时可在设置页改为 http://localhost:8787
  static const String webProxyBaseUrl = cloudflareWorkerUrl;

  /// OPSIN 代理地址（Web 端需要代理避免 CORS）
  static const String opsinProxyBaseUrl = '$proxyBaseUrl/opsin';

  /// Web 端 OPSIN 代理地址（需部署 Cloudflare Worker 后配置）
  static const String webOpsinProxyBaseUrl = '$cloudflareWorkerUrl/opsin';

  /// DECIMER OCSR 默认端点（自部署在 DigitalOcean Droplet 上，详见 tools/decimer_server.py）
  /// 通过 Nginx 反代 /decimer/ 到 127.0.0.1:7860 的 FastAPI 容器
  /// 完整请求路径为：{decimerBaseUrl}/process_image → Droplet 直接处理
  static const String decimerBaseUrl = 'https://agent.shengxia.me/decimer';

  /// DECIMER 处理图片路径（POST + multipart/form-data，字段名 image）
  static const String decimerProcessPath = '/process_image';

  /// DECIMER 完整处理 URL
  static const String decimerProcessUrl = '$decimerBaseUrl$decimerProcessPath';

  /// Web 端 DECIMER 代理地址（Droplet 已配置 CORS，可直接访问）
  static const String webDecimerBaseUrl = decimerBaseUrl;
}
