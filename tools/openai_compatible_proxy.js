const http = require('http');
const https = require('https');
const zlib = require('zlib');
const { URL } = require('url');

const aiTarget = new URL(process.env.AI_TARGET || 'https://api.openai.com');
const opsinTarget = new URL(process.env.OPSIN_TARGET || 'https://opsin.ch.cam.ac.uk');
const port = Number.parseInt(process.env.PORT || '8787', 10);
const host = process.env.HOST || '127.0.0.1';
const maxBodyBytes = Number.parseInt(process.env.MAX_BODY_BYTES || '16777216', 10);

if (!Number.isInteger(maxBodyBytes) || maxBodyBytes <= 0) {
  throw new Error('MAX_BODY_BYTES must be a positive integer');
}

if (!['http:', 'https:'].includes(aiTarget.protocol)) {
  throw new Error('AI_TARGET must use HTTP or HTTPS');
}

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
  console.log(`[Proxy] ${method} ${targetUrl.origin}${targetUrl.pathname}`);

  const transport = targetUrl.protocol === 'https:' ? https : http;
  const proxyReq = transport.request(
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
  let byteLength = 0;
  let tooLarge = false;
  let settled = false;

  const fail = (error) => {
    if (settled) return;
    settled = true;
    callback(error);
  };

  req.on('data', (chunk) => {
    byteLength += chunk.length;
    if (byteLength > maxBodyBytes) {
      tooLarge = true;
      chunks.length = 0;
      return;
    }
    if (!tooLarge) chunks.push(chunk);
  });
  req.on('error', fail);
  req.on('aborted', () => {
    settled = true;
  });
  req.on('end', () => {
    if (settled) return;
    settled = true;
    if (tooLarge) {
      const error = new Error('request body exceeds the configured limit');
      error.code = 'BODY_TOO_LARGE';
      callback(error);
      return;
    }
    callback(null, Buffer.concat(chunks));
  });
}

function buildTargetUrl(requestUrl, target) {
  const incoming = new URL(requestUrl || '/', 'http://proxy.invalid');
  if (incoming.origin !== 'http://proxy.invalid') return null;
  return new URL(`${incoming.pathname}${incoming.search}`, target.origin);
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
    const targetUrl = buildTargetUrl(opsinPath, opsinTarget);
    if (!targetUrl) {
      res.writeHead(400, withCorsHeaders({ 'content-type': 'text/plain' }));
      res.end('Invalid request path');
      return;
    }
    const headers = {
      host: opsinTarget.host,
      accept: 'application/json',
      'user-agent': 'ChemVISION-Proxy/1.0',
    };
    proxyRequest(targetUrl, req.method, headers, null, res);
    return;
  }

  // Default route: OpenAI-compatible API. The target origin is configurable;
  // the incoming path (for example /v1/chat/completions) is preserved.
  const targetUrl = buildTargetUrl(req.url, aiTarget);
  if (!targetUrl) {
    res.writeHead(400, withCorsHeaders({ 'content-type': 'text/plain' }));
    res.end('Invalid request path');
    return;
  }
  const allowedHeaderKeys = [
    'authorization',
    'content-type',
    'accept',
    'user-agent',
  ];
  const headers = {
    host: targetUrl.host,
    accept: 'application/json',
    'user-agent': 'ChemVISION-Proxy/1.0',
  };
  for (const key of allowedHeaderKeys) {
    const value = req.headers[key];
    if (value) {
      headers[key] = value;
    }
  }

  collectBody(req, (error, body) => {
    if (error) {
      const status = error.code === 'BODY_TOO_LARGE' ? 413 : 400;
      res.writeHead(status, withCorsHeaders({ 'content-type': 'text/plain' }));
      res.end(error.message);
      return;
    }
    proxyRequest(targetUrl, req.method, headers, body, res);
  });
});

server.listen(port, host, () => {
  console.log(`Proxy listening on http://${host}:${port}`);
  console.log(`AI target: ${aiTarget.origin}`);
  console.log(`OPSIN target: ${opsinTarget.href}`);
});
