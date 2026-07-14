# Prove-It Playbooks

Symptom-driven NRQL for investigating and **proving** an observability issue. Each playbook is a
progression — a coarse question first, then narrow to the proof. Run these with `scripts/nr-nrql.sh`
or `newrelic nrql query`. Replace `my-service` with the real `entity.name` (confirm it with
`SELECT uniqueCount(entity.name) FROM Log FACET entity.name SINCE 1 day ago`).

General method: **start wide (is there signal?), then facet (where?), then drill (which rows?), then
compare (before/after).** Always keep the query you ran — it *is* the evidence.

## A. Verify ingestion

"Are my logs arriving at all?"

```sql
-- Any logs in the account recently, over time?
SELECT count(*) FROM Log SINCE 30 minutes ago TIMESERIES

-- Which services/hosts are logging, and how much?
SELECT count(*) FROM Log FACET entity.name, hostname SINCE 1 hour ago LIMIT MAX

-- One service specifically, as a time series:
SELECT count(*) FROM Log WHERE entity.name = 'my-service' SINCE 1 hour ago TIMESERIES

-- Is today's volume normal vs yesterday?
SELECT count(*) FROM Log WHERE entity.name = 'my-service' SINCE 1 hour ago COMPARE WITH 1 day ago
```

If empty: don't conclude "not sent" yet — check drop rules, data partitions (`FROM Log_<name>`), and
ingest errors (`SELECT count(*) FROM NrIntegrationError SINCE 1 hour ago FACET message`). See
[logs.md](logs.md#where-logs-disappear-drop-rules--partitions). Also remember low-volume logs batch
and can arrive late — widen the window before deciding.

## B. Root-cause an error spike

"Errors jumped — what and where?"

```sql
-- Confirm & shape the spike over time (mind that `level` may be `log.level`/`severity.text`):
SELECT count(*) FROM Log WHERE level IN ('ERROR','FATAL') SINCE 3 hours ago TIMESERIES

-- Where is it concentrated?
SELECT count(*) FROM Log WHERE level = 'ERROR' FACET entity.name, hostname SINCE 1 hour ago LIMIT 50

-- Which messages dominate?
SELECT count(*) FROM Log WHERE level = 'ERROR' FACET message SINCE 1 hour ago LIMIT 20

-- Pattern match across message text:
SELECT count(*) FROM Log WHERE message RLIKE '(?i)timeout|connection refused|deadlock' SINCE 1 hour ago TIMESERIES

-- Error *rate* (not just count), so a traffic change doesn't fool you:
SELECT percentage(count(*), WHERE level = 'ERROR') FROM Log WHERE entity.name = 'my-service' SINCE 1 hour ago TIMESERIES
```

## C. Correlate logs to a trace

"Which request/trace produced these logs, and what else happened in it?"

```sql
-- All logs for one trace (grab trace.id from a log row or an APM error):
SELECT * FROM Log WHERE trace.id = 'abc123...' SINCE 6 hours ago LIMIT MAX

-- All logs for one span:
SELECT * FROM Log WHERE span.id = 'def456...' SINCE 6 hours ago

-- Erroring spans in APM, to get trace ids to pivot from:
SELECT trace.id, error.message FROM Span WHERE entity.name = 'my-service' AND error IS TRUE SINCE 1 hour ago LIMIT 20
```

In the UI, the logs-in-context panel on an APM error or a distributed trace shows the linked lines
directly — this is the same correlation, visualized.

## D. Confirm a fix (before/after)

"Did the deploy actually reduce the errors?" Two equally valid framings:

```sql
-- Absolute windows around the deploy (edit timestamps to your deploy time):
SELECT count(*) FROM Log WHERE level = 'ERROR' AND entity.name = 'my-service'
SINCE '2026-07-14T09:00:00-04:00' UNTIL '2026-07-14T10:00:00-04:00'    -- before
SELECT count(*) FROM Log WHERE level = 'ERROR' AND entity.name = 'my-service'
SINCE '2026-07-14T10:00:00-04:00' UNTIL '2026-07-14T11:00:00-04:00'    -- after

-- Or one query overlaying now vs a prior window:
SELECT count(*) FROM Log WHERE level = 'ERROR' AND entity.name = 'my-service'
SINCE 30 minutes ago COMPARE WITH 2 hours ago
```

Prove the *rate*, not just the count, if traffic differs between windows (use the `percentage(...)`
form from playbook B). Give the "after" window a buffer for late-arriving low-volume logs.

## E. Detect missing / dropped logs

"Some logs vanished — where?"

```sql
-- Logs that never got correlated (often a decoration/forwarding gap):
SELECT count(*) FROM Log WHERE trace.id IS NULL AND entity.name = 'my-service' SINCE 1 hour ago TIMESERIES

-- A known logtype that should be steady — look for a cliff:
SELECT count(*) FROM Log WHERE logtype = 'mylog' SINCE 6 hours ago TIMESERIES 15 minutes

-- Staleness per service (when did each last log?):
SELECT latest(timestamp) FROM Log FACET entity.name SINCE 1 day ago LIMIT MAX
```

Then check **drop filter rules** and **data partitions** in the UI — an accidental drop rule removes
matching logs before storage, and a partition moves them to `FROM Log_<name>`. Empty ≠ not sent.

## F. NRQL alert conditions

"Alert me when this recurs." Alerts → Alert conditions → new NRQL condition. The query must return
**one numeric value per evaluation window**; set at least one threshold (critical/warning), a
threshold duration, and aggregation settings.

```sql
-- Error-rate condition:
SELECT percentage(count(*), WHERE level = 'ERROR') FROM Log WHERE entity.name = 'my-service'

-- "Logs stopped" volume-floor condition (pair with loss-of-signal handling):
SELECT count(*) FROM Log WHERE entity.name = 'my-service'
```

⚠️ **Low-volume logs batch and arrive late** — New Relic explicitly warns about this for log alerts.
Tune the aggregation window / evaluation delay so a normal batching gap doesn't false-alarm, and use
loss-of-signal settings for "stopped logging" detection rather than a naive `count() < 1`.

---

*Sources: NRQL reference — https://docs.newrelic.com/docs/nrql/nrql-syntax-clauses-functions/ ;
facet across time — https://docs.newrelic.com/docs/nrql/nrql-references/nrql-group-results-across-time/ ;
distributed tracing — https://docs.newrelic.com/docs/distributed-tracing/concepts/how-new-relic-distributed-tracing-works/ ;
create NRQL alert conditions — https://docs.newrelic.com/docs/alerts-applied-intelligence/new-relic-alerts/alert-conditions/create-nrql-alert-conditions/ .
Fetched July 2026.*
