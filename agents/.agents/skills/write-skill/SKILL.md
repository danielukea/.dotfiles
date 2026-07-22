---
name: write-skill
description: How to write or edit a skill well — SKILL.md structure, triggering descriptions, gotchas. Use when creating, writing, editing, or reviewing a skill or SKILL.md. Not for: pruning skills — use `skill-prune`.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Skill
---

# Write a Skill

The entry point for authoring or editing a skill well. A skill is a folder — a
`SKILL.md` plus optional `references/`, `templates/`, `scripts/` — that an agent
discovers by its `description` and loads when it's relevant.

**This SKILL.md is thin on purpose.** It carries the framing, the routing, and the
gotchas — the things you need to _decide how to proceed_. The actual craft lives in
`references/`; open the one that matches the step you're on. Don't read them all up
front.

**Skills teach knowledge; they don't railroad.** Encode what the model can't derive on
its own — gotchas, conventions, hard-won judgment — and leave it room to adapt. Force
exact steps only when the steps _are_ the correctness (an API sequence, a safe
migration order). For judgment tasks, teaching beats a mandatory workflow.

## The work (decide → open the reference)

Pick what the task needs; this is a toolkit, not a pipeline.

| You're deciding…                                                                       | Open                                |
| -------------------------------------------------------------------------------------- | ----------------------------------- |
| What the skill _is_ — knowledge vs orchestration, its name, what to put in / leave out | `references/principles.md`          |
| The `description` (how it gets triggered)                                              | `references/descriptions.md`        |
| File layout and frontmatter fields                                                     | `references/anatomy.md`             |
| How to grow and measure it after shipping                                              | `references/evals-and-iteration.md` |
| Reviewing / auditing an existing skill                                                 | `references/reviewing.md`           |

## Scaffold and check

- Copy `templates/SKILL.md.template` as the starting point — it already has the
  frontmatter and an append-only `## Gotchas` section.
- Run `scripts/validate_skill.sh <path-to/SKILL.md>` to sanity-check frontmatter,
  name/folder match, description length, the `## Gotchas` section, and that any paths the
  body names exist.

## See also

- `~/.agents/docs/SKILLS.md` — the fuller narrative behind these references.
- `skill-creator` skill — the automated draft → test → grade → iterate eval loop.

## Gotchas

**Append new failure modes here as you hit them** — this growing list is the highest-value
part of any skill, and the thing to lead with. A skill with no gotchas is usually just
restating what a senior dev (or the model) already knows.

Each line below is a hook, not the full teaching — follow the pointer for the detail.

- **Start a new skill aggressively small.** One paragraph plus a `## Gotchas` section is
  often the whole thing — grow it from real use, don't speculate it up front — see
  `references/evals-and-iteration.md`.
- **Descriptions start lean.** ~30–40 tokens to start; grow toward the 120 ceiling only on
  evidence of under-triggering — see `references/descriptions.md`.
- **No project coupling in a portable skill** — see `references/principles.md`.
- **DRY across layers.** Say each thing once; a `SKILL.md` line should _hook_ a reference,
  not re-teach it — see `references/principles.md`.
- **Peer collision.** Read a new skill's `description` beside its nearest sibling before
  shipping — overlapping triggers fire the wrong skill — see `references/descriptions.md`.
- **The format authority is this guidance, not the nearest existing skill.** Peer skills
  may predate the current rules — copying one's shape (e.g. a fat `## Gotchas` _table_ that
  mirrors its own gotchas reference in full) reproduces its drift. This section — a compressed,
  append-only hook list — and `templates/SKILL.md.template` are the model. Reach for the
  peer only to learn the domain, not the format.
- **A green `validate_skill.sh` is not a passed review.** The linter proves the heading
  _exists_; it can't see DRY duplication, altitude, or railroading. Run the judgment passes
  in `references/reviewing.md` on your own output before shipping — don't let the mechanical
  check stand in for them.
- **A gotcha is a learning that changes a future decision — not a definition or commentary.**
  Writing this list, an agent tried to add "`## Gotchas` documents traps in using the skill"
  — true, but it tells a reader nothing to _do_. If an agent wouldn't act differently after
  reading it, it isn't a gotcha. Name the failure that actually happened and the fix.
