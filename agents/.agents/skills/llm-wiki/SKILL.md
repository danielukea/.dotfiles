---
name: llm-wiki
description: >
  Surface background context from the user's personal wiki (~/Workspace/notes) — decisions,
  people, projects, history — whenever broader context would help, not just when explicitly
  asked. Read-only.
allowed-tools: Read, Glob, Grep, Bash
---

# LLM Wiki — Personal Context Lookup

The user maintains a personal Zettelkasten-style knowledge wiki at `~/Workspace/notes` — atomic,
cross-linked notes on decisions, people, projects, and past investigations, distilled from
meetings, sources, and daily notes. It's written to be read by agents, not just the user.

**Reach for this proactively.** Before answering something about the user's work, a person, a
project, or a past decision — even if not explicitly asked to "check notes" — query the wiki
first. Silence here is a missed context injection, not a safe default.

## Query it

Use the bundled `scripts/wq` (a delegator to the wiki's own query CLI) instead of hand-rolling
grep over the vault:

```bash
scripts/wq search "<term>"                     # full-text in note bodies
scripts/wq tag <tag>                            # notes in a domain
scripts/wq find --tag <tag> --status verified   # compound AND
scripts/wq backlinks <slug>                     # what links to a note
scripts/wq stats                                # orientation: counts, top tags
scripts/wq moc                                  # list all Maps of Content
scripts/wq help                                 # full command list
```

Then read only the candidate notes it surfaces — absolute paths under
`~/Workspace/notes/wiki/notes/*.md` — following one hop of `[[wikilinks]]` if a note points
somewhere relevant. Don't read the whole `notes/` pool; that defeats the point of querying first.

## Answer

- Lead with the answer; cite every claim with `[[note]]` links.
- Prefer `status: verified` notes; say so if you lean on an `unverified` one.
- If the wiki doesn't cover the question, say so plainly rather than silently falling back to raw
  `meetings/`/`daily/`/`sources/` for a quick lookup. If that raw depth is actually needed, point
  the user at the `wiki-query` skill from inside `~/Workspace/notes` itself.

## Gotchas

| Symptom | Real cause |
| --- | --- |
| The wiki's own docs (`wiki/CLAUDE.md`, `wiki/index.md`) reference paths like `wiki/bin/wq` | Those are relative to `~/Workspace/notes`, not your cwd — resolve against that root, or just use this skill's `scripts/wq` instead. |
| Tempted to save a finding back into the wiki | Out of scope here — this skill is read-only by design. Point the user to `wiki-ingest` from inside `~/Workspace/notes`. |
| Wiki has nothing on a general programming/library question | Expected — the wiki is personal/work notes (Wealthbox-focused), not a docs mirror. Use normal codebase search or web docs instead. |
| `scripts/wq` errors with "notes wiki not found" | `~/Workspace/notes` is missing or moved on this machine — say so and proceed without wiki context rather than retrying. |

## More detail

- `~/Workspace/notes/CLAUDE.md` — map of the whole notes repo.
- `~/Workspace/notes/wiki/CLAUDE.md` — the wiki's design doc (note format, MOC rules, progressive disclosure).
- `~/Workspace/notes/.claude/skills/wiki-query/SKILL.md` — the canonical, detailed query methodology this skill's procedure is derived from (only invocable as its own skill from inside that repo, but its written procedure applies here too).
