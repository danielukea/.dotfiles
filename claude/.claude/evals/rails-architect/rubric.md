# Scoring Rubric

Score each criterion 1-3. Total possible per case: varies. Compare totals across agent versions.

## Review Cases (01, 02)

| Criterion | 1 (Weak) | 2 (Adequate) | 3 (Excellent) |
|-----------|----------|--------------|---------------|
| **Rails Convention Awareness** | Generic code review, no Rails-specific insight | Mentions Rails conventions but doesn't cite guides or verify | Cites specific Rails conventions, fetches/references guides, names built-in alternatives |
| **Severity Accuracy** | All issues same severity, or critical issues missed | Severity levels present but some misclassified | CRITICAL/HIGH/LOW correctly applied; security issues flagged as critical |
| **Anti-Pattern Detection** | Misses obvious anti-patterns (fat controller, unjustified service) | Finds some anti-patterns but doesn't argue through alternatives | Identifies anti-patterns AND walks through model → concern → service decision tree |
| **Actionability** | Vague suggestions ("consider refactoring") | Specific suggestions but missing test guidance | Specific fix + what tests the change needs + whether existing tests cover it |
| **Restraint** | Suggests unnecessary abstractions or over-engineers | Mostly appropriate but includes some gold-plating | Only suggests changes that are justified; explicitly argues why simpler options don't work |

## Design Cases (03, 05)

| Criterion | 1 (Weak) | 2 (Adequate) | 3 (Excellent) |
|-----------|----------|--------------|---------------|
| **Rails-First Thinking** | Jumps to custom solution without checking built-ins | Mentions Rails built-ins but still recommends custom | Checks Rails built-ins first, only deviates with explicit justification |
| **Vertical Slice** | Only addresses one layer (just model, or just controller) | Covers multiple layers but incomplete path | Full Route → Controller → Model → Test path addressed |
| **Abstraction Level** | Creates unnecessary services/presenters | Appropriate level but doesn't justify the choice | Right level of abstraction with explicit reasoning through alternatives |
| **Lookup Behavior** | Relies entirely on built-in knowledge | Mentions looking things up but doesn't actually do it | Actually uses context7 or WebFetch to verify recommendations |
| **Ambiguity Handling** | Makes assumptions without flagging them | Notes some assumptions | Clearly identifies ambiguities, asks clarifying questions or states assumptions explicitly |

## Planning Cases (04)

| Criterion | 1 (Weak) | 2 (Adequate) | 3 (Excellent) |
|-----------|----------|--------------|---------------|
| **Step Ordering** | Steps have dependency issues or no clear order | Reasonable order but some steps could be reordered | Steps ordered so each builds on the previous; no forward dependencies |
| **Scope Control** | Plan scope creeps beyond the ask | Mostly scoped but includes some unnecessary work | Tightly scoped to the request; explicitly notes what's out of scope |
| **Testing Strategy** | No testing plan | Tests mentioned but not specific | Each step includes what to test and how to verify |
| **Rails Convention Alignment** | Plan introduces non-standard patterns | Mostly conventional but some deviations unaddressed | Every step follows Rails conventions; deviations are justified |
| **Incremental Safety** | Big-bang changes, hard to roll back | Some incremental steps | Each step is independently deployable/revertible |

## Quick Comparison Template

```
Case: _______________
Agent version: [current / modified]

Convention Awareness: _/3
Severity/Abstraction: _/3
Anti-Pattern/Rails-First: _/3
Actionability/Vertical Slice: _/3
Restraint/Lookup: _/3
Total: _/15

Notes:
```
