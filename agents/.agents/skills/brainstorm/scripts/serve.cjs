#!/usr/bin/env node
// Minimal zero-dependency live-reload preview server for the brainstorm skill.
// Renders the NEWEST .md (or .html) file in --dir as a styled page with Mermaid
// diagrams and markdown tables rendered live. The browser polls /newest and
// reloads when the agent writes/overwrites a file. Feedback stays in the terminal
// — this server only renders; it captures nothing.
//
// Usage: node serve.cjs --dir <content-dir> [--port 0] [--host 127.0.0.1] [--open]

const http = require("http");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i !== -1 && args[i + 1] ? args[i + 1] : def;
};
const dir = opt("--dir");
const host = opt("--host", "127.0.0.1");
const port = parseInt(opt("--port", "0"), 10);
const doOpen = args.includes("--open");

if (!dir) {
  console.error(JSON.stringify({ error: "--dir <content-dir> is required" }));
  process.exit(1);
}
fs.mkdirSync(dir, { recursive: true });

// Newest .md/.html file in dir by mtime (ignores server-info.json and dotfiles).
function newest() {
  let best = null;
  for (const name of fs.readdirSync(dir)) {
    if (name.startsWith(".") || !/\.(md|html?)$/i.test(name)) continue;
    const full = path.join(dir, name);
    const st = fs.statSync(full);
    if (!st.isFile()) continue;
    if (!best || st.mtimeMs > best.mtimeMs) best = { name, full, mtimeMs: st.mtimeMs };
  }
  return best;
}

const RELOAD = `<script>
let last=null;
(async function poll(){
  try{
    const j=await (await fetch('/newest',{cache:'no-store'})).json();
    const sig=j.name+':'+j.mtime;
    if(last!==null&&sig!==last){location.reload();return;}
    last=sig;
  }catch(e){}
  setTimeout(poll,1500);
})();
</script>`;

function page(md, title) {
  const src = JSON.stringify(md).replace(/</g, "\\u003c");
  return `<!DOCTYPE html><html><head><meta charset="utf-8">
<title>${title}</title>
<style>
:root{--bg:#f5f5f7;--fg:#1d1d1f;--muted:#86868b;--border:#d1d1d6;--card:#fff;--accent:#0071e3}
@media(prefers-color-scheme:dark){:root{--bg:#1d1d1f;--fg:#f5f5f7;--muted:#86868b;--border:#424245;--card:#2d2d2f;--accent:#0a84ff}}
*{box-sizing:border-box}
body{font-family:system-ui,-apple-system,sans-serif;line-height:1.6;color:var(--fg);background:var(--bg);margin:0}
.wrap{max-width:900px;margin:0 auto;padding:2.5rem 2rem}
h1,h2,h3{line-height:1.25;margin:1.6em 0 .5em}h1{margin-top:0}
a{color:var(--accent)}
table{border-collapse:collapse;width:100%;margin:1em 0}
th,td{border:1px solid var(--border);padding:.5rem .75rem;text-align:left}
th{background:var(--card)}
code{background:var(--card);padding:.15em .4em;border-radius:4px;font-size:.9em}
pre{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:1rem;overflow:auto}
pre code{background:none;padding:0}
pre.mermaid{background:none;border:none;text-align:center}
blockquote{border-left:3px solid var(--border);margin:1em 0;padding:.2em 1em;color:var(--muted)}
hr{border:none;border-top:1px solid var(--border);margin:2em 0}
</style></head><body><div class="wrap" id="content"></div>
<script src="https://cdn.jsdelivr.net/npm/marked@12/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
const SRC=${src};
document.getElementById('content').innerHTML=marked.parse(SRC);
document.querySelectorAll('pre > code.language-mermaid').forEach(c=>{
  const p=document.createElement('pre');p.className='mermaid';p.textContent=c.textContent;
  c.parentElement.replaceWith(p);
});
const dark=matchMedia('(prefers-color-scheme: dark)').matches;
mermaid.initialize({startOnLoad:false,theme:dark?'dark':'default'});
mermaid.run().catch(()=>{});
</script>${RELOAD}</body></html>`;
}

const waiting = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>brainstorm</title>
<style>body{font-family:system-ui,sans-serif;color:#86868b;background:#f5f5f7;display:flex;
align-items:center;justify-content:center;height:100vh;margin:0}
@media(prefers-color-scheme:dark){body{background:#1d1d1f}}</style></head>
<body><p>Waiting for the first prototype…</p>${RELOAD}</body></html>`;

const server = http.createServer((req, res) => {
  const url = req.url.split("?")[0];
  if (url === "/newest") {
    const n = newest();
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ name: n ? n.name : null, mtime: n ? Math.round(n.mtimeMs) : 0 }));
    return;
  }
  if (url === "/" || url === "/index.html") {
    const n = newest();
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
    if (!n) return res.end(waiting);
    const body = fs.readFileSync(n.full, "utf8");
    if (/\.html?$/i.test(n.name) && /^\s*<(!doctype|html)/i.test(body)) {
      return res.end(body.replace(/<\/body>/i, RELOAD + "</body>"));
    }
    return res.end(page(body, n.name));
  }
  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("not found");
});

server.listen(port, host, () => {
  const actual = server.address().port;
  const displayHost = host === "0.0.0.0" ? "localhost" : host;
  const url = `http://${displayHost}:${actual}/`;
  const info = { port: actual, url, dir, pid: process.pid };
  try {
    fs.writeFileSync(path.join(dir, "server-info.json"), JSON.stringify(info, null, 2));
  } catch (e) {}
  console.log(JSON.stringify(info));
  if (doOpen) {
    const cmd = process.platform === "darwin" ? "open" : "xdg-open";
    try {
      spawn(cmd, [url], { stdio: "ignore", detached: true }).unref();
    } catch (e) {}
  }
});
