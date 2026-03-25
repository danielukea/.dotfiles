# rails-architect Agent Eval

Evaluates the rails-architect agent across three capabilities: **review**, **design**, and **planning**. Uses real classes from crm-web as test fixtures.

## Running the Eval

Each test case is a prompt file. Run them against the agent and score the output.

```bash
# Run a single test case
claude -p "$(cat evals/rails-architect/cases/01-review-controller.md)" --agent rails-architect

# Run all cases (dry-run to see prompts)
for f in evals/rails-architect/cases/*.md; do
  echo "=== $(basename $f) ==="
  claude -p "$(cat $f)" --agent rails-architect
done
```

## Test Cases

| # | File | Capability | Fixture | What It Tests |
|---|------|-----------|---------|---------------|
| 01 | review-controller.md | Review | ContactsController | Fat controller detection, custom action identification, severity accuracy |
| 02 | review-service.md | Review | Meetings::BackfillFromEvents | Service object justification, DRY analysis, boundary assessment |
| 03 | design-feature.md | Design | Contact model | Rails-first approach, abstraction restraint, vertical slice |
| 04 | plan-refactor.md | Plan | Event model | Ordered steps, concern separation, testing plan |
| 05 | design-ambiguous.md | Design | ContactsController | Handling ambiguity, asking vs. assuming, convention knowledge |

## Scoring

Score each output on the rubric in `rubric.md`. Each criterion is 1-3:
- **1** = Missing or wrong
- **2** = Partially correct
- **3** = Excellent

A/B test: run each case against the current agent and the modified agent, score both, compare totals.
