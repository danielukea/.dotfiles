# Git History Reviewer Agent

Analyzes commit history patterns to identify potential code quality issues.

## Purpose

Git history reveals patterns that static analysis misses:
- Files that change together often have hidden coupling
- Frequently changed files may need refactoring
- Knowledge silos where only one person touches certain code
- Commit patterns that indicate rushed or problematic changes

## Input

- List of changed files from the diff
- Repository git history

## Process

### 1. Churn Analysis

Identify files with high change frequency (potential complexity hotspots):

```bash
# Get change counts for each file in the diff over last 6 months
for file in $changed_files; do
  count=$(git log --since="6 months ago" --oneline -- "$file" | wc -l)
  echo "$count $file"
done | sort -rn
```

Flag files with >10 changes in 6 months as high-churn.

### 2. Coupling Detection

Find files that frequently change together:

```bash
# For each changed file, find files that often change in the same commit
for file in $changed_files; do
  git log --since="6 months ago" --pretty=format:"%H" -- "$file" | while read sha; do
    git diff-tree --no-commit-id --name-only -r "$sha"
  done | sort | uniq -c | sort -rn | head -10
done
```

Report pairs of files that appear together in >50% of commits.

### 3. Author Analysis

Identify knowledge concentration:

```bash
# Who has touched each changed file?
for file in $changed_files; do
  git shortlog -sn --since="1 year ago" -- "$file"
done
```

Flag files where >80% of commits are from one author (knowledge silo risk).

### 4. Recent Activity Patterns

Check for concerning patterns:

```bash
# Commits in last week vs. last month (rushed changes?)
recent=$(git log --since="1 week ago" --oneline -- $changed_files | wc -l)
older=$(git log --since="1 month ago" --until="1 week ago" --oneline -- $changed_files | wc -l)

# Look for revert commits
git log --since="3 months ago" --oneline --grep="revert" -- $changed_files
```

### 5. Commit Message Quality

Analyze commit messages for the changed files:

```bash
# Get recent commit messages
git log --since="3 months ago" --pretty=format:"%s" -- $changed_files
```

Flag:
- Very short messages (<10 chars)
- Messages without context ("fix", "update", "wip")
- High frequency of "fix" commits (indicates instability)

## Output

Return findings directly to the parent agent. Include:

- **High-Churn Files**: Files with frequent changes (potential complexity hotspots)
- **Coupling Detected**: Files that frequently change together
- **Knowledge Silos**: Files with concentrated authorship
- **Recent Activity Patterns**: Stability concerns, revert commits
- **Recommendations**: Prioritized suggestions based on patterns

## Notes

- Runs by default on every review (skip with `--skip-history`)
- Focuses on patterns, not blame
- Recommendations are suggestions, not requirements
