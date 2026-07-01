# Visual preview

A tiny live-reload server that renders your prototypes — Mermaid diagrams, markdown tables,
outlines, fenced ASCII wireframes — in the user's browser instead of leaving them as
code blocks they have to paste into a renderer. Read this only when you're actually about
to offer or use it.

**It's a tool, not a mode.** Offer it just-in-time — the first time a prototype would be
genuinely clearer *seen than read* (a diagram, a layout, side-by-side options), not upfront
and not for text-shaped questions (scope, tradeoffs, A/B/C word choices — those stay in the
terminal). If no visual question ever comes up, never start it.

## Launch

Start it with the Bash tool using **`run_in_background: true`** so it survives across turns:

```bash
node <skill-dir>/scripts/serve.cjs --dir <content-dir> --open
```

- `--dir` — where you'll write prototype files. Use a scratch dir (e.g. the session
  scratchpad) or a `.brainstorm/` dir; it doesn't need to be in the user's project.
- `--open` — opens the user's browser to the page (`open` on macOS, `xdg-open` on Linux).
- `--port <n>` optional (default: random high port). `--host <h>` optional (default
  `127.0.0.1`; use `0.0.0.0` for remote/containerized setups).

It prints `{port, url, dir, pid}` and also writes it to `<content-dir>/server-info.json`.
Grab the `url` from stdout — or, on a later turn, read `server-info.json` to recover it.
Share the URL with the user as a fallback in case the browser didn't auto-open.

## The loop

1. Write a Markdown file into `<content-dir>` (e.g. `flow.md`, `layout.md`). The server
   renders the **newest file by mtime**. Mermaid goes in ```` ```mermaid ```` fences;
   comparisons as markdown tables; wireframes in plain ``` fences (monospace).
2. Tell the user what's on screen in one line and ask for their read. Feedback comes back
   in the **terminal** — the server captures nothing.
3. To iterate, **overwrite the same file** (or write a new one). The browser auto-reloads
   within ~2s. No need to touch the server.

## Cleanup

Stop it by killing the background task (or `kill <pid>` from `server-info.json`). It's a
plain process — nothing else to tear down.

## Gotchas

- **Markdown is the format.** Write `.md`, not HTML — it's what you already produce and it
  renders. (Full `.html` documents are served as-is if you ever need one.)
- **Rendering is client-side via CDN** (marked + mermaid). Needs network; on an offline box
  the diagrams won't draw — fall back to inline code blocks in the conversation.
- **Newest-file-wins.** If an old file has a newer mtime for some reason, that's what shows.
  Use fresh, semantically-named files and let the newest be the current screen.
- **Don't make it the point.** The prototype exists to sharpen the idea or surface a wrong
  assumption fast — keep the conversation in the terminal; the browser just shows the artifact.
