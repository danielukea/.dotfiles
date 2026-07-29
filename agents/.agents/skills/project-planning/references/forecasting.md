# Forecasting

Mechanics for answering "how long" without inventing a number. Use when a duration or date is
actually required — not by default.

## First: budget or forecast?

They answer different questions. Picking the wrong one produces a number nobody should act on.

| | **Budget** | **Forecast** |
|---|---|---|
| Fixed | The time | The scope |
| Flexes | The scope | The date |
| The question | "What can we get for six weeks?" | "When does this fixed scope land?" |
| Produced by | A decision about worth | Historical throughput |
| Right when | Scope is negotiable and value is bounded | Scope is externally fixed — a contract, a migration, a deprecation deadline |

Most product work should be budgeted, not forecast. Reach for a forecast when the scope genuinely
can't flex.

Note which one "don't estimate" arguments are actually aimed at: the opinion-derived number, not the
history-derived range. Refusing to estimate is not a reason to refuse to forecast.

## The outside view, made mechanical

Decomposing work and summing the parts is the inside view. It feels rigorous and reliably
under-forecasts, because a decomposition can only contain work you can already see — and the
unseen work is exactly what causes overruns. Large-project research finds systematic overruns in
this direction across every project type studied, including software.

The correction is a **reference class**: find comparable completed work and use its actual
distribution. This is executable against your own history, so do that before reasoning from a task
list.

1. **Define the class.** "Projects in this repo that touched N subsystems and shipped a schema
   change" — narrow enough to be comparable, broad enough to have members. Aim for 5+.
2. **Pull the actuals from history.** First commit on the branch to merge; issue created to issue
   closed; the tracker's own cycle-time data if it has any.
   ```sh
   # calendar days from a merge commit back to the branch's first commit
   git log --merges --format='%H %cI %s' --since='18 months ago'
   git log --format='%cI' <first-commit>..<merge-commit> | tail -1
   ```
3. **Look at the distribution, not the mean.** Report the range and where the current work sits in
   it. The spread between the 50th and 85th percentile is the honest uncertainty.
4. **Adjust only for named, specific differences** — and adjust the *class*, not the number. "This
   one also needs a data backfill, so use the subset that had backfills." Applying a gut multiplier
   to a reference-class number reintroduces exactly the bias the class removed.

When no reference class exists, say so and forecast a wide range. That's more useful than a
confident narrow one, and it's an argument for the first milestone being a walking skeleton that
*creates* a data point.

## The shape of the answer

Uncertainty is widest at the start and narrows only as work is actually done — the cone of
uncertainty. A point estimate is therefore the wrong shape for the answer at the moment it's usually
demanded.

Prefer, in order:

1. **A probabilistic range** — "75% by mid-October, 95% by mid-November." Throughput-based Monte
   Carlo gets here from a completed-items count and needs no estimates at all: sample historical
   throughput repeatedly, count how many samples finish the remaining items by each date.
2. **Three-point** — optimistic / likely / pessimistic, reported as all three. Never collapsed to a
   weighted single number, which throws away the only useful information in it.
3. **A single date** — only when a date is contractually required, and then always as the
   pessimistic end, never the likely one.

State the confidence level with the date. "October 22" and "75% by October 22" get treated
identically by the speaker and completely differently by the listener.

## Decay and recalibration

A forecast is a measurement of a moment, and its inputs go stale:

- **Re-forecast at every milestone boundary.** Completed milestones are new members of your
  reference class — the best data you'll get, and specific to this project.
- **A resolved spike invalidates the forecast it preceded.** The spike existed because a variable
  was unknown; once known, the old range is stale in both directions.
- **Never carry forward a pre-decomposition number.** The first forecast made before the dependency
  graph existed is the least informed one you'll ever produce, and it is the one most likely to be
  quoted back.
- **Track forecast vs. actual per milestone.** This is how a reference class gets built at all —
  without it, every project starts from the inside view again.

## Sources

- Flyvbjerg on reference-class forecasting and optimism bias —
  <https://www.pmi.org/learning/library/nobel-project-management-reference-class-forecasting-8068>
- Kahneman's inside vs. outside view — <https://corporate.jasoncollins.blog/outside-view>
- Boehm/McConnell, the cone of uncertainty —
  <https://www.teamretro.com/guides/agile-estimation-guide/cone-of-uncertainty/>
- Estimating vs. forecasting; the #NoEstimates distinction —
  <https://a4al6a.substack.com/p/the-honest-estimation-problem-why>
- Throughput-based Monte Carlo forecasting —
  <https://www.scrum.org/resources/blog/monte-carlo-forecasting-scrum>
- Rolling-wave planning / progressive elaboration —
  <https://en.wikipedia.org/wiki/Rolling-wave_planning>
