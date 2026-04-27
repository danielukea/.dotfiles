# Extensibility Lens

You are answering: *"if requirement X changes next quarter, how many files
must change, and which connascence forms break?"* This is the Open/Closed
question, made concrete via change-impact simulation.

## What to look for

### Implicit branching

Long `case` / `if-elsif` chains that switch on type, role, plan, or
environment. Each branch is a place a new variant must be added — usually in
3+ files, because the same switch is duplicated across layers.

### Switch-on-type

`case object.class.name when …`, `if obj.is_a?(Foo)`, `instanceof` chains.
The OO answer is polymorphism; the FP answer is a sum type with exhaustive
matching. Either beats a stringly-typed switch.

### Hard-coded providers

A single concrete implementation referenced everywhere with no seam:
`Stripe::Charge.create`, `OpenAI::Client.new`, `redis.set(...)`. When the
provider must change, the call sites are the change surface.

### Duplicated extension scaffolding

Adding a new variant requires: (1) a new model, (2) a new migration column,
(3) a new policy class, (4) a new view partial, (5) a new front-end form,
(6) a new test fixture, (7) a registry entry. Each of those is a separate
edit, often in a separate file. The scaffolding *itself* is the smell — a
real extension point would let a new variant be added in one place.

### Closed enums in places that should be open

DB enum columns, TS string-literal unions, Ruby `acts_as_enumerated`. When
the value set is finite and stable, this is fine. When new values are added
quarterly, the enum is a closed door.

### Frozen public APIs without versioning

Public HTTP routes, websocket events, job arg shapes, exported library
classes — if any of these have no version namespace and no deprecation
mechanism, extending them risks silent consumer breakage.

## Change-impact simulation

This is the heart of the lens. After surveying the code:

1. **Infer 3–5 plausible future requirements** from:
   - Open TODOs / FIXMEs / `# TODO:` comments
   - Recent feature flags (changes coming behind them)
   - CLAUDE.md / README mentions of upcoming work
   - Recent commit messages naming the *next* thing
   - The user's stated motivation for invoking this skill

2. **For each requirement, simulate the change:**
   - List every file that would need to change
   - Identify the strongest connascence form that would have to be touched
     across those files (CoA across slices? CoV between an enum and its
     consumers? CoP across a 7-arg method?)
   - Estimate the locality (same slice / cross-slice / cross-service)

3. **Rank requirements by change cost:**
   `cost = file_count × max_connascence_strength × max_locality_multiplier`

4. **Identify the missing seams.** For the highest-cost requirements, what
   single abstraction would cut the change cost? A registry? A strategy
   object? A new slice? A versioned interface? Name the abstraction; don't
   design it.

## How to investigate

### With CLI tools

**ast-grep** for switch-on-type patterns:
```bash
ast-grep --pattern 'case $X.class.name when $$$' --lang ruby
ast-grep --pattern 'if $X instanceof $$$' --lang typescript
ast-grep --pattern 'switch ($X.type) { $$$ }' --lang typescript
```

**semgrep** for hard-coded providers:
```bash
semgrep --pattern 'Stripe.$$$' --pattern 'OpenAI.$$$'
```

**grep** for feature flags (variation points):
```bash
grep -rE 'feature_flag|flipper|launch_darkly|is_enabled' app/ src/
```

**Git log** for "what changed together" — tells you where extensions
historically required coordinated edits:
```bash
# Find recent feature additions
git log --since='6 months ago' --grep='[Aa]dd' --name-only --pretty=format:'---%n%s' |
  awk '/^---/ { msg=$0; n=0; next } NF { files[msg]++; n++ } END { for (m in files) print files[m], m }' |
  sort -rn | head
```

### Without CLI tools

1. Read 3–5 of the most recent feature-adding commits in full. What files
   did they each touch? What's the median count? If it's >5, the codebase
   is hard to extend.
2. For one specific upcoming requirement, do the change in your head:
   list the files. Compare to the historical median.
3. Look for "scaffolding" patterns: places that reward you with a checklist
   of files to add ("create the controller, the policy, the view, the test,
   the type, the route"). Each step is a separate edit and each is a
   separate place to drift.

## Evidence requirement for simulated requirements

Every "future requirement" in your change-impact simulation must be grounded
in **one of**:

- An open `TODO`/`FIXME`/`# HACK` comment in the code
- A feature flag whose name signals upcoming work
- A recent commit message that names the next step
- A line in `CLAUDE.md` / `README.md` / `LEARNINGS.md` describing planned
  work
- The user's stated motivation when invoking the skill

Cite the source per requirement. **Do not invent plausible-sounding future
requirements without a code-level or git-level artifact backing them.** A
generic "what if you added a new LLM provider" doesn't count unless the
code shows signs of expecting one.

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:

- **Change-impact simulations** for 3–5 requirements, ranked by cost. Each
  must cite its evidence source per the rule above.
- **Missing seams**: 2–4 abstractions that would lower future change cost.

## Stack guidance

Load `references/stacks/{detected_stack}.md` for stack-specific patterns and
cite at least one applied pattern in your `### Adapter patterns applied`
section.
