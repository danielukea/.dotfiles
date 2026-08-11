# Descriptions — the trigger

The `description` frontmatter is how a skill gets *selected*. It's the signal an agent
matches against the work in front of it — not a summary of the contents. Write it for the
model, not for a human reader.

A vague description means the skill never fires. A bloated one taxes every turn.

## A description is a detectable condition, not a table of contents

Spend it on **what state of the work makes this skill relevant**, then stop.

> How Rails is written - trigger on any Ruby/Rails question: models, controllers, jobs,
> queries, service objects, where behavior belongs, version gotchas. _(~38 tokens)_

Two things to keep out:

- **Contents summaries.** Re-listing the body's sections ("covers X, Y, and Z, with a
  worked example") gives the selector nothing to match on. The body is already there for
  the agent that loads it.
- **Quoted phrase lists.** `Use when the user says "plan this project", "break this into
  milestones"…` narrows the trigger to the wordings you happened to imagine, and costs
  more tokens than the condition it approximates. A condition generalizes; a phrase list
  doesn't.

Name a literal phrase only when it's a term of art the condition can't imply — `"NRQL"`,
`"Canon TDD"`, a CLI's name.

## Budget: 30–40 tokens

`name` + `description` load on *every* turn for *every* installed skill, so length is a
shared, recurring cost. The ladder `scripts/validate_skill.sh` reports:

| ~Tokens | Verdict                                      |
| ------- | -------------------------------------------- |
| ≤ 40    | The target. Most conditions fit in 30–40.    |
| 40–60   | Over ideal — fine if every clause does work. |
| > 60    | WARN: trim.                                  |
| > 120   | FAIL: hard ceiling.                          |

Price a candidate before it goes in the file — no need to edit-then-check:

```sh
scripts/validate_skill.sh --description "How Rails is written - trigger whenever …"
```

The fix for under-triggering is almost never "add words." It's a **sharper condition**.
Padding to be pushy trades a real per-turn cost for a gain phrasing usually gets for free.

## Domain nouns beat verbs — a doctrine skill needs a matchable surface

For a taste-and-convention skill, selection turns on "do I need help here?", not "is this the
topic?" The model believes it already knows Rails, so more *verbs* for the work ("writing,
reviewing, refactoring…") don't move it. The nouns a question actually contains do.

Measured on `rails` (2026-08-11; 10 in-scope + 10 near-miss queries, one project root per run,
4–5 runs each, Sonnet). Recall / false-trigger rate:

| Description | ~Tokens | Recall | FT |
| ----------- | ------- | ------ | -- |
| gated on "planning **a feature**" | 24 | 66% | 0% |
| verbs widened (writing/reviewing/refactoring/debugging) | 38 | 73% | 0% |
| no nouns, just "any Ruby/Rails question" | 25 | 82% | 2% |
| **domain nouns** (models, controllers, jobs, queries, service objects…) | 38 | 84% | 0% |
| positions + "House conventions" + "consult before answering from memory" | 39 | 98% | 0% |

Two things to take from it. **"A feature" was a real gate** — that one word cost ~18 points
against the same tokens spent on nouns. And the 98% row is *unexplained*: it stacked owned
framing, the skill's positions, and a direct instruction, and the ingredients were never
isolated, so don't cargo-cult it. It also restates the body's positions, which the top of this
file rules out on cost grounds.

Worth knowing why the gap exists at all: left to itself the model answered a fat-controller
query by recommending a service object — exactly what the skill argues against.

## Trim order (when you're over budget)

Cut in this order and stop as soon as you're under:

1. Contents summary — what the skill *covers*, as opposed to when it applies.
2. Near-duplicate triggers. Redundancy is per-*axis*, not per-phrase: "create a ticket"
   and "turn this into a ticket" teach the selector the same thing.
3. Connective prose ("Also trigger on…", "Use whenever the user asks about…").
4. Parentheticals that repeat what the condition already implies.

## Overlap is fine

Two skills firing on one request is a good outcome, not a collision — the agent reads both
and picks. Don't design around peer collision, and don't write reciprocal pointers into a
neighbor's body.

A `Not for: <case> — use <sibling>` pointer earns its tokens only against a **genuine
trap**: a sibling that would confidently do the wrong thing on the same request. For an
ordinary neighbor, omit it — the pointer costs every turn, narrows triggering, and dangles
when the sibling is renamed or pruned.

Before writing one, check the sibling can even fire: a skill with
`disable-model-invocation: true` only runs when the user invokes it by name, so no pointer
is protecting anything. (This skill's old `Not for: pruning skills — use skill-prune`
guarded exactly that non-collision.)

Cheaper than any pointer: a **name that can't be misread** — `code-design-principles`, not
`design-principles`. See `principles.md` → Naming tracks scope.

## One more example

A proactive skill, ~50 tokens (`llm-wiki`). The condition is "would background context
help" — no phrase list, and the read-only scope limit is part of the trigger:

> Surface background context from the user's personal wiki (~/Workspace/notes) —
> decisions, people, projects, history — whenever broader context would help, not just
> when explicitly asked. Read-only.
