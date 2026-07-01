---
name: react-composition
description: Generic, framework-agnostic React composition patterns for reusing logic and structuring component APIs — custom hooks, compound components, container/presentational separation, render props, and higher-order components. Use this whenever designing or refactoring React components, hooks, or contexts; deciding HOW to share stateful logic across components; building related component sets (tabs, menus, dropdowns, accordions, steppers); designing a reusable component API; or reviewing whether a component's composition is sound — even if the user doesn't name a specific pattern. Covers WHICH pattern to reach for and why. Does not cover version-specific React APIs or any particular data-fetching/UI library.
license: MIT
metadata:
  author: consolidated from patterns.dev
  version: "1.0"
---

# React Composition

How to share behavior and structure component APIs in React. These patterns are durable — they're about *where logic lives* and *how pieces fit together*, not about any React version's syntax or any specific library. They apply equally in any React codebase.

The guiding principle: **start with behavior, not markup, and compose over configure.** A component's logic (state, effects, handlers) is separable from how it looks. Get the logic boundary right first; the rendering is the easy part.

## The one decision that matters

Most "which pattern?" questions reduce to *how should this logic be shared?* Work down this list and stop at the first that fits — each later option adds indirection you must justify:

| Situation | Reach for | Why |
|-----------|-----------|-----|
| Reuse stateful logic across components | **Custom hook** | The modern default — no wrapper nesting, logic is plain functions |
| A set of components that coordinate shared state (tabs, menu, accordion) | **Compound components** (Context + static sub-components) | Clean API, implicit state sharing, no prop drilling |
| Separate "what data" from "how it looks" | **Container/presentational** — but prefer a **hook** for the data half | Testable pure views; hooks remove the wrapper layer |
| Consumer must control the markup that surrounds shared data | **Render props** (or children-as-function) | Explicit data hand-off, no prop-name collisions |
| The *same uncustomized* behavior must wrap *many unrelated* components | **HOC** | One place for cross-cutting logic — but a hook is usually simpler |

**Default to hooks.** HOCs and render props predate hooks and solved the same logic-reuse problem with wrapper nesting ("wrapper hell"). They remain useful in the narrow cases above, but if a custom hook does the job, use it.

## Composition over configuration

Before sharing logic, notice when a component is accreting *configuration* instead of being *composed*. Boolean-prop accumulation is the smell: four booleans is sixteen states, most untested.

```tsx
// Configuration — combinatorial, opaque
<Card showHeader showFooter collapsible bordered withShadow headerAction="close" />

// Composition — explicit, each piece optional and testable
<Card>
  <Card.Header><Card.CloseButton /></Card.Header>
  <Card.Body collapsible>…</Card.Body>
  <Card.Footer>…</Card.Footer>
</Card>
```

When a component has distinct *modes* (dialog vs. drawer, video vs. image), prefer explicit variant components over a `type` prop with branches — each variant takes exactly the props it needs and no impossible states exist.

## The patterns, briefly

Each is treated in full in `references/patterns.md` (read it when designing or reviewing a specific pattern — it has complete examples, pros/cons, and pitfalls). Summaries:

### Custom hooks — the default for logic reuse
Extract stateful logic into a `use`-prefixed function so multiple components share behavior without sharing markup. Follow the Rules of Hooks (call only at the top level, only from React functions). Keep hooks focused; name the return shape deliberately — a tuple `[value, actions]` for symmetry with `useState`, an object `{ state, handlers }` when there are many members. Compute derived values directly in the body rather than syncing them with an effect.

### Compound components — coordinated sets
For components that belong together and share state (tabs, dropdowns, menus, accordions), hold the state in a parent, share it via Context, and attach the children as static properties (`Tabs.List`, `Tabs.Trigger`, `Tabs.Panel`). Consumers compose the pieces; the shared state stays implicit. Memoize the context value so children don't re-render on unrelated parent updates. Prefer Context over `React.Children.map`+`cloneElement`, which only reaches direct children and can collide on prop names.

### Container / presentational — separate logic from view
Keep presentational components pure: they receive data through props and render it without owning fetching or business logic. Put the "what data" concern elsewhere. In modern React that elsewhere is almost always a **custom hook**, not a wrapper container component — the hook gives the same separation with no extra layer. Reach for this as a *mindset* (pure, prop-driven views are reusable and trivially testable) more than as a literal two-component split.

### Render props — consumer controls the markup
Pass a function (often `children`) that receives data and returns JSX. Useful when a component owns some state/behavior but the consumer must decide what to render around it (e.g., a list that owns selection but lets you render each row). Explicit data flow avoids HOC prop collisions. Avoid stacking render props deeply — that nesting is itself a smell; a hook is usually cleaner.

### Higher-order components — wrap many with the same behavior
A function that takes a component and returns an enhanced one. Justified when the *same, uncustomized* behavior applies to *many unrelated* components and each must still work standalone. Merge (don't clobber) incoming props to avoid collisions, and remember composition order matters. In new code, reach for a hook first — HOCs create the wrapper nesting hooks were designed to remove.

## Keep it durable

This skill intentionally avoids React-version-specific APIs, build tools, and named data-fetching or UI libraries — those churn and rot a pattern guide fast. Keep additions at the level of *composition reasoning* (where logic lives, how pieces fit) so the guidance stays true across versions and projects. Library- and codebase-specific conventions belong in project rules or the relevant project skill, not here.

## When reviewing composition

- Is reusable logic in a hook, or duplicated/trapped in components?
- Boolean-prop accumulation that should be composition or variant components?
- Compound sets sharing state through Context with a memoized value — or prop-drilling?
- Presentational components kept pure (no fetching/business logic in the view)?
- HOC/render-props nesting that a hook would flatten?
- Hook return shapes named and consistent; derived state computed, not effect-synced?
