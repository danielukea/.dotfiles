# Gotchas — Full Detail

The failure modes that waste the most time, in full. The SKILL.md table has the one-line hooks; this
is the "why" and the fix.

## 401 "invalid API key" on any query

Two independent causes, same error:
1. **Wrong key type.** NRQL/NerdGraph/entity queries require a **User key** (`NRAK-` prefix). A
   License/Ingest key (40-char hex) is for *sending* data and will 401 on a query. See
   [cli-and-nerdgraph.md](cli-and-nerdgraph.md#api-key-types-read-this-first).
2. **Wrong or dead key/region.** A `NRAK-` key that is revoked, mistyped, or from a different account
   also 401s — as does hitting the **wrong region endpoint** (US key against the EU endpoint or vice
   versa).

Diagnose, don't guess: `newrelic diagnose validate --profile <name>` validates the profile's key +
region + connectivity end-to-end. If it fails, refresh the User key with `newrelic profile add`.
(Observed on this machine: both configured profiles hold `NRAK-` User keys yet 401 on a live query —
right key *type*, so the fix is re-validating/refreshing the key, not changing its type.)

## NerdGraph returns 200 but results are `null`

NerdGraph is a GraphQL API: **an invalid NRQL query still returns HTTP 200**, with the problem
reported in the JSON `.errors` array and `.data.actor.account.nrql.results` set to `null`. A naive
`jq '.data.actor.account.nrql.results'` then prints `null` and you misread it as "no matching data".
Always evaluate `.errors` first:

```bash
jq -e 'if .errors then (.errors|error(tostring)) else .data.actor.account.nrql.results end'
```

`scripts/nr-nrql.sh` does this. The CLI (`newrelic nrql query`) surfaces query errors on stderr
instead, so this trap is specific to raw curl.

## `WHERE level = 'ERROR'` finds nothing

The severity attribute name is **source-dependent**. Framework/agent logs often use `level`;
OpenTelemetry uses `log.level` and/or `severity.text` (`SeverityText`); some pipelines use `severity`.
If you assume the wrong one, the filter matches nothing and you conclude "no errors" incorrectly.

Inspect first:
```sql
SELECT keyset() FROM Log SINCE 1 day ago        -- what attributes exist?
SELECT * FROM Log SINCE 30 minutes ago LIMIT 1  -- what does a real row look like?
```
Then filter on the attribute that's actually present (or cover both: `WHERE level = 'ERROR' OR
log.level = 'ERROR' OR severity.text = 'ERROR'`).

## Can't filter APM logs by `service.name`

`service.name` is an OpenTelemetry/service-mesh convention and is frequently **absent on logs
forwarded by an APM agent**. The reliable identifiers on APM logs are `entity.name` and `entity.guid`.
Use those; reach for `service.name` only after confirming it exists via `keyset()`.

## Empty log results when the app is clearly logging

`SELECT count(*) FROM Log` returning 0 does **not** prove logs weren't sent. Check, in order:
1. **Time window / batching** — low-volume logs arrive late; widen `SINCE`.
2. **Data partition** — the logs may be in a partition: query `FROM Log_<PartitionName>`, not `FROM Log`.
3. **Drop filter rule** — a rule may discard matching logs *before storage*; review drop rules in the UI.
4. **Ingest errors** — `SELECT count(*) FROM NrIntegrationError SINCE 1 hour ago FACET message`
   (⚠️ confirm this event type is populated for the account first).

See [logs.md](logs.md#where-logs-disappear-drop-rules--partitions).

## NerdGraph JSON body breaks on the NRQL string

NRQL contains double quotes (`WHERE level = "ERROR"` or around ISO timestamps), which collide with
JSON string quoting when you build the request body by hand — you get malformed JSON or a silently
truncated query. **Never string-concatenate.** Build the body with `jq -n` and pass NRQL as a GraphQL
variable typed `Nrql!`, account id as `Int!` (see [cli-and-nerdgraph.md](cli-and-nerdgraph.md#nerdgraph-via-curl)).

## Recent windows look empty then fill in

New Relic batches low-volume log ingestion, so a `SINCE 5 minutes ago` query can under-report and then
"grow" as batches land. This bites two workflows: **confirming a fix** (the after-window looks better
than it is) and **alerting** (a normal batching gap trips a naive threshold). Give windows a buffer;
for alerts, tune the aggregation window / evaluation delay and use loss-of-signal handling.

## `SELECT *` silently truncates

Raw event selects and `FACET` have a low default `LIMIT`. If you're counting rows, enumerating
services, or exporting, add **`LIMIT MAX`** — otherwise you silently see only the first slice and
under-count. (Max explicit `LIMIT` is 5,000.)

## `UNTIL` is exclusive

`UNTIL` excludes its boundary and defaults to `NOW`. `SINCE 2 hours ago UNTIL 1 hour ago` is a
one-hour window that **excludes** the instant exactly one hour ago. For "up to now", just omit
`UNTIL`.

## Verify-before-shipping caveats

Facts from research that are source-dependent — confirm against live data or the cited spec before
relying on them programmatically:

- **`NR-LINKING` field order** — confirm against
  [newrelic-exporter-specs/logging](https://github.com/newrelic/newrelic-exporter-specs/tree/master/logging)
  before parsing the blob in code.
- **`level` vs `log.level` vs `severity.text`** — query the actual attribute set; don't hardcode.
- **`service.name` presence on APM logs** — often absent; prefer `entity.name`/`entity.guid`.
- **`NrIntegrationError` population** — verify the account actually emits it before using it as an
  ingest-error signal.
- **Multi-account / partition scoping** — a query is scoped to one account ID and `FROM Log` excludes
  partitions; confirm both when results seem short.

---

*Sources: as cited in [cli-and-nerdgraph.md](cli-and-nerdgraph.md), [logs.md](logs.md), and
[nrql.md](nrql.md). The 401-on-valid-User-key and NerdGraph-200-with-null observations were verified
directly against the installed CLI v0.112.17 in July 2026.*
