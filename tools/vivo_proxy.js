const http = require('http');
const https = require('https');
const zlib = require('zlib');
const { URL } = require('url');

const vivoTarget = new URL(process.env.VIVO_TARGET || 'https://api-ai.vivo.com.cn');
const opsinTarget = new URL(process.env.OPSIN_TARGET || 'https://opsin.ch.cam.ac.uk');
const port = Number.parseInt(process.env.PORT || '8787', 10);

function withCorsHeaders(headers) {
  return {
    ...headers,
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'authorization,content-type,accept',
  };
}

function decodeStream(proxyRes, callback) {
  const chunks = [];
  const encoding = (proxyRes.headers['content-encoding'] || '').toLowerCase();

  let stream = proxyRes;
  if (encoding === 'gzip') {
    stream = proxyRes.pipe(zlib.createGunzip());
  } else if (encoding === 'deflate') {
    stream = proxyRes.pipe(zlib.createInflate());
  } else if (encoding === 'br') {
    stream = proxyRes.pipe(zlib.createBrotliDecompress());
  }

  stream.on('data', (chunk) => chunks.push(chunk));
  stream.on('end', () => callback(null, Buffer.concat(chunks)));
  stream.on('error', (err) => callback(err, null));
}

function proxyRequest(targetUrl, method, headers, body, res) {
  console.log(`[Proxy] ${method} ${targetUrl.href}`);

  const proxyReq = https.request(
    targetUrl,
    { method, headers },
    (proxyRes) => {
      console.log(`[Proxy] <- ${proxyRes.statusCode}`);

      // Build response headers, removing encoding-related ones since we decode
      const responseHeaders = {};
      for (const [key, value] of Object.entries(proxyRes.headers)) {
        if (key !== 'content-encoding' && key !== 'transfer-encoding') {
          responseHeaders[key] = value;
        }
      }

      decodeStream(proxyRes, (err, body) => {
        if (err) {
          console.error(`[Proxy] Decode error: ${err.message}`);
          res.writeHead(502, withCorsHeaders({ 'content-type': 'text/plain' }));
          res.end(`Proxy decode error: ${err.message}`);
          return;
        }
        responseHeaders['content-length'] = body.length;
        res.writeHead(proxyRes.statusCode || 500, withCorsHeaders(responseHeaders));
        res.end(body);
      });
    },
  );

  proxyReq.on('error', (error) => {
    res.writeHead(502, withCorsHeaders({ 'content-type': 'text/plain' }));
    res.end(`Proxy error: ${error.message}`);
  });

  if (body && body.length > 0) {
    proxyReq.end(body);
  } else {
    proxyReq.end();
  }
}

function collectBody(req, callback) {
  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => callback(Buffer.concat(chunks)));
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, withCorsHeaders({}));
    res.end();
    return;
  }

  // Route: /opsin/* -> OPSIN server
  if (req.url.startsWith('/opsin/')) {
    const opsinPath = req.url; // /opsin/xxx.json
    const targetUrl = new URL(opsinPath, opsinTarget);
    const headers = {
      host: opsinTarget.host,
      accept: 'application/json',
      'user-agent': 'ChemVISION-Proxy/1.0',
    };
    proxyRequest(targetUrl, req.method, headers, null, res);
    return;
  }

  // Default route: Vivo API
  const targetUrl = new URL(req.url, vivoTarget);
  const allowedHeaderKeys = [
    'authorization',
    'content-type',
    'accept',
    'user-agent',
  ];
  const headers = {
    host: vivoTarget.host,
    accept: 'application/json',
    'user-agent': 'ChemVISION-Proxy/1.0',
  };
  for (const key of allowedHeaderKeys) {
    const value = req.headers[key];
    if (value) {
      headers[key] = value;
    }
  }

  collectBody(req, (body) => {
    proxyRequest(targetUrl, req.method, headers, body, res);
  });
});

server.listen(port, () => {
  console.log(`Proxy listening on http://localhost:${port}`);
  console.log(`Vivo target: ${vivoTarget.href}`);
  console.log(`OPSIN target: ${opsinTarget.href}`);
});
