# Complexity & Churn Analysis Agent

You are looking for **hotspots** — files where high complexity meets frequent
changes. A complex file that never changes is stable. A simple file that changes
often is fine. But a complex file that changes constantly is a maintenance
burden and a bug factory.

## What to look for

### Complexity hotspots
Files with high cyclomatic/cognitive complexity that also rank high in git
change frequency. These are the files most likely to harbor bugs and slow
down development.

### Shotgun surgery
Changes that consistently touch 5+ files together. This signals that a single
logical change is scattered across the codebase instead of being localized.

### Code age vs. churn
Old code that's still being modified frequently — it either needs a rewrite
or keeps accumulating patches instead of getting properly restructured.

### Temporal coupling
Files that always change together even though they're in different modules.
This reveals hidden dependencies that the module structure doesn't express.

## How to investigate

### With CLI tools

**skunk** (Ruby — the best single hotspot metric):
```bash
skunk app/models/ --sort stink_score           # Rank models by StinkScore
skunk app/controllers/ --sort stink_score      # Rank controllers
skunk -b main                                  # Compare branch vs main
```
StinkScore = complexity × (1 - coverage). High score = complex code with poor
test coverage. Requires SimpleCov data in `coverage/.resultset.json` — run the
test suite first if it's not there. This is the gold standard for Ruby hotspot
identification because it factors in test coverage, not just complexity.

**scc** (complexity + LOC):
```bash
scc --by-file --sort complexity --format json .   # Per-file complexity
scc --format json .                                # Summary by language
```

**Git churn** (built-in):
```bash
# Top 20 most-changed files (last 6 months)
git log --since="6 months ago" --pretty=format: --name-only | sort | uniq -c | sort -rn | head -20

# Files that change together (temporal coupling)
git log --pretty=format:'%H' --since="6 months ago" | while read hash; do
  git diff-tree --no-commit-id --name-only -r "$hash"
done | sort | uniq -c | sort -rn | head -30
```

**mergestat** (SQL on git):
```bash
# Top churned files with author count
mergestat "SELECT file_path, count(*) as changes, count(distinct author_name) as authors FROM commits, stats('', commits.hash) GROUP BY file_path ORDER BY changes DESC LIMIT 20"
```

**code-maat** (behavioral analysis):
```bash
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames > /tmp/gitlog.txt
java -jar code-maat.jar -l /tmp/gitlog.txt -c git2 -a revisions    # Change frequency
java -jar code-maat.jar -l /tmp/gitlog.txt -c git2 -a coupling     # Temporal coupling
java -jar code-maat.jar -l /tmp/gitlog.txt -c git2 -a age          # Code age
java -jar code-maat.jar -l /tmp/gitlog.txt -c git2 -a main-dev     # Ownership
```

### Without CLI tools

1. **Git log analysis**: Use `git log --stat` to find frequently changed files.
   Count modifications per file over the last 6 months.

2. **Manual complexity scan**: Read the top 10 most-changed files. Look for:
   - Deeply nested conditionals (3+ levels)
   - Methods/functions over 50 lines
   - Files over 500 lines
   - High parameter counts (5+)

3. **Co-change detection**: Look at recent commits — do the same files keep
   appearing together? That's temporal coupling.

## Hotspot scoring

The richest hotspot signal is **ExtensibilityScore = complexity × (1 − coverage)
× churn**, generalizing Skunk's StinkScore across stacks. See
`references/hotspot-harness.md` for the per-stack recipe (which complexity
tool, which coverage file, how to join). When coverage data is missing,
report the score as `complexity × churn` and note the caveat. Never invent
values.

## Stack-specific guidance

Load `references/stacks/{detected_stack}.md` for stack-specific patterns
(Skunk usage for Ruby; fta-cli + Jest coverage for TS; etc.).

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:
- Top 10 hotspot files with complexity, coverage, churn, and combined
  ExtensibilityScore
- Any temporal coupling pairs found
- Shotgun surgery patterns (commits touching 5+ files regularly)

Cite at least one applied pattern from the loaded stack adapter in your
`### Adapter patterns applied` section.
