# Principles — what a skill _is_ and what goes in it

## Teach knowledge, don't railroad

Encode what the model **can't derive on its own** — gotchas, org/codebase conventions,
hard-won judgment. Give it the information _and the room to adapt_.

Litmus test: does this skill teach **WHAT to know** or dictate **HOW to work**?

- **Judgment tasks** (design, testing, review) → teach knowledge; let the agent compose
  its own approach. Strip prescription that constrains it — mandatory workflows, review
  gates.
- **Genuinely mechanical tasks** (an API sequence, a DB sync, a safe migration order) →
  the exact steps _are_ the correctness. Keep prescription that improves output — safe
  sequences, fan-out for breadth, fixed output formats, finding caps.

## Two layers — keep them separate

- **Knowledge skills** — durable principles / patterns / gotchas. Composable, no
  mandatory workflow, trigger on their own descriptions. (e.g. `code-design-principles`,
  `test-principles`.)
- **Orchestration skills** — workflows, parallel agent dispatch, API sequences. Keep
  them _thin_, and have them **reference knowledge skills by name** rather than embedding
  the knowledge (e.g. `arch-design` → `code-design-principles`).

**Anti-pattern:** durable knowledge trapped inside a mandatory orchestration ritual, so
it can't be reused any other way. If the knowledge is valuable, it belongs in a
knowledge skill the orchestrator _calls_.

## Naming tracks scope

The name must never outrun what's inside:

- `<discipline>-principles` — a broad principle set (`test-principles`).
- **Qualify a discipline whose bare word is ambiguous.** `code-design-principles`, not
  `design-principles` — the unqualified name reads as _visual_ design, so agents load it
  for frontend work it doesn't cover. The qualifier is the cheapest disambiguation there
  is; reach for it before a `Not for:` pointer.
- `<stack>-composition` / a specific pattern name — a focused catalog
  (`react-composition`).
- `<domain>` alone — a **router** that legitimately owns a whole domain and dispatches to
  its own references (`rails`). Earn this name before taking it: the skill must cover the
  domain broadly, not one opinionated slice of it.
- **Don't launder an opinion into a neutral-sounding name.** A focused catalog renamed to
  "best practices" invites contradictory additions later, because nothing signals what the
  guidance is committed to. The guard is that the commitment stays legible — either in the
  name, or, in a domain router, by stating the position outright and grounding each claim
  with a `file:line` citation or a measurement. Provenance can move; it can't evaporate.
- Broader coverage → usually a **new sibling skill**, not a catch-all rename. Consolidate
  instead only when the siblings are facets of one domain an agent meets as a unit — and
  then repoint every skill that named the old one (`grep -rn <old-name>`), including any
  doc that used it as an example. `rails` absorbed `rails-composition-dhh` this way.

## What to put in (high-signal only)

- **Gotchas** — the single highest-value part. Failure modes found in practice. Most
  good skills start as a few lines and one gotcha, then grow.
- **Conventions the model can't derive** — schema quirks, naming, environment behavior.
- **Decision heuristics** — when to reach for X vs Y.

Avoid:

- **Stating the obvious.** Litmus test (same one used for CLAUDE.md): _would a senior
  developer already know this?_ If yes, cut it.
- **Rigid procedures for judgment tasks.**
- **Codebase coupling in a portable skill.** Project-specific commands and paths belong
  in that project's rules, not in a skill meant to travel across repos and agents.

**Corollary for skills over frameworks the model already knows** (JTBD, SOLID, journey
maps): the value is the _traps_ and the _when-to-reach-for-it_ call — not the framework
definitions. Keep definitions to one-line pointers; spend the words on what goes wrong.

## Progressive disclosure — cut on the decide/do line

Use the file system. Keep `SKILL.md` lean; push detail into `references/`, `templates/`,
`scripts/` that load only when needed.

**The cut is the decide/do line.** What the agent needs to _recognize the skill and
choose an approach_ stays in the always-loaded `SKILL.md` — the framing, a decision
table, the boundaries. What it needs only _while producing the artifact_ — worked
examples, format strings, fill-in templates — moves one hop away. Test each paragraph:
is this helping me _choose_, or helping me _execute once I've chosen_?

**Keep a hook in the loaded layer.** When you push a gotcha's detail to a reference,
leave a one-line trace in `SKILL.md` (a table cell, a parenthetical). Gotchas are why
the skill exists — don't let progressive disclosure hide them entirely.

**DRY across layers.** Say each thing once. Redundancy is earned only as a
hook→full-detail relationship _across_ layers, never a repeat within one layer.

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
