---
name: honeybadger-cli
description: >
  Honeybadger's `hb` CLI — auth (Reporting vs Data API), config file, and command
  groups for faults, deployments, and insights queries from the terminal.
---

# Honeybadger CLI (`hb`)

`hb` is the official Honeybadger CLI. It exposes two credential-scoped APIs — a
**Reporting API** (`--api-key` / `HONEYBADGER_API_KEY`, for `deploy`, `check-in`, `run`,
`agent`) and a **Data API** (`--auth-token` / `HONEYBADGER_AUTH_TOKEN`, or the `auth_token:`
key in `~/.honeybadger-cli.yaml`, for everything else). Run `hb <command> --help` for exact
flags rather than guessing — the tool is self-documenting and this skill won't duplicate it.

## Command groups

- **Reporting API** (`--api-key`): `deploy`, `check-in`, `run`, `agent`
- **Data API** (`--auth-token`): `faults`, `projects`, `insights`, `deployments`,
  `environments`, `accounts`, `teams`, `comments`, `check-ins`, `statuspages`, `uptime`
- Common flags worth knowing exist: `-o/--output table|json`, `--project-id`,
  `--account-id`, `--fault-id`

## Quick reference

```
hb faults list --project-id <project-id> --limit 10 -o json
hb faults get --project-id <project-id> --id <fault-id> -o json
hb deploy -e production -r <repo> -v $(git rev-parse HEAD)
hb insights query --project-id <project-id> -q "SELECT AVG(used_percent) FROM report.system.cpu"
```

## Gotchas

- Most Data API commands (`faults list`, `insights query`, etc.) require `--project-id`
  (or `HONEYBADGER_PROJECT_ID`) even when `--auth-token` is already configured — a missing
  auth token and a missing project ID look similar at a glance but are separate flags.
- The two auth mechanisms aren't interchangeable — using `--auth-token` on a Reporting
  command (or vice versa) is a common mistake. Know which bucket a subcommand falls in.
- `~/.honeybadger-cli.yaml` holds a live personal auth token in plaintext by default —
  treat it like a secret; don't cat/paste it into shared output, commits, or logs.
- `hb run -- <cmd>`: shell redirection (`>`, pipes) is interpreted by the calling shell
  before `hb` ever sees it. Wrap multi-step shell logic in a script and pass the script
  to `hb run` instead.
- `hb insights query` uses **BadgerQL** (a Honeybadger-specific SQL-like language over
  fixed `report.*` tables), not arbitrary SQL against a real database.
