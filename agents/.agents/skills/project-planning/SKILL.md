---
name: project-planning
description: Planning a project — milestone decomposition, build order, dependency and risk sequencing, forecasting. Use whenever work spans multiple milestones or issues and the order, the risk, or the duration is in question.
allowed-tools: Read, Grep, Glob
---

# Project Planning

There is no procedure here — apply the lenses that bear on the question in front of you. The claim
this skill is built on: **a plan's job is to order work so that what you learn early changes what
you do later, and to make its own wrongness detectable.** A schedule is a byproduct. A plan that
can't be falsified isn't a plan, it's a wish with dates attached.

This skill helps after the project has been shaped, and defined.

## The core reframes

Get these four and the rest follows.

- **A plan is a decision-ordering device, not a schedule.** Its value is the order it commits to
  and the claims it makes falsifiable — not the dates it asserts. Judge a plan by what it lets you
  decide now and what it tells you to stop guessing about.
- **Sequence by risk and integration, not by layer or by value.** The first milestone should retire
  the most uncertainty, not deliver the most. The highest-value work is usually the _last_ thing
  that's safe to build, because it rests on everything still unproven.
- **Detail decays with distance.** Plan the near wave in detail and the far wave coarsely — and say
  out loud where the horizon is. Rolling-wave planning isn't vagueness about the future; it's
  refusing to fabricate precision you don't have.
- **Budget when scope is negotiable; forecast when scope is fixed.** These answer different
  questions, and picking the wrong one is the usual failure. _Estimating_ — deriving a number from
  opinion about a task list — is the move to avoid. _Forecasting_ — deriving a range from history —
  is not the same thing. Work out which is actually being asked for.

## What a plan must answer

A plan earns its existence by settling these. Whatever it can't settle yet it should say so
explicitly, rather than fill in.

| The decision it enables        | What the plan states                                                                       | What it must refuse to state yet                |
| ------------------------------ | ------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| Are we agreed on the same job? | The scope boundary — and the out-of-scope list, which does more work than the in-scope one | Solutions for out-of-scope items                |
| What do we start on Monday?    | Milestone 1 in real detail, with its done-ness test                                        | The same detail for milestone 5                 |
| Why this order?                | The dependency rationale, and which edges are real vs. merely convenient                   | An order presented as forced when it was chosen |
| What could kill this?          | The riskiest assumption, and the spike or slice that tests it                              | Confidence that the assumption holds            |
| How long?                      | A range, with the reference class it came from                                             | A single date, or per-task padding              |
| When do we stop and rethink?   | The replan trigger — the observation that would falsify the plan                           | That the plan will hold                         |
| How far ahead is this real?    | The planning horizon, and that past it is deliberately coarse                              | Anything past the horizon in fine grain         |

## Where to go for depth

Don't read these up front. Open the one matching the move you're making.

| You're doing this                                                                                         | Open                        |
| --------------------------------------------------------------------------------------------------------- | --------------------------- |
| Drawing milestone boundaries, working out what depends on what, finding where parallelism actually exists | `references/sequencing.md`  |
| Ordering by risk, mapping assumptions, designing a spike, placing buffer, setting replan triggers         | `references/risk.md`        |
| Answering "how long", building a reference class, choosing between a budget and a forecast                | `references/forecasting.md` |

## Gotchas

The highest-value part of this skill. **Append new failure modes here as you hit them.**

- **Uniform detail across a plan is the tell of a fake plan.** If milestone 6 is specified as
  precisely as milestone 1, that detail was invented rather than derived. State the horizon and
  leave what's past it coarse on purpose.
- **Most dependency edges are false.** "B needs A" is nearly always "B needs _some_ A" — a stub, a
  flag, an abstraction seam. Before accepting a serial order, name the mechanism that would break
  the edge. False edges are what make plans un-parallelizable. → `references/sequencing.md`
- **Parallelism is capped by the dependency graph, not by headcount.** If a plan assumes N
  concurrent streams, check that the graph actually has N independent branches. When it doesn't,
  extra capacity buys coordination cost and nothing else.
- **Ordering by architectural layer is the default, and it defers every integration risk to the
  end.** The thinnest end-to-end path through all the boundaries earns the first slot, even though
  it delivers almost no user value. → `references/sequencing.md`
- **Per-task padding gets eaten; pooled buffer survives.** Safety hidden inside a task is consumed
  by that task. Safety pooled at the end is visible and can be watched burn — which is what makes
  it usable as a signal. → `references/risk.md`
- **The outside view wins even when you know more about this specific project.** Decomposing and
  summing feels rigorous and reliably under-forecasts, because a decomposition can only contain
  what you can already see. Build the reference class from real history before reasoning from the
  task list. → `references/forecasting.md`
- **A spike with no decision attached is unbudgeted work.** Time-box it, name the decision it buys,
  and state which result kills the approach — otherwise it expands and produces a document nobody
  acts on. → `references/risk.md`
- **A plan with no written replan trigger just gets pushed.** Name the falsifying observation in
  advance, or slipping will read as a status update instead of a signal.
