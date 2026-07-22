# Principles — what a skill *is* and what goes in it

## Teach knowledge, don't railroad

Encode what the model **can't derive on its own** — gotchas, org/codebase conventions,
hard-won judgment. Give it the information *and the room to adapt*.

Litmus test: does this skill teach **WHAT to know** or dictate **HOW to work**?

- **Judgment tasks** (design, testing, review) → teach knowledge; let the agent compose
  its own approach. Strip prescription that constrains it — mandatory workflows, review
  gates.
- **Genuinely mechanical tasks** (an API sequence, a DB sync, a safe migration order) →
  the exact steps *are* the correctness. Keep prescription that improves output — safe
  sequences, fan-out for breadth, fixed output formats, finding caps.

## Two layers — keep them separate

- **Knowledge skills** — durable principles / patterns / gotchas. Composable, no
  mandatory workflow, trigger on their own descriptions. (e.g. `design-principles`,
  `test-principles`, `rails-composition-dhh`.)
- **Orchestration skills** — workflows, parallel agent dispatch, API sequences. Keep
  them *thin*, and have them **reference knowledge skills by name** rather than embedding
  the knowledge (e.g. `arch-design` → `design-principles`).

**Anti-pattern:** durable knowledge trapped inside a mandatory orchestration ritual, so
it can't be reused any other way. If the knowledge is valuable, it belongs in a
knowledge skill the orchestrator *calls*.

## Naming tracks scope

The name must never outrun what's inside:

- `<discipline>-principles` — a broad principle set (`design-principles`).
- `<stack>-composition` / a specific pattern name — a focused catalog
  (`rails-composition-dhh`).
- **Keep opinionated provenance in the name** (`-dhh`). A generic "best-practices"
  rename launders the opinion and invites contradictory additions later.
- Broader coverage → a **new sibling skill**, not a catch-all rename of an existing one.

## What to put in (high-signal only)

- **Gotchas** — the single highest-value part. Failure modes found in practice. Most
  good skills start as a few lines and one gotcha, then grow.
- **Conventions the model can't derive** — schema quirks, naming, environment behavior.
- **Decision heuristics** — when to reach for X vs Y.

Avoid:

- **Stating the obvious.** Litmus test (same one used for CLAUDE.md): *would a senior
  developer already know this?* If yes, cut it.
- **Rigid procedures for judgment tasks.**
- **Codebase coupling in a portable skill.** Project-specific commands and paths belong
  in that project's rules, not in a skill meant to travel across repos and agents.

**Corollary for skills over frameworks the model already knows** (JTBD, SOLID, journey
maps): the value is the *traps* and the *when-to-reach-for-it* call — not the framework
definitions. Keep definitions to one-line pointers; spend the words on what goes wrong.

## Progressive disclosure — cut on the decide/do line

Use the file system. Keep `SKILL.md` lean; push detail into `references/`, `templates/`,
`scripts/` that load only when needed.

**The cut is the decide/do line.** What the agent needs to *recognize the skill and
choose an approach* stays in the always-loaded `SKILL.md` — the framing, a decision
table, the boundaries. What it needs only *while producing the artifact* — worked
examples, format strings, fill-in templates — moves one hop away. Test each paragraph:
is this helping me *choose*, or helping me *execute once I've chosen*?

**Keep a hook in the loaded layer.** When you push a gotcha's detail to a reference,
leave a one-line trace in `SKILL.md` (a table cell, a parenthetical). Gotchas are why
the skill exists — don't let progressive disclosure hide them entirely.

**DRY across layers.** Say each thing once. Redundancy is earned only as a
hook→full-detail relationship *across* layers, never a repeat within one layer.

## Composing with peer skills

Most useful skills plug into others. Two failure modes to design out:

- **Description collision.** A new skill at the same altitude as an existing one is
  riskier than any body content — if their triggers overlap, the wrong one fires or both
  do. Give disjoint trigger phrasings and reciprocal `Not for: … — use <sibling>`
  pointers. Read the two descriptions side by side before shipping.
- **A seam isn't real until the handoff artifact carries it.** "Composes into X" is
  cosmetic unless the thing X hands downstream has a slot for your output. Wire it both
  directions — the caller names your skill at the decision point; your skill names the
  caller and respects its boundary — and give the shared artifact (a template, a brief,
  a report format) a place to hold what you produce.
