# Variation Points Lens

You are inventorying *where the code already supports variation cleanly* and
*where variation is implicit, scattered, or absent*. Every codebase has
points that change often (per-tenant, per-plan, per-experiment, per-region);
the question is whether those points are *named* or *smeared*.

## Categories of variation points

### Explicit and clean ✓
- **Strategy / Policy objects**: a class hierarchy or interface where each
  concrete impl handles one variant.
- **Registries**: `Notifier.register(:slack, SlackNotifier)`. New variants
  plug in without touching call sites.
- **Polymorphism**: STI with subclass-specific behavior, or duck-typed
  classes implementing a shared interface.
- **Feature flags / experiments**: short-lived flags wrapped in a single
  `Flipper.enabled?(:thing, user)` call.
- **Configuration files**: behavior toggled via YAML/ENV instead of code.
- **Plugin / extension points**: documented hooks (`ActiveSupport::Notifications`,
  middleware stacks, lifecycle callbacks) that third parties can register
  against.
- **Generic factories**: `Discount.for(plan)` returns the right variant.

### Implicit and dirty ✗
- **`if/elsif` on type**: same switch repeated in 3+ places.
- **`case env when 'production'`**: env-checks scattered through business
  logic instead of injected at composition.
- **Copy-paste-then-edit**: a near-duplicate file `BillingV2`, `BillingNew`,
  `BillingExperimental`, each with small diffs.
- **Stale flags**: feature flags older than 6 months that no longer toggle
  anything but still gate code.
- **Magic strings as discriminators**: `if user.role == 'admin'` repeated
  everywhere instead of a Role object.
- **Conditional includes / mixins**: `include AdminFeatures if admin?` —
  variation expressed as conditional class structure.

## How to investigate

### Inventory existing seams

For each candidate seam type, count and locate:

```bash
# Strategy/registry hints
grep -rn 'register\|registry\|strategy\|policy' app/ lib/ src/

# Feature flags
grep -rnE 'flipper|feature_flag|launch_darkly|is_enabled\(|FlagsClient'

# Policy objects (Pundit, etc.)
ls app/policies/ 2>/dev/null

# Polymorphism: STI
grep -rn 'self.inheritance_column' app/models/

# Duck-typed contracts (Ruby): modules included by 3+ classes
grep -rn 'include [A-Z]' app/ | awk '{print $NF}' | sort | uniq -c | sort -rn | head
```

### Find dirty variation

```bash
# Repeated case-on-type
ast-grep --pattern 'case $X.class.name when $$$' --lang ruby
ast-grep --pattern 'switch ($X.type) { $$$ }' --lang typescript

# Env switches in business logic
grep -rnE 'Rails\.env\.|process\.env\.NODE_ENV' app/ src/ | grep -v 'config/'

# Near-duplicate filename heuristic
find . -type f \( -name '*New.*' -o -name '*V2.*' -o -name '*Old.*' -o -name '*Legacy.*' \) | grep -v node_modules | grep -v vendor

# Stale feature flags (no recent commits touching them)
for flag in $(grep -rohE 'flipper.enabled\?\(:[a-z_]+' . | sort -u); do
  echo "$flag last touched: $(git log -1 --format='%ar' --grep "${flag#*:}")"
done
```

### Map variation density

Per file, count: how many `if`/`case` branches discriminate on the same
identifier? A file with 8 different `if user.plan == 'pro'` checks is begging
for a `Plan` object.

## Two heuristics

### "Adding the next variant" thought experiment
For each implicit variation point, simulate: *if I had to add a new
variant tomorrow, where would I edit?* If the answer is one file, the
seam is fine. If it's six files, the seam is missing.

### "Configuration vs. code" balance
Count what's in config vs what's in code. **Both directions are smells:**
- Hard-coded values that change per environment → push to config.
- Config files that contain branching logic, conditionals, or string
  interpolation → pull back to code (configuration is becoming a poorly
  typed DSL).

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:

- **Clean variation points**: a table — name, type (strategy / registry /
  flag / config / polymorphism), and how a new variant is added.
- **Dirty variation points**: each as a Finding using the exact schema
  (Connascence formula tag — typically CoA or CoV).
- **Missing seams**: variations that should be named but aren't. Recommend
  a specific abstraction (registry, strategy, polymorphism) per finding.
- **Stale flags**: feature flags older than 6 months that should be reaped.

## Stack guidance

Load `references/stacks/{detected_stack}.md`. Cite at least one applied
pattern in your `### Adapter patterns applied` section.
