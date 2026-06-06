/**
 * ChemVISION CORS Proxy Worker
 *
 * 转发 vivo AI API 请求并添加 CORS 响应头，解决浏览器跨域限制。
 *
 * 部署方式：
 *   npm install -g wrangler
 *   npx wrangler deploy
 *
 * 部署后在 ChemVISION 设置页的「自定义 Base URL」中填入 Worker URL，
 * 例如：https://chemvision-proxy.your-subdomain.workers.dev
 */

const TARGET_BASE = 'https://api-ai.vivo.com.cn';

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // 处理 CORS 预检请求
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    // 构建目标 URL：保留路径和查询参数
    const targetUrl = TARGET_BASE + url.pathname + url.search;

    // 复制原始请求的 method、headers、body
    const init = {
      method: request.method,
      headers: filterHeaders(request.headers),
      redirect: 'follow',
    };

    // 非 GET/HEAD 请求携带 body
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      init.body = await request.arrayBuffer();
    }

    try {
      const response = await fetch(targetUrl, init);

      // 构建带 CORS 头的响应
      const responseHeaders = new Headers(response.headers);
      for (const [key, value] of Object.entries(corsHeaders())) {
        responseHeaders.set(key, value);
      }

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: 'Proxy error', message: err.message }), {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(),
        },
      });
    }
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
    'Access-Control-Max-Age': '86400',
  };
}

/** 过滤掉不应转发的请求头 */
function filterHeaders(headers) {
  const filtered = new Headers();
  const skip = new Set(['host', 'origin', 'referer', 'cf-connecting-ip', 'cf-ray']);
  for (const [key, value] of headers) {
    if (!skip.has(key.toLowerCase())) {
      filtered.set(key, value);
    }
  }
  return filtered;
}
