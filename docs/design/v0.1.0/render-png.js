// Exports every board in canvas.json to png/<Board>.png at its canvas size.
// Usage (from anywhere): node docs/design/v0.1.0/render-png.js   (needs Microsoft Edge)
const http = require('http'), fs = require('fs'), path = require('path'), os = require('os');
const run = require('util').promisify(require('child_process').execFile);

const repo = path.resolve(__dirname, '../../..');
const edge = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.json': 'application/json' };

const server = http.createServer((req, res) => {
  const file = path.join(repo, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(repo) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

server.listen(0, '127.0.0.1', async () => {
  const base = `http://127.0.0.1:${server.address().port}/docs/design/v0.1.0/`;
  const out = path.join(__dirname, 'png');
  fs.mkdirSync(out, { recursive: true });
  for (const [f, b] of Object.entries(require('./canvas.json').boards)) {
    const png = path.join(out, f.replace('.dc.html', '.png'));
    // A fresh profile per shot: a second headless Edge on the same profile exits without a screenshot.
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'dc-edge-'));
    try {
      await run(edge, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--user-data-dir=${profile}`,
        '--virtual-time-budget=8000', `--window-size=${b.w},${b.h}`, `--screenshot=${png}`, base + f], { timeout: 60000 });
    } catch (e) { console.error(f, e.message.split('\n')[0]); }
    fs.rmSync(profile, { recursive: true, force: true });
    console.log(fs.existsSync(png) ? `${f} -> png/${path.basename(png)}` : `${f} FAILED`);
  }
  server.close();
});
