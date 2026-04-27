# Hotspot Harness — StinkScore Generalized

The Skunk gem ([fastruby/skunk](https://github.com/fastruby/skunk)) defined
**StinkScore** for Ruby:

```
StinkScore(file) = complexity(file) × (1 − coverage(file))
```

This harness generalizes the recipe across stacks and adds churn so the score
captures the full extensibility hazard:

```
ExtensibilityScore(file) = complexity(file) × (1 − coverage(file)) × churn(file, 6mo)
```

A file that scores high here is **complex**, **untested**, and **frequently
changed** — the classic recipe for bugs and rippling change cost.

## Inputs by stack

The harness picks the best available signal per stack. If a tool isn't
installed, fall back to the next row.

### Ruby

| Input | Preferred | Fallback |
|-------|-----------|----------|
| Complexity | `skunk` (computes everything together; preferred) | `rubocop --only Metrics --format json` |
| Coverage | SimpleCov `coverage/.resultset.json` | parse RSpec output |
| Churn | `git log --since='6 months ago' --pretty=format: --name-only \| sort \| uniq -c` | — |

If Skunk is available *and* SimpleCov coverage exists in
`coverage/.resultset.json`, prefer Skunk's output directly — it's the canonical
score.

### JavaScript / TypeScript

| Input | Preferred | Fallback |
|-------|-----------|----------|
| Complexity | `fta-cli` (fast, JSON output) | `scc --by-file --format json` |
| Coverage | Jest `coverage/coverage-summary.json` | Vitest `coverage/coverage-final.json`; c8 `coverage.json` |
| Churn | `git log` | — |

`fta-cli` produces "Fast TypeScript Analyzer" scores per file. `scc` gives a
language-agnostic complexity number that works as a proxy.

### Python

| Input | Preferred | Fallback |
|-------|-----------|----------|
| Complexity | `radon cc -s --json` | `scc --by-file` |
| Coverage | `coverage.py` JSON (`coverage json`) | `.coverage` SQLite DB |
| Churn | `git log` | — |

### Go

| Input | Preferred | Fallback |
|-------|-----------|----------|
| Complexity | `gocyclo -over 10 .` | `scc --by-file` |
| Coverage | `go test -coverprofile=cover.out && go tool cover -func=cover.out` | — |
| Churn | `git log` | — |

### Rust

| Input | Preferred | Fallback |
|-------|-----------|----------|
| Complexity | `scc --by-file --format json` | manual file-size proxy |
| Coverage | `cargo tarpaulin --out Json` | — |
| Churn | `git log` | — |

## Computing the score

Pseudo-script (implementation lives in the Complexity & Churn agent):

```bash
# 1. complexity table: file -> complexity score
# 2. coverage table:   file -> percent covered (0..1)
# 3. churn table:      file -> change count (last 6mo)

# join on file path:
join complexity coverage churn |
  awk '{ score = $2 * (1 - $3) * $4; print $1, score }' |
  sort -k2 -rn | head -20
```

If any input is missing for a stack, omit that factor and report the score
with a caveat (e.g., "no coverage data — score is complexity × churn only").
**Never invent a value.**

## Pairing with connascence

The Complexity & Churn agent reports raw hotspots. The synthesis step then
overlays connascence: for each top-10 hotspot, what is the
*highest-strength connascence form* present in that file (from other lenses'
findings)?

```
ExtensibilityHazard(file) = ExtensibilityScore(file) × max_connascence_strength_in(file)
```

This combined score is the headline metric of the report's
**Extensibility Hotspot Table**. It captures both *internal* difficulty
(complexity, untested, churning) and *external* difficulty (this file is
densely connected to others by strong connascence forms).

## Excluding noise

When computing churn, exclude paths that don't represent feature work:

- `db/migrate/` — every change is a new file by construction
- `vendor/`, `node_modules/`, `target/`, `dist/`, `build/`
- Generated files (`*.generated.ts`, `schema.rb`)
- Lockfiles (`yarn.lock`, `Gemfile.lock`, `Cargo.lock`)
- Snapshot test outputs (`__snapshots__/`)

When computing complexity, exclude:

- Test files (they have their own quality lens)
- Auto-generated parsers, GraphQL types, etc.
