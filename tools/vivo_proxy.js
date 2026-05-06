const http = require('http');
const https = require('https');
const { URL } = require('url');

const target = new URL(process.env.VIVO_TARGET || 'https://api-ai.vivo.com.cn');
const port = Number.parseInt(process.env.PORT || '8787', 10);

function withCorsHeaders(headers) {
  return {
    ...headers,
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'authorization,content-type,accept',
  };
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, withCorsHeaders({}));
    res.end();
    return;
  }

  const targetUrl = new URL(req.url, target);
  const allowedHeaderKeys = [
    'authorization',
    'content-type',
    'accept',
    'user-agent',
  ];
  const headers = {
    host: target.host,
    accept: 'application/json',
    'user-agent': 'ChemVISION-Proxy/1.0',
  };
  for (const key of allowedHeaderKeys) {
    const value = req.headers[key];
    if (value) {
      headers[key] = value;
    }
  }

  console.log(`[Proxy] ${req.method} ${targetUrl.href}`);

  const proxyReq = https.request(
    targetUrl,
    {
      method: req.method,
      headers,
    },
    (proxyRes) => {
      console.log(`[Proxy] <- ${proxyRes.statusCode}`);
      res.writeHead(
        proxyRes.statusCode || 500,
        withCorsHeaders(proxyRes.headers || {}),
      );
      proxyRes.pipe(res);
    },
  );

  proxyReq.on('error', (error) => {
    res.writeHead(502, withCorsHeaders({ 'content-type': 'text/plain' }));
    res.end(`Proxy error: ${error.message}`);
  });

  req.pipe(proxyReq);
});

server.listen(port, () => {
  console.log(`Vivo proxy listening on http://localhost:${port}`);
  console.log(`Target: ${target.href}`);
});
