import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../docs');
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.zip': 'application/zip' };
http.createServer((request, response) => {
  try {
    let name = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (name.endsWith('/')) name += 'index.html';
    const file = path.resolve(root, '.' + name);
    if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.writeHead(404); response.end('Not found'); return;
    }
    response.writeHead(200, { 'Content-Type': mime[path.extname(file)] ?? 'application/octet-stream' });
    fs.createReadStream(file).pipe(response);
  } catch { response.writeHead(400); response.end('Bad request'); }
}).listen(4173, '127.0.0.1', () => console.log('RallyTrip preview: http://127.0.0.1:4173'));
