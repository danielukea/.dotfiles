#!/usr/bin/env bash
#
# nr-nrql.sh — run an NRQL query against New Relic and print the result rows.
#
# Prefers the `newrelic` CLI when installed (it reads region/auth from the profile);
# otherwise falls back to the NerdGraph GraphQL API with curl + jq. Either way the
# query text is passed safely (no hand-concatenation) and NerdGraph's silent
# "HTTP 200 with .errors" trap is guarded.
#
# Credentials come from the environment / CLI profile — NEVER hardcode a key or
# account id in this file or in a commit.
#
#   NEW_RELIC_API_KEY      User key, prefix NRAK-  (required for the curl fallback)
#   NEW_RELIC_ACCOUNT_ID   numeric account id      (required for the curl fallback;
#                                                    optional with the CLI if the
#                                                    profile already sets it)
#   NEW_RELIC_REGION       US (default) | EU        (selects the NerdGraph endpoint)
#
# Usage:
#   ./nr-nrql.sh "SELECT count(*) FROM Log WHERE level='ERROR' SINCE 30 minutes ago FACET entity.name"
#
set -euo pipefail

query="${1:-}"
if [ -z "$query" ]; then
  echo "usage: nr-nrql.sh \"SELECT ... FROM Log SINCE 1 hour ago\"" >&2
  exit 64
fi

if command -v newrelic >/dev/null 2>&1; then
  # CLI path — JSON by default; returns the results array directly (no envelope).
  newrelic nrql query \
    ${NEW_RELIC_ACCOUNT_ID:+--accountId "$NEW_RELIC_ACCOUNT_ID"} \
    --query "$query" | jq '.'
else
  # NerdGraph curl fallback — needs curl + jq.
  acct="${NEW_RELIC_ACCOUNT_ID:?set NEW_RELIC_ACCOUNT_ID (numeric account id)}"
  key="${NEW_RELIC_API_KEY:?set NEW_RELIC_API_KEY (NRAK- User key)}"
  endpoint="https://api.newrelic.com/graphql"
  [ "${NEW_RELIC_REGION:-US}" = "EU" ] && endpoint="https://api.eu.newrelic.com/graphql"

  # Build the GraphQL body with jq so NRQL double-quotes are escaped correctly,
  # passing NRQL as a variable ($q: Nrql!) rather than concatenating it in.
  jq -n --argjson acct "$acct" --arg q "$query" '{
    query: "query($acct: Int!, $q: Nrql!) { actor { account(id: $acct) { nrql(query: $q) { results } } } }",
    variables: { acct: $acct, q: $q }
  }' \
  | curl -sS -X POST "$endpoint" \
      -H "Content-Type: application/json" \
      -H "API-Key: $key" \
      --data @- \
  | jq -e 'if .errors then (.errors | error(tostring))
           else .data.actor.account.nrql.results end'
fi
