# NRQL — New Relic Query Language

The one language for everything in NRDB. Read this for exact clause order, functions, operators, and
time windows. For the log-specific attributes you'll filter on, see [logs.md](logs.md); for
symptom-driven queries, see [investigate.md](investigate.md).

## Contents

- [Clause structure](#clause-structure)
- [The Log event type](#the-log-event-type)
- [Aggregator & row functions](#aggregator--row-functions)
- [WHERE operators](#where-operators)
- [Time windows](#time-windows)
- [FACET, TIMESERIES, COMPARE WITH](#facet-timeseries-compare-with)
- [LIMIT and truncation](#limit-and-truncation)

## Clause structure

`SELECT` and `FROM` are required; everything else is optional. Canonical order:

```
SELECT function(attribute) [AS 'label'] [, ...]
FROM dataType [, dataType2 ...]
[WHERE attribute <comparison> value [AND|OR ...]]
[FACET attribute | function(attribute) [, ...]]
[LIMIT n | LIMIT MAX] [OFFSET n]
[ORDER BY attribute|function [ASC|DESC]]
[SINCE time] [UNTIL time]
[WITH TIMEZONE 'zone']
[COMPARE WITH time]
[TIMESERIES time | AUTO | MAX [SLIDE BY time]]
```

- `SELECT *` returns raw attributes of each row; `SELECT func(attr)` returns an aggregate.
- Multiple data types: `FROM Log, Transaction`.
- Query variables and conditional facets exist too: `WITH … AS`, `FACET CASES(...)`, plus `JOIN`,
  `EXTRAPOLATE` (compensate for APM sampling), and `PREDICT`/`predictLinear`.

## The Log event type

Logs are the `Log` event type:

```sql
SELECT * FROM Log SINCE 1 hour ago LIMIT MAX
```

- A **data partition** is its own event type: `FROM Log_MyPartition`. You can union: `FROM Log, Log_MyPartition`.
- Which attributes exist depends on the log source — list them with:

```sql
SELECT keyset() FROM Log SINCE 1 day ago          -- all attribute names present
SELECT * FROM Log SINCE 30 minutes ago LIMIT 1    -- inspect one real row
```

See [logs.md](logs.md) for the common attributes (`message`, `level`, `timestamp`, `entity.name`,
`entity.guid`, `trace.id`, `span.id`, `hostname`, `logtype`).

## Aggregator & row functions

**Aggregators** (use with or without `FACET`):

| Function | Use |
| --- | --- |
| `count(*)` | number of matching rows — the workhorse for volume/spike/ingestion |
| `uniqueCount(attr)` | distinct values, e.g. `uniqueCount(entity.name)` |
| `percentage(count(*), WHERE …)` | share of rows meeting a condition (error rate) |
| `filter(count(*), WHERE …)` | a sub-aggregate inside a broader query |
| `rate(count(*), 1 minute)` | normalize a count to a per-time rate |
| `latest(attr)` / `earliest(attr)` | most/least recent value (e.g. `latest(timestamp)` for staleness) |
| `average` / `sum` / `min` / `max` / `median` | numeric aggregates |
| `percentile(attr, 95, 99)` | latency-style percentiles |
| `histogram(attr)` / `apdex(attr, t:)` | distributions / apdex |

**Row/string helpers:** `capture(attr, r'regex')` (RE2 capture), `aparse(attr, 'pattern*')`,
`concat`, `if(...)`, `getField`, `numeric(attr)`, `eventType()`, `accountId()`.

## WHERE operators

- Comparison: `= != < <= > >=`, combined with `AND` / `OR` and parentheses.
- `LIKE` / `NOT LIKE` — `%` wildcard, **case-insensitive**: `WHERE message LIKE '%timeout%'`.
- `RLIKE` / `NOT RLIKE` — RE2 regex: `WHERE message RLIKE '(?i)connection refused|timeout'`.
- `IN (...)` / `NOT IN (...)`: `WHERE level IN ('ERROR','FATAL')`.
- `IS NULL` / `IS NOT NULL`: `WHERE trace.id IS NULL` (find un-correlated logs).
- `IS TRUE` / `IS FALSE`: `WHERE error IS TRUE`.

## Time windows

- **Relative:** `SINCE 1 hour ago`, `SINCE 30 minutes ago UNTIL 10 minutes ago`, `SINCE 1 day ago`,
  `SINCE yesterday`.
- **Absolute (ISO 8601, quote it):** `SINCE '2026-07-14T12:00:00-04:00' UNTIL '2026-07-14T13:00:00-04:00'`.
- `UNTIL` is **exclusive**; default is `UNTIL NOW`. So `SINCE 1 hour ago` means the last hour up to now.
- `WITH TIMEZONE 'America/New_York'` sets the display/bucketing zone.

## FACET, TIMESERIES, COMPARE WITH

- **`FACET attr[, attr2]`** — group results (up to two facets): `FACET entity.name, hostname`. Default
  facet limit is small; add `LIMIT MAX` to see all groups.
- **`TIMESERIES [time|AUTO|MAX]`** — return a time series instead of one number; add `SLIDE BY 1 minute`
  for a sliding (smoothed) window: `TIMESERIES 5 minutes SLIDE BY 1 minute`.
- **`COMPARE WITH <time>`** — overlay an earlier window for before/after proof: `SINCE 30 minutes ago
  COMPARE WITH 1 day ago` shows now vs the same slot yesterday.

## LIMIT and truncation

- `LIMIT n` caps rows/facets (max 5,000). Use **`LIMIT MAX`** when you need completeness — otherwise
  raw `SELECT *` and `FACET` silently truncate and you'll under-count.
- `OFFSET n` pages; `ORDER BY` sorts (defaults are aggregate-dependent, so be explicit for `SELECT *`).

---

*Sources: NRQL syntax, clauses & functions — https://docs.newrelic.com/docs/nrql/nrql-syntax-clauses-functions/ ;
NRQL intro — https://docs.newrelic.com/docs/nrql/get-started/introduction-nrql-how-nrql-works/ ;
group results across time — https://docs.newrelic.com/docs/nrql/nrql-references/nrql-group-results-across-time/ .
Fetched July 2026.*
