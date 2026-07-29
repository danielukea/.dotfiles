# Risk ordering

Mechanics for deciding what to do first because of what you don't know, and for making the plan's
failure visible early. Use while producing the plan.

## Assumption mapping

Every plan rests on claims that could be false. Surface them, then sort on two axes: **how much
depends on it** × **how much evidence you have**.

|  | Little evidence | Good evidence |
|---|---|---|
| **Critical to the plan** | **Test this first.** These set the order of the whole project | Proceed; note it as a monitored premise |
| **Not critical** | Cheap to be wrong — note and move on | Ignore |

The top-left quadrant is the only one that changes your sequencing. Name them concretely: not "the
API might be slow" but "the vendor endpoint sustains 50 req/s at p95 under 400ms" — a claim with a
truth value.

Ask of each: **is this truth knowable now, and what's the cheapest way to learn it?** An assumption
that can't be tested before the work isn't a risk to sequence around; it's a risk to mitigate with a
fallback.

## Pre-mortem

Cheap, fast, and better at surfacing what an optimistic read misses. Run it once the plan has a
shape, before committing.

1. State the plan, then assert: *it is six months later and this failed badly.*
2. Each participant independently writes plausible causes of the failure — independently first, so
   the first answer doesn't anchor the rest.
3. Collect, dedupe, and reverse each cause into the assumption it violates.
4. Feed those assumptions back into the map above.

The mechanism is prospective hindsight — asserting the failure as fact licenses reasons that
hedged phrasing suppresses. It reliably surfaces risks that a "what could go wrong?" round does not.

Running solo: adopt distinct perspectives in sequence — the on-call engineer, the person who
inherits this in a year, the customer who hits the edge case — rather than one generic pass.

## Spike design

A spike is a bounded experiment that buys a decision. Without all four parts it's just unbudgeted
work that ends in a document.

- **The question**, phrased so it has a yes/no or a number as its answer.
- **The time-box** — hours or days, fixed before starting.
- **The decision it buys** — name the plan branch that changes based on the result. If the plan is
  the same either way, don't run it.
- **The kill criterion** — what result makes you abandon the approach entirely, decided *before*
  you're invested in it.

Spike output is a decision plus throwaway code, not a report and not a foundation. Code written
under a time-box to answer a question hasn't met the quality bar for code that gets built on;
treating it as a head start is how spike code becomes load-bearing.

## Buffer sizing and placement

Padding every task hides the safety where it gets consumed: work expands to fill the time allowed,
and a task with slack tends not to start until the slack is gone. The safety is spent regardless of
whether the risk materialized, and you can't see it going.

Instead:

1. Size each task at roughly its **50% duration** — the "if things go normally" number, not the
   "I'm confident" number.
2. Pool the stripped safety into a **single project buffer** at the end of the chain.
3. Feed buffers where non-critical paths join the critical path, so upstream variance doesn't
   propagate.
4. **Manage the buffer as the status signal.** Buffer consumed vs. work completed is the real
   progress measure — cheap to compute and hard to argue with.

The counterintuitive part is that the total is often *shorter* than the padded plan, because pooled
safety covers variance across all tasks rather than being stranded inside each one.

## Replan triggers

Write these into the plan. A plan with no falsifying condition gets pushed indefinitely, because
every individual slip looks locally reasonable.

Useful triggers:

- **Buffer burn outpaces progress** — e.g. >50% of buffer consumed at <30% of scope complete. This
  is the single best early signal.
- **A spike returned negative** on a top-left-quadrant assumption. The plan branch it was buying
  now applies; take it rather than re-running the spike.
- **A milestone boundary moved twice.** Once is a correction; twice means the decomposition is
  wrong, not the estimate.
- **A new dependency edge appeared** between work that was planned as parallel. Re-derive the
  critical path — it may have moved.
- **The horizon arrived** — you've reached the point where the coarse far wave needs real detail.
  This one is a scheduled replan, not a failure, and should be in the plan from the start.

State the response, not just the trigger: cut scope, re-sequence, re-forecast, or escalate. A
trigger with no attached action is a metric, not a plan.

## Sources

- Gary Klein, the pre-mortem method — <https://www.gary-klein.com/premortem>
- Assumption testing and mapping — <https://www.producttalk.org/assumption-testing/>
- Goldratt, *Critical Chain* — buffers, student syndrome, Parkinson's law —
  <https://plaky.com/learn/project-management/critical-chain-project-management/>
- Student syndrome in practice —
  <https://www.epicflow.com/blog/student-syndrome-in-project-management-real-constraint-or-just-human-factor/>
