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
  `rails-composition-dhh`, `react-composition`, `design-principles`, `test-principles`.
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

Corollary for a knowledge skill over frameworks the model already knows (JTBD, SOLID,
journey maps): the value is the **traps and the when-to-reach-for-it call**, not the
framework definitions. Keep the definitions to one-line pointers and spend the words on what
goes wrong — `design-principles` and `user-centered-problem-definition` are built this way.

## Progressive disclosure

Use the file system. Keep `SKILL.md` lean and point to `references/`, `templates/`,
`scripts/` for detail the agent loads only when it needs them.

**Cut on the decide/do line.** What the agent needs to *recognize the skill and choose an
approach* stays in the always-loaded `SKILL.md` — the framing, a decision table, the
boundaries. What it needs only *while producing the artifact* — worked examples, format
strings, fill-in templates — moves to `references/`. Test each paragraph: is this helping me
choose, or helping me execute once I've chosen? Executing-detail belongs one hop away.

**Keep a hook in the loaded layer.** When you push a gotcha's detail to a reference, leave a
one-line trace in `SKILL.md` (a "trap" column, a parenthetical) so the highest-value signal
survives even when the reference is never opened. Gotchas are why the skill exists — don't
let progressive disclosure hide them entirely.

**DRY within a skill.** Say each thing once. Three phrasings of the same caution is two too
many; a gotcha that restates the intro or a table cell is dead weight — cut it. Redundancy is
earned only as a hook→full-detail relationship *across* layers, never as a repeat within one.

## Descriptions are triggers

The `description` frontmatter is how the skill gets selected — write it for the model.
Include the activation keywords and phrasings a user would actually say. A vague
description means the skill never fires.

## Composing skills — peers and seams

Most useful skills plug into others. Two failure modes to design out:

**Description collision.** Adding a skill at the same altitude as an existing one (a second
problem-definition skill beside `brainstorm`) is riskier than any body content — if their
`description` triggers overlap, the wrong one fires or both do. Give them disjoint trigger
phrasings and reciprocal `Not for:` pointers that name the sibling ("…not for X — use
`other-skill`"). Read the two descriptions side by side before shipping; that seam, not the
prose, is where peer skills break.

**A seam isn't real until the handoff artifact carries it.** "Composes into `brainstorm`" is
cosmetic if the thing that skill hands downstream has nowhere to hold your output. Wire it
both directions — the caller names your skill at the decision point; your skill names the
caller and respects its boundary — *and* give the shared handoff artifact (a template, a
brief, a report format) a slot for what you produce. Otherwise the work evaporates at the
handoff. (This repo: the `user-centered-problem-definition` map only reached `arch-design`
once `brainstorm`'s Problem Brief template gained a Users & Stakeholders section.)

## Start small, iterate, measure

- Ship a few lines + one gotcha; grow from real usage, not speculation.
- Usage is logged deterministically by a `PostToolUse` hook (see
  `agents/.agents/scripts/agent-usage-logger.sh`) → `~/.claude/logs/skill-usage.jsonl`.
  Claude Code invocations are `detection:"explicit"` (a real `Skill` tool call); Codex has
  no such tool call, so its entries are `detection:"inferred"` — heuristically detected
  from shell commands that open a `SKILL.md` — and are weaker evidence of real use. Audit
  which skills earn their keep with the `skill-prune` skill.

## Evals: specs vs runs

`/skill-creator` produces two kinds of eval artifact — keep them apart so run output
never clutters the skills tree or the git history:

- **Eval specs** (`evals.json`) are the source of truth: small, hand-authored, tracked.
  They live *beside* the skill at `claude/.claude/skills/<skill>/evals/evals.json`.
- **Eval runs** (benchmark/grading/timing JSON, generated reports) are large and
  regenerable. They live *outside* the skills tree at `claude/.claude/skill-evals/<skill>/`
  and are gitignored. Anything skill-creator drops as `<skill>-workspace/` inside `skills/`
  is also gitignored — move it to `skill-evals/` when you want to keep it around.

## Maintenance

- Where skills live and how they're linked: see the memory note on skill-source layout
  (`~/.claude/skills` symlinks into this repo; keep skills dotfiles-canonical).
- After creating/editing a skill in this repo, run `./link.sh link` so the symlink
  picks it up.
