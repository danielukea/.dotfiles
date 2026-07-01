---
name: library-docs
description: >
  Fetch current, authoritative documentation for a library, framework, or API
  instead of answering from training memory. Use whenever the answer depends on
  a specific library's real API or behavior — "how do I use <library>", "docs
  for X", "what's the current/latest API/syntax/option for", "does <lib> support
  ...", "the right way to call ...", version-specific usage, an unfamiliar or
  niche library, an error that looks like API drift or a deprecation, or any
  library released or changed after your knowledge cutoff. Prefer this over
  guessing — stale API knowledge is the failure mode it prevents. SKIP when: the
  ask is a broad, multi-source, cited research report (use deep-research); it's
  about the Claude / Anthropic API or models (use claude-api); it's language
  stdlib or a ubiquitous API you know cold; or the project's own rules/docs
  already specify the API.
allowed-tools: Read, WebSearch, WebFetch, ToolSearch, mcp__plugin_context7_context7__*
user-invocable: true
---

# library-docs

Get the *real* docs for a library and apply them, rather than reconstructing an
API from memory. Context7 is the primary source (indexed, version-specific);
official docs on the web are the fallback.

## Sequence

1. **Load the Context7 tools.** They're ToolSearch-gated, so pull the schemas first:

   ```
   ToolSearch("context7 resolve-library-id get-library-docs")
   ```

   Exact names are namespaced — e.g. `mcp__plugin_context7_context7__resolve-library-id`
   and `…__get-library-docs`. If the keyword search surfaces nothing, Context7 isn't
   available in this environment — jump to step 4.

2. **Resolve the library ID.** Call `resolve-library-id` with the library name; pick the
   best match (highest coverage / trust, and the version the user is on if they said one).

3. **Fetch focused docs.** Call `get-library-docs` with that ID plus a specific `topic`
   (the exact API/feature in question) and a sensible token budget. Always scope by
   `topic` — never dump the whole library.

4. **Fallback** (Context7 absent, no good match, or a thin result): `WebSearch` for the
   official documentation page, then `WebFetch` the canonical URL. Prefer official,
   version-matched sources over blog posts.

5. **Apply.** Note the version you consulted, cite the source, and prefer what you fetched
   over training memory when they conflict.

## Notes

- One focused fetch beats a broad dump — scope by `topic`.
- If the user names a version, resolve and fetch that version specifically.
- Hand off deep, multi-source investigations to `deep-research`; Anthropic/Claude API
  specifics belong to `claude-api`.
