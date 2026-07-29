# Sequencing

Mechanics for turning a known body of work into an ordered set of milestones. Use while producing
the plan.

## Milestone boundary tests

A boundary is right when it passes all four. Most proposed boundaries fail the second and third.

1. **Stop test.** If the project were cancelled the moment this milestone landed, is the system in a
   coherent, defensible state? A boundary that leaves things half-migrated is a checkpoint, not a
   milestone.
2. **Demo test.** Can you show it to someone who doesn't know the codebase? "The service layer is
   done" fails. Not every milestone must be user-visible, but it must be *observable* — a passing
   end-to-end test, a working admin screen, a real request served.
3. **Decision test.** What does landing this let you decide that you couldn't before? If nothing,
   the milestone is bookkeeping and probably belongs merged into its neighbour.
4. **Reversal test.** Can you roll it back without unwinding later milestones? If not, it's coupled
   to work that hasn't happened yet, and the boundary is in the wrong place.

Grain heuristic: a milestone that decomposes into fewer than ~3 issues is really an issue; one that
needs more than ~10 is hiding a boundary inside itself.

## Building the dependency graph

1. List the units of work at issue grain — one deliverable each, verb-first.
2. For each pair, ask only: **can B start before A lands?** Not "should" — *can*. Write the edge
   only when the answer is genuinely no.
3. Topologically sort. The result is your candidate order and its layers are your parallelism
   ceiling.
4. Find the longest path — the critical path. Its length is the floor on duration no amount of
   capacity reduces. Shortening the project means shortening *that* path, nothing else.
5. Mark work that is off the critical path. That's where slack lives and where extra capacity can
   actually be applied.

Record the graph in the plan, not just the ordering. An order without its graph loses the *why*, and
the first schedule pressure will reshuffle it arbitrarily.

## Interrogating edges

Assume every edge is guilty. For each one, ask which mechanism breaks it:

| Claimed dependency | Mechanism that breaks it |
|---|---|
| "UI needs the real API" | Stub or fixture at the boundary; contract agreed first, both sides built against it |
| "Can't ship until the whole flow works" | Feature flag — deploy dark, release later. Deploy is not release |
| "Schema must change before the code" | Expand/contract (parallel change): add new alongside old, migrate readers, then drop old. Three small safe steps instead of one coupled one |
| "Can't replace the old subsystem incrementally" | Branch by abstraction — introduce a seam, run both behind it, move traffic, delete the loser |
| "Needs the refactor first" | Do the refactor *within* the first milestone that requires it, not as its own prerequisite milestone. Standalone refactor milestones fail the demo and decision tests |
| "Needs the data migrated" | Backfill behind a flag with dual-write; the migration becomes a background task, not a gate |

An edge that survives all of these is real. Note in the plan which edges you broke and how — that's
the difference between a sequence you chose and one you were forced into.

## Vertical over horizontal

Horizontal slicing (all models → all controllers → all views) is the default an agent falls into
because it matches how code is organized. It defers every integration risk to the end, where a fixed
budget can't absorb it.

The alternative is a **walking skeleton** (also called a tracer bullet or thin thread): the thinnest
possible end-to-end path that touches every architectural boundary and integration point, built to
production quality but with almost no functionality. One request, entering at the real edge, hitting
the real persistence, deployed by the real pipeline.

It earns the first milestone slot because it converts the largest class of unknown-unknowns —
"do these pieces actually connect?" — into known facts before anything is built on top. Its
done-ness test is the deployment, not the feature.

After the skeleton, each subsequent slice thickens one path end-to-end rather than completing one
layer across all paths.

## Parallelism limits

The graph gives the ceiling; coordination cost lowers it. Communication paths grow as
*n(n−1)/2*, and onboarding cost lands exactly when there's no slack to absorb it — which is why
adding capacity to a late project makes it later rather than merely failing to help.

Practical reading: before planning N parallel streams, confirm the graph has N branches that share
no files and no in-flight interfaces. Two streams editing the same seam are one stream with a merge
tax.

## Sources

- Alistair Cockburn, *walking skeleton*; Hunt & Thomas, *tracer bullets* —
  <https://distilledpatterns.org/patterns/walking-skeleton/>
- Pete Hodgson, "Expand/Contract: making a breaking change without a big bang" —
  <https://blog.thepete.net/blog/2023/12/05/expand/contract-making-a-breaking-change-without-a-big-bang/>
- "Deployment is not a release" — <https://www.flagsmith.com/blog/deployment-is-not-a-release>
- Brooks's law — <https://en.wikipedia.org/wiki/Brooks's_law>
