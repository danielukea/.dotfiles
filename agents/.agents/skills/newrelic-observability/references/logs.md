# The New Relic Log Data Model

What a `Log` record actually is, where it comes from, and why a query might not find what you expect.
For NRQL mechanics see [nrql.md](nrql.md); for symptom playbooks see [investigate.md](investigate.md).

## Contents

- [How logs get into New Relic](#how-logs-get-into-new-relic)
- [Attributes on a Log record](#attributes-on-a-log-record)
- [Logs in context (the correlation pivot)](#logs-in-context-the-correlation-pivot)
- [Searching logs (UI vs NRQL)](#searching-logs-ui-vs-nrql)
- [Where logs disappear: drop rules & partitions](#where-logs-disappear-drop-rules--partitions)

## How logs get into New Relic

Logs can arrive several ways, and **the ingestion path determines which attributes exist** — this is
why you inspect a real row before assuming a field name.

1. **APM agents** — modern language agents (Ruby, Java, Node, Python, …) decorate logs with
   correlation metadata **and forward them by default**. Best for app logs with zero extra tooling.
2. **Infrastructure agent** — captures host/file/systemd/syslog/tcp/winlog logs via Fluent Bit;
   supports custom attributes. More powerful for host-level and non-app logs.
3. **Third-party forwarders** — Fluentd, Fluent Bit, Logstash; plus AWS/Azure/GCP/Kubernetes
   integrations.
4. **Log API / TCP endpoint** — direct HTTP POST of JSON. New Relic parses the `message` value as
   JSON and promotes its keys to top-level attributes.
5. **OpenTelemetry** — app → OTel Collector → OTLP → New Relic.

Structured/JSON logs auto-parse into queryable attributes. Custom **Grok** parsing rules (testable in
the Parsing UI) extract fields from unstructured lines — prefer typed captures and anchors (`^`/`$`)
over blanket `%{GREEDYDATA}`.

## Attributes on a Log record

Common / reserved:

| Attribute | Meaning | Caveat |
| --- | --- | --- |
| `message` | the log body | JSON messages get exploded into top-level attrs |
| `level` | severity (INFO/WARN/ERROR/DEBUG/FATAL) | **name varies by source** — see below |
| `timestamp` | event time (epoch ms), used for ordering/windowing | reserved |
| `entity.name` / `entity.guid` | the APM entity that produced the log | **most reliable app identifier** |
| `hostname` | host that emitted it | |
| `trace.id` / `span.id` | logs-in-context correlation keys | present only when decorated |
| `logtype` | well-known attribute that triggers built-in parsing & quickstart dashboards | set it deliberately |
| `fb.input` | Fluent Bit input (`tail`/`systemd`/`syslog`/`tcp`/`winlog`) | infra-agent logs |
| `filePath` | source file | infra-agent `tail` input only |

**Severity name is source-dependent.** Many frameworks use `level`; OpenTelemetry uses `log.level`
and/or `severity.text` (`SeverityText`). Always confirm with `SELECT keyset() FROM Log` or a raw row
before writing `WHERE level = 'ERROR'`.

**`service.name` may be absent on APM-agent logs** — it's an OTel/service convention. For APM logs,
`entity.name` / `entity.guid` are the dependable identifiers.

## Logs in context (the correlation pivot)

This is what makes New Relic investigation powerful: each decorated log line carries **`trace.id`,
`span.id`, `entity.guid`, `entity.name`, `hostname`**, so you can pivot log ↔ distributed trace ↔ APM
error in the UI, or join them in NRQL (`WHERE trace.id = '…'`).

Two flavors:
- **APM logs in context** — the agent adds metadata and forwards logs itself.
- **Infrastructure / OpenTelemetry logs in context** — a forwarder correlates via entity/host + trace
  context.

When an agent can't decorate the record directly it appends a linking blob:

```
NR-LINKING|{entity.guid}|{hostname}|{trace.id}|{span.id}|{entity.name}|
```

⚠️ **Verify the field order before parsing it programmatically.** The order above came from a docs
search snippet; the authoritative spec is
[newrelic-exporter-specs/logging](https://github.com/newrelic/newrelic-exporter-specs/tree/master/logging) —
check there if you're writing code that splits this string.

## Searching logs (UI vs NRQL)

- The Logs UI search bar is **Lucene-based**: bare keywords (`process failed`) or attribute filters
  (`service_name:"my service"`). The left-nav **Attributes** panel and the **+** on a row add filters.
- **Patterns** clusters similar messages — good for spotting a spike or a drop.
- The **NRQL** button converts the current search to NRQL. There's "no direct equivalence" — NRQL is
  often simpler and is what you'll use from the CLI/API.

## Where logs disappear: drop rules & partitions

If a query returns nothing but you're sure the app is logging, check these **before** concluding logs
aren't sent:

- **Drop filter rules** — matching logs are discarded *before storage*. An overly broad rule silently
  removes data. (Alerts → data management / Logs → drop filter rules.)
- **Data partitions** — logs routed to a partition live in a separate event type. Query
  `FROM Log_<PartitionName>` (not `FROM Log`), or union both.
- **Ingest errors** — check `SELECT count(*) FROM NrIntegrationError SINCE 1 hour ago FACET message`
  (⚠️ verify this event type is populated for the account before relying on it).

---

*Sources: log management get started — https://docs.newrelic.com/docs/logs/get-started/get-started-log-management/ ;
logging best practices — https://docs.newrelic.com/docs/logs/get-started/logging-best-practices/ ;
forward logs w/ infra agent (attribute list) — https://docs.newrelic.com/docs/logs/forward-logs/forward-your-logs-using-infrastructure-agent/ ;
Log API — https://docs.newrelic.com/docs/logs/log-api/introduction-log-api/ ;
logs in context — https://docs.newrelic.com/docs/logs/logs-context/logs-in-context/ and
https://docs.newrelic.com/docs/logs/logs-context/get-started-logs-context/ ;
annotate w/ APM agent APIs (NR-LINKING) — https://docs.newrelic.com/docs/logs/logs-context/annotate-logs-logs-context-using-apm-agent-apis/ ;
use logs UI — https://docs.newrelic.com/docs/logs/ui-data/use-logs-ui/ . Fetched July 2026.*
