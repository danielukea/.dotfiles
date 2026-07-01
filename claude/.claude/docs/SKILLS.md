# Skills — Building and Maintaining

Principles for authoring skills that actually improve agent output. Distilled from
Anthropic's ["Lessons from building Claude Code: how we use skills"](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills)
and this repo's own experience. Read this before creating or editing a skill.

## What a skill is

Not just a markdown file — a folder of instructions plus optional `references/`,
`templates/`, and `scripts/` that an agent discovers and uses. It can carry
reference material and executable helpers, not only prose.

## The core principle: teach knowledge, don't railroad

Encode what the model **can't derive on its own** — gotchas, org/codebase
conventions, hard-won judgment. Give it the information *and the flexibility to
adapt*. Don't force a rigid step-by-step procedure onto a task that needs judgment.

Litmus test: does this skill teach **WHAT to know**, or dictate **HOW to work**?
- Judgment tasks (design, testing, review) → teach knowledge; let the agent compose.
- Genuinely mechanical tasks (API call sequences, DB sync, safe migrations) → exact
  steps ARE the correctness. Prescription there is right, not railroading.

Strip prescription that constrains judgment (mandatory workflows, review gates).
Keep prescription that improves output (safe sequences, agent-dispatch for breadth,
fixed output formats, finding caps).

## Two layers — keep them separate

- **Knowledge skills**: durable principles/patterns/gotchas. Composable, no mandatory
  workflow, trigger on their own descriptions. Models in this repo:
  `rails-composition-dhh`, `react-composition`, `design-principles`, `write-tests`.
- **Orchestration skills**: workflows, parallel agent dispatch, API sequences. Keep
  them thin and have them **reference knowledge skills by name** rather than embedding
  the knowledge (e.g. `arch-design` → `design-principles`).

Anti-pattern: durable knowledge trapped inside a mandatory orchestration ritual, so it
can't be used any other way.

## Naming convention

The name tracks content **scope** — never let it outrun what's inside:
- `<discipline>-principles` — a broad principle set (`design-principles`, `testing-principles`).
- `<stack>-composition` / a specific pattern name — a focused catalog (`rails-composition-dhh`).

Keep opinionated provenance in the name (`-dhh`) — a generic "best-practices" rename
launders the opinion and invites contradictory additions. Broader coverage → a new
sibling skill, not a catch-all rename.

## What to put in (high-signal content)

- **Gotchas** — the single highest-value part. Capture failure modes found in practice;
  grow the list over time. "Most of our best skills began as a few lines and one gotcha."
- **Conventions the model can't derive** — schema quirks, naming, environment behavior.
- **Decision heuristics** — when to reach for X vs Y.

Avoid: stating the obvious (a senior dev / the model already knows it); rigid procedures
for judgment tasks; and **codebase coupling in a general skill** — project-specific
commands/paths belong in that project's rules (e.g. `crm-web/.claude/rules/`), not in a
portable skill.

## Progressive disclosure

Use the file system. Keep `SKILL.md` lean and point to `references/`, `templates/`,
`scripts/` for detail the agent loads only when it needs them.

## Descriptions are triggers

The `description` frontmatter is how the skill gets selected — write it for the model.
Include the activation keywords and phrasings a user would actually say. A vague
description means the skill never fires.

## Start small, iterate, measure

- Ship a few lines + one gotcha; grow from real usage, not speculation.
- Usage is logged deterministically by a `PostToolUse` hook (see
  `scripts/agent-usage-logger.sh`) → `~/.claude/logs/skill-usage.log`. Audit which
  skills earn their keep with the `skill-prune` skill.

## Maintenance

- Where skills live and how they're linked: see the memory note on skill-source layout
  (`~/.claude/skills` symlinks into this repo; keep skills dotfiles-canonical).
- After creating/editing a skill in this repo, run `./link.sh link` so the symlink
  picks it up.
