---
name: newrelic-observability
description: Investigate and prove observability issues — especially LOGGING — with New Relic (docs.newrelic.com), via NRQL and the `newrelic` CLI / NerdGraph GraphQL API. Use whenever querying New Relic data, writing or reviewing NRQL, running `newrelic nrql query` or a NerdGraph curl, checking "are my logs arriving?", investigating an error/log spike, correlating logs to an APM trace via trace.id/span.id, confirming a fix with a before/after window, or defining an NRQL alert condition. Also trigger on "New Relic", "NRQL", "NerdGraph", "Log event type", "entity.guid", "logs in context", "are my logs arriving". Not for: Honeybadger faults — use `wealthbox:diagnose-and-fix-error` / `wealthbox:fix-honeybadger`; Wealthbox request-log search — use `wealthbox:request-log-search`.
---

# New Relic Observability — Prove It With NRQL

Reference for investigating and **proving** observability issues in [New Relic](https://docs.newrelic.com/),
with a logging emphasis. **This file is a router** — it states the mental model, gives you a
question-driven playbook, and flags the traps. Full NRQL syntax, the log data model, CLI/NerdGraph
usage, and worked queries live in `references/`; open the linked file when you're at that decision
point. Runnable helper in `scripts/nr-nrql.sh`.

**Anchor:** verified against the `newrelic` CLI **v0.112.17** and docs.newrelic.com current as of
July 2026. The mission is always the same shape — **turn a claim ("logs stopped", "errors spiked",
"my fix worked") into an NRQL query whose result is the proof.**

## The Core Mental Model

Everything New Relic collects lands in **NRDB** (New Relic Database) and is queryable with one
language, **NRQL**. Data follows the **MELT** model:

- **Metrics** — numeric measurements over time (`Metric` type; also APM metric-timeslices).
- **Events** — discrete occurrences with attributes: `Transaction`, `TransactionError`, `Span`,
  `PageView`, and **`Log`**.
- **Logs** — log lines, stored as the **`Log`** event type. `SELECT * FROM Log`. This is the focus.
- **Traces** — a request across services, as **`Span`** objects; a whole trace shares a `trace.id`,
  each segment a `span.id`.

An **entity** is anything reporting data, identified by **`entity.guid`** (name in `entity.name`).
**Logs in context** is the pivot that makes investigation work: APM agents stamp each log line with
**`trace.id`, `span.id`, `entity.guid`, `entity.name`, `hostname`**, so you can jump log → trace →
APM error and back. Queries are scoped to a numeric **account ID** (and a **region**, US or EU).

## Reach for this skill when

- Querying New Relic for anything (logs, errors, traces, metrics) via NRQL.
- Verifying log **ingestion** — "are my logs even arriving?"
- Root-causing an **error / log-volume spike**.
- **Correlating** a log line to its APM trace/span or error.
- **Proving a fix** by comparing a before-window to an after-window.
- Writing or reviewing an **NRQL alert condition**.

## Two ways to run a query

Both require a **User key** (`NRAK-…`, *not* a License/Ingest key), an **account ID**, and a
**region**. Never hardcode these — read them from the CLI profile or `NEW_RELIC_*` env vars.

1. **`newrelic` CLI** (preferred when `command -v newrelic` succeeds — it handles region/auth from
   the profile): `newrelic nrql query --accountId <id> --query 'SELECT …'` (JSON by default → pipe to `jq`).
2. **NerdGraph curl** (portable, zero-install — just `curl` + `jq`): POST to `api.newrelic.com/graphql`
   (US) / `api.eu.newrelic.com/graphql` (EU) with an `API-Key` header.

`scripts/nr-nrql.sh` does the right thing automatically: CLI if present, else NerdGraph curl. Full
flags, auth setup, key types, and security in [references/cli-and-nerdgraph.md](references/cli-and-nerdgraph.md).

## Prove-it playbook

Each row turns a question into a query. Sketches below; runnable, parameterized versions with the
reasoning in [references/investigate.md](references/investigate.md).

| Question you're proving | NRQL shape | Playbook |
| --- | --- | --- |
| Are logs arriving at all? | `SELECT count(*) FROM Log … TIMESERIES` / `FACET entity.name, hostname` | [investigate.md#a](references/investigate.md#a-verify-ingestion) |
| What/where is the error spike? | `SELECT count(*) FROM Log WHERE level IN ('ERROR','FATAL') FACET message` | [investigate.md#b](references/investigate.md#b-root-cause-an-error-spike) |
| Which trace/request caused this? | `SELECT * FROM Log WHERE trace.id = '…'` | [investigate.md#c](references/investigate.md#c-correlate-logs-to-a-trace) |
| Did my fix actually work? | `… SINCE <after> COMPARE WITH <before>` (or two absolute windows) | [investigate.md#d](references/investigate.md#d-confirm-a-fix-beforeafter) |
| Where did the missing logs go? | drop filter rules, data partitions (`FROM Log_<name>`) | [investigate.md#e](references/investigate.md#e-detect-missing--dropped-logs) |
| Alert me when this recurs | NRQL alert condition + threshold | [investigate.md#f](references/investigate.md#f-nrql-alert-conditions) |

## Surface → Reference

| Need | Reach for | Reference |
| --- | --- | --- |
| Write/read NRQL (clauses, functions, time windows) | `SELECT … FROM … WHERE … FACET … TIMESERIES` | [nrql.md](references/nrql.md) |
| Understand the log data model & where logs come from | ingestion, attributes, logs-in-context, partitions | [logs.md](references/logs.md) |
| Run a query from the terminal | `newrelic` CLI, NerdGraph curl, auth, keys | [cli-and-nerdgraph.md](references/cli-and-nerdgraph.md) |
| Investigate a specific symptom | the A–F playbooks | [investigate.md](references/investigate.md) |
| "This silently doesn't work / lies to me" | — | [gotchas.md](references/gotchas.md) |

## Gotchas (hooks — full detail in [references/gotchas.md](references/gotchas.md))

| Symptom | Real cause |
| --- | --- |
| NRQL query returns `401 invalid API key` | Needs a **User key** (`NRAK-`), not a License/Ingest key; also 401s if the key is invalid/revoked or the **region** (US vs EU) is wrong. Diagnose with `newrelic diagnose validate`. |
| NerdGraph curl "succeeds" but results are `null` | NerdGraph returns **HTTP 200 even on invalid NRQL** — the error hides in `.errors`. Check `.errors` before reading `.data…results` (the toolbox script does). |
| `WHERE level = 'ERROR'` finds nothing though errors exist | Severity attribute name is **source-dependent** — `level` vs `log.level` vs `severity.text`. Inspect a raw row / `keyset()` first; don't assume. |
| Can't filter APM logs by `service.name` | `service.name` is an OTel convention, often **absent on APM-agent logs** — use `entity.name` / `entity.guid`. |
| `SELECT count(*) FROM Log` empty but the app is logging | A **drop filter rule** removed them pre-storage, or they're in a **data partition** — query `FROM Log_<partition>`. Empty ≠ not sent. |
| NerdGraph JSON body breaks on the NRQL string | NRQL's double quotes collide with JSON quoting — never hand-concatenate; pass NRQL as a **GraphQL variable** (`$q: Nrql!`) built with `jq -n`. |
| Recent `SINCE 5 minutes ago` looks empty, fills in later | **Low-volume logs batch and arrive late** — give ingestion / "confirm fix" / alert windows a buffer. |
| Raw `SELECT * FROM Log` silently truncates rows | Default `LIMIT` is low for event selects — use `LIMIT MAX` when completeness matters. |
| `SINCE 1 hour ago UNTIL 1 hour ago` misses the boundary | `UNTIL` is **exclusive**; default is `UNTIL NOW`. |

## Toolbox

`scripts/nr-nrql.sh` — run any NRQL query and print the result rows. Prefers the CLI, falls back to
NerdGraph curl+jq, and guards the silent-`null`-on-error trap.

```bash
export NEW_RELIC_ACCOUNT_ID=<id> NEW_RELIC_API_KEY=<NRAK-…> NEW_RELIC_REGION=US
./scripts/nr-nrql.sh "SELECT count(*) FROM Log WHERE level='ERROR' SINCE 30 minutes ago FACET entity.name"
```

## Bundled References

- **[references/nrql.md](references/nrql.md)** — NRQL clause structure, the `Log` event type,
  aggregators (`count`/`uniqueCount`/`percentage`/`percentile`/`latest`/`filter`/`rate`), WHERE
  operators (`LIKE`/`RLIKE`/`IN`/`IS NULL`), time windows (relative, absolute ISO-8601,
  `TIMESERIES`/`SLIDE BY`, `COMPARE WITH`), and `LIMIT MAX`.
- **[references/logs.md](references/logs.md)** — how logs get in (APM agent, infra agent, forwarders,
  Log API, OTel), `Log` attributes, logs-in-context + the `NR-LINKING` blob, Lucene search, drop
  filter rules, and data partitions.
- **[references/investigate.md](references/investigate.md)** — the A–F prove-it playbooks with
  runnable NRQL and the reasoning behind each.
- **[references/cli-and-nerdgraph.md](references/cli-and-nerdgraph.md)** — `newrelic nrql query` /
  `nerdgraph query` / `entity search` / `diagnose validate`, profile & env auth, NerdGraph curl
  shape, US/EU endpoints, User-vs-License key types, and credential-security rules.
- **[references/gotchas.md](references/gotchas.md)** — every gotcha above in full with source
  citations, plus verify-before-shipping caveats (NR-LINKING field order, `level` naming,
  `service.name` absence, `NrIntegrationError`, multi-account/partition scoping).

---

*Sources: [docs.newrelic.com](https://docs.newrelic.com/) (NRQL reference, log management, logs in
context, NerdGraph, API keys) and the [newrelic-cli](https://github.com/newrelic/newrelic-cli) docs,
fetched directly and verified against the installed CLI **v0.112.17** `--help` — not reconstructed
from training memory. Each reference file carries its own source URLs. No account IDs or API keys
are stored in this skill; supply them via `NEW_RELIC_*` env vars or a `newrelic` CLI profile.*
