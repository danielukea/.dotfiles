# Running Queries: the `newrelic` CLI and NerdGraph

Two ways to run NRQL from a terminal. **Prefer the CLI when it's installed** (`command -v newrelic`);
fall back to **NerdGraph curl** for portability (only needs `curl` + `jq`). `scripts/nr-nrql.sh`
picks automatically. Everything here reads credentials from a profile or env — **never hardcode an
account ID or key**.

## Contents

- [API key types (read this first)](#api-key-types-read-this-first)
- [The newrelic CLI](#the-newrelic-cli)
- [NerdGraph via curl](#nerdgraph-via-curl)
- [Which path when](#which-path-when)
- [Credential security](#credential-security)

## API key types (read this first)

| Key | Prefix | Used for |
| --- | --- | --- |
| **User key** | `NRAK-` | **Querying** — NRQL, NerdGraph, entity search. This is what you need. |
| License / Ingest key | 40-char hex | **Sending** data in (agents, Log API, `newrelic events`). Not for querying. |
| Browser key | — | RUM ingest only. |

Querying with a License/Ingest key → **401 invalid API key**. The legacy **REST API keys reached EOL
in 2025** — don't build on them; use NerdGraph. Get/manage keys in the UI (`one.newrelic.com` → "API
keys") or via `newrelic apiAccess` / NerdGraph.

## The `newrelic` CLI

Install (macOS): `brew install newrelic-cli`. Verified against **v0.112.17**.

**Auth — profiles** (stored in `~/.newrelic/credentials.json`):

```bash
newrelic profile add \
  --profile <name> \
  --region <US|EU> \
  --apiKey <NRAK-... User key> \
  --accountId <int>
# --licenseKey is optional, only needed for `newrelic events`.
# Aliases: `profile add` == `profile configure`. Also: profile list | default <name> | delete.
```

**Auth — env vars** (override the profile; ideal for CI/agents):

```bash
export NEW_RELIC_API_KEY=<NRAK-... User key>
export NEW_RELIC_ACCOUNT_ID=<int>     # overrides -a/--accountId
export NEW_RELIC_REGION=US            # US | EU | JP
```

**Global flags** (all commands): `-a/--accountId int`, `--profile <name>`, `--format [JSON|Text|YAML]`
(**default JSON**), `--plain`, `--debug`, `--trace`.

**Commands you'll actually use:**

```bash
# Run NRQL (results array is returned directly — no NerdGraph envelope):
newrelic nrql query --accountId <id> --query "SELECT count(*) FROM Log SINCE 1 hour ago" | jq '.'
newrelic nrql query -a <id> -q "SELECT * FROM Log WHERE level='ERROR' SINCE 30 minutes ago LIMIT 20" \
  | jq -r '.[] | [.timestamp, .level, .message] | @tsv'

# Raw GraphQL — the escape hatch for anything nrql-query doesn't cover:
newrelic nerdgraph query 'query($guid: EntityGuid!){ actor { entity(guid:$guid){ name domain entityType } } }' \
  --variables '{"guid":"<GUID>"}'

# Find entities (to get an entity.name/guid to filter on):
newrelic entity search --name=<name> --domain=<APM|INFRA|BROWSER|...> --reporting=true

# "Is New Relic wired up correctly?" — the single best connectivity check:
newrelic diagnose validate --profile <name>
```

Note: there is **no** top-level `newrelic logs` command — query logs via NRQL against `Log`.

## NerdGraph via curl

Endpoints: **US** `https://api.newrelic.com/graphql`, **EU** `https://api.eu.newrelic.com/graphql`.
Auth header: `API-Key: <NRAK- User key>`. NRQL runs inside the GraphQL `actor` tree:

```graphql
{ actor { account(id: <ACCOUNT_ID>) { nrql(query: "SELECT count(*) FROM Log SINCE 1 hour ago") { results } } } }
```

**Do not hand-concatenate the NRQL into the JSON body** — its double quotes collide with JSON
quoting. Build the payload with `jq -n` and pass NRQL as a GraphQL **variable** (`$q: Nrql!`,
account `$a: Int!`):

```bash
jq -n --argjson a "$NEW_RELIC_ACCOUNT_ID" --arg q "SELECT count(*) FROM Log SINCE 1 hour ago" \
  '{query:"query($a:Int!,$q:Nrql!){actor{account(id:$a){nrql(query:$q){results}}}}",variables:{a:$a,q:$q}}' \
| curl -sS -X POST https://api.newrelic.com/graphql \
    -H "Content-Type: application/json" -H "API-Key: $NEW_RELIC_API_KEY" --data @- \
| jq -e 'if .errors then (.errors|error(tostring)) else .data.actor.account.nrql.results end'
```

**Critical:** NerdGraph returns **HTTP 200 even when the NRQL is invalid** — the error is in
`.errors`, and `.data.actor.account.nrql.results` is `null`. Always check `.errors` first (the `jq -e`
above does), or you'll read a silent `null` as "no data".

## Which path when

- **CLI** — when it's installed and a profile/region is configured. Fewest keystrokes; region and auth
  handled for you; JSON output pipes straight to `jq`. Best on a developer machine.
- **NerdGraph curl** — portable (any box with `curl`+`jq`), fully self-contained (endpoint + auth +
  query visible in one command), and covers the entire API, not just the CLI's wrapped subset. Best in
  CI or an unknown environment.

`scripts/nr-nrql.sh` prefers the CLI and falls back to curl, so you don't have to choose.

## Credential security

- **Never** put a key or account ID in the skill, a script, a commit, or shell history.
- Read from env (`${NEW_RELIC_API_KEY:?}`) or the CLI profile — not inline literals.
- The profile file `~/.newrelic/credentials.json` should be `chmod 600` (user-only). A `NRAK-` User
  key grants API access at the user's permission level — treat it like a password.
- Add `.newrelic/` and `*.env` to `.gitignore`. This repo also enforces a `gitleaks` pre-commit hook.

---

*Sources: newrelic-cli getting started (install, env vars) — https://github.com/newrelic/newrelic-cli/blob/main/docs/GETTING_STARTED.md ;
`nrql query` — https://github.com/newrelic/newrelic-cli/blob/main/docs/cli/newrelic_nrql_query.md ;
`nerdgraph query` — https://github.com/newrelic/newrelic-cli/blob/main/docs/cli/newrelic_nerdgraph_query.md ;
NerdGraph intro (endpoints, API-Key, curl) — https://docs.newrelic.com/docs/apis/nerdgraph/get-started/introduction-new-relic-nerdgraph/ ;
NerdGraph NRQL tutorial — https://docs.newrelic.com/docs/apis/nerdgraph/examples/nerdgraph-nrql-tutorial/ ;
API keys — https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/ ;
REST keys EOL 2025 — https://docs.newrelic.com/whats-new/2025/01/whats-new-03-01-rest-api-keys-eol/ .
Flags verified against installed CLI v0.112.17. Fetched July 2026.*
