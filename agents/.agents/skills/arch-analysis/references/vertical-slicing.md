# Vertical Slicing Lens

You are examining whether the code is organized so that a feature change stays
*inside one slice* of the codebase, instead of rippling across many. Vertical
slicing is the strategic counterpart to connascence: it is the technique that
keeps high-strength connascence (CoA, CoE, CoTime, CoV, CoI) **local**, where
it is tolerable.

## The four questions

### 1. Is the code organized by feature (vertical) or by layer (horizontal)?

Inspect the top-level folder structure.

- **Layer-first**: `controllers/`, `services/`, `models/`, `views/`,
  `components/`. A feature is scattered across all of them.
- **Feature-first**: `notifications/`, `billing/`, `automations/`. Each folder
  holds the entire MVC stack for that feature.
- **Hybrid (typical Rails)**: layer-first at the top level but with feature
  *namespacing* inside each layer (`app/services/notifications/*`,
  `app/models/notifications/*`, `app/javascript/notifications/*`). This counts
  as feature-first if the namespacing is consistent and enforced.

Most Rails apps are hybrid. The question to answer: *is the namespacing
consistent across layers, or do features have different names depending on
which layer you're in?*

### 2. Are slice boundaries explicit?

A slice with no public API is not a slice — it's a folder. Look for:

- **Rails Engine** with a documented external interface (`engines/billing/`)
- **Packwerk pack** with `package.yml`, `public/`, and `private/` directories
- **Single entry-point module** like `Billing` re-exporting public types
- **TS feature folder with `index.ts` barrel** as the only intended import path
- **`README.md` inside the slice** documenting what's public

If callers reach into a slice's internals (`Billing::Internal::Calculator`,
`features/billing/utils/feeMath`), the boundary is theoretical.

### 3. Is the dependency direction controlled and acyclic?

Build the slice-to-slice import graph (manual grep is fine if `dep-tree` /
`packwerk` aren't installed) and answer:

- **Are there cycles?** Slice A imports from Slice B which imports from Slice
  A. Cycles destroy the slicing.
- **Which way do dependencies flow?** Hexagonal/Ports-and-Adapters predicts
  the *domain* slices should be at the center with no outward dependencies,
  and infrastructure (HTTP, DB, jobs, mailers, third-party) at the edges
  pointing inward. If the domain imports from infrastructure, the inversion
  is missing.
- **Is direction documented?** Packwerk `dependencies:` lists, ESLint
  `import/no-restricted-paths`, ArchUnit-style tests are all signals that
  someone has thought about direction.

### 4. Are concerns / mixins / HOCs respecting slice direction?

Cross-cutting concerns are the most common way slicing breaks down.

**Healthy direction:**
- `Notifications::Sendable` lives in the Notifications slice.
- Models in *other slices* (`User`, `Account`) include it.
- The concern itself only calls into Notifications-slice code.
- Direction: other-slices → Notifications. Acyclic.

**Diagonal coupling (broken):**
- A concern in slice A includes-or-calls slice B,
- which is included by models in slice C,
- which imports back into slice A.
- The concern has stitched three slices together.

For React: HOCs and shared hooks have the same trap. A `withBillingContext`
HOC living in `features/billing/` that wraps components from
`features/notifications/` and reads from `features/users/` is diagonal.

## How to investigate

### With CLI tools

**Packwerk** (Rails):
```bash
bin/packwerk validate              # boundary configuration health
bin/packwerk check                 # runtime violations
cat packwerk.yml                   # global config
find . -name 'package.yml' -path '*/packs/*' | head    # existing packs
```

**dep-tree** (polyglot):
```bash
dep-tree entropy .                 # single coupling/slicing health score
dep-tree tree app/                 # human-readable tree
```

**dependency-cruiser** (JS/TS):
```bash
depcruise --output-type err src/   # rule violations
depcruise --output-type dot src/ | dot -Tsvg > deps.svg
```

**ESLint** (TS):
```bash
grep -r 'no-restricted-paths\|import/no-restricted-imports' .eslintrc* eslint.config.*
```

Presence of these rules is itself a slicing signal.

### Without CLI tools

Build a manual slice map:

1. **List the candidate slices.** From folder structure, namespacing, or
   feature-flag names. The list should be 5–30 entries; if it's 1, the
   codebase isn't sliced; if it's 100+, you're listing files, not slices.
2. **For each slice, grep imports outward.** `grep -r 'from .features/X/' src/`
   — what does X depend on?
3. **Build the directed graph.** Note cycles (A→B→A) as top-priority findings.
4. **Check the public-vs-internal diff.** What does the slice publish (its
   `index.ts`, public namespace, Engine routes)? What do callers actually
   import? The diff is the boundary leak.

## Signals that the slicing is working

- Adding a new feature creates a new folder; existing folders don't change.
- Removing a feature is a `rm -rf`, plus deleting one or two registry rows.
- A feature can be open in one editor pane without splitting attention.
- Tests for one slice don't load other slices.
- Two engineers can work in different slices without merge conflicts.

## Signals that the slicing is broken

- Adding a feature touches 12 directories.
- "Where does X live?" gets multiple answers.
- A concern is included by 15+ classes from different domains.
- Cross-slice imports outnumber intra-slice imports.
- One God file (`app.ts`, `application_controller.rb`,
  `ApplicationRecord`) accumulates everyone's hooks.
- Removing a feature requires hunting for 30+ scattered references.

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:

- **Slice map**: a table of detected slices, what each owns (which models,
  components, jobs, routes), and which slices each depends on.
- **Boundary violations**: cross-slice imports that reach into internals,
  cycles, diagonal coupling through concerns/HOCs. Tag each with the exact
  connascence formula (typically CoA at across-slices locality).
- **Missing slices**: features that *should* be slices but are scattered.
- **Direction inversions**: domain code depending on infrastructure when it
  should be the other way around.

Cite at least one applied pattern from the loaded stack adapter in your
`### Adapter patterns applied` section.

## References

- *Vertical Slice Architecture* — Jimmy Bogard
- *Screaming Architecture* / Package-by-Feature — Robert C. Martin
- *Modular Monolith* — Shopify `components/` (Sorbet + Packwerk),
  Gusto `components/`
- *Acyclic Dependency Principle* (ADP) — Robert C. Martin
- *Domain-Driven Design* — Eric Evans (bounded contexts, ACL)
- *Hexagonal Architecture* — Alistair Cockburn (ports and adapters)
- Rails Engines — [guides.rubyonrails.org/engines.html](https://guides.rubyonrails.org/engines.html)
