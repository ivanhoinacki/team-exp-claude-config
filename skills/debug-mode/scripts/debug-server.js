const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 7777;
const LOG_FILE = path.join(process.cwd(), '.claude', 'debug.log');

fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check endpoint
  if (req.method === 'GET' && req.url === '/') {
    const exists = fs.existsSync(LOG_FILE);
    const lines = exists ? fs.readFileSync(LOG_FILE, 'utf8').split('\n').filter(Boolean).length : 0;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', port: PORT, logFile: LOG_FILE, entries: lines }));
    return;
  }

  // Clear logs endpoint
  if (req.method === 'DELETE' && req.url === '/') {
    fs.writeFileSync(LOG_FILE, '');
    res.writeHead(200);
    res.end('cleared');
    return;
  }

  if (req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const parsed = JSON.parse(body);
        if (!parsed.timestamp) parsed.timestamp = Date.now();
        fs.appendFileSync(LOG_FILE, JSON.stringify(parsed) + '\n');
      } catch {
        fs.appendFileSync(LOG_FILE, body + '\n');
      }
      res.writeHead(200);
      res.end('ok');
    });
    return;
  }

  res.writeHead(404);
  res.end();
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Debug log server listening on http://127.0.0.1:${PORT}`);
  console.log(`Writing to ${LOG_FILE}`);
  console.log(`Health: GET /  |  Clear: DELETE /  |  Log: POST /`);
});
