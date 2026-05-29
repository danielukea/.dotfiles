# Stack Adapter: React + TypeScript

Patterns and signals specific to React/TS frontends. Loaded by every lens
once the stack is detected.

## Coupling traps

- **Prop drilling**: a value passed through 4+ component layers without
  being used by intermediate layers. Almost always a missed context, hook,
  or compound-component opportunity.
- **Context fan-out**: one Provider whose value contains 20+ unrelated
  fields, consumed by half the tree. Every change re-renders everything.
  Split into multiple narrower Providers.
- **Barrel files** (`index.ts` re-exporting everything) that create hidden
  coupling — consumers can't tell which symbol depends on which submodule.
  Acceptable as a *slice's public surface*; problematic as accidental
  internal re-exports.
- **Cross-feature deep imports**: `import { stuff } from 'features/billing/utils/internal/calc'`
  reaches into another slice's internals. Fix at the import-rule level
  (`eslint-plugin-boundaries`, `import/no-restricted-paths`).

## Complexity hotspots

```bash
fta-cli analyze .                                  # Fast TypeScript Analyzer
scc --by-file --sort complexity src/ --format json | jq '.[].Files | sort_by(-.Complexity) | .[0:20]'
npx knip                                           # unused exports, files, deps
npx ts-prune                                       # dead exports
npx type-coverage --detail                         # % of code with explicit types
```

Run Jest with coverage if not present, then feed `coverage/coverage-summary.json`
to the StinkScore harness:

```bash
yarn jest --coverage --coverageReporters=json-summary
```

## Extensibility traps

### Monolithic components
A 600-line `Dashboard.tsx` mixing data fetching, derived state, formatting,
and JSX is the React equivalent of a god class. The fix is the **headless
pattern**: extract logic into a hook (`useDashboard`), context, or
controller; the component becomes thin and replaceable.

### Missing headless seams
The user's `headless-component-designer` skill enforces this for new code.
For existing code, look for:
- `useState` + `useEffect` clusters in the component body that should be a
  custom hook
- `if (loading)` / `if (error)` ladders in render that should be at the
  hook level
- Form state mixed with form rendering (use react-hook-form / a wizard hook)

### Untyped boundaries
`any`, `unknown`, `as` casts at module entry/exit. Each is a contract
breakdown. `type-coverage --detail` lists them.

### Inline conditional rendering on type
`{user.kind === 'pro' ? <ProBadge /> : user.kind === 'enterprise' ? ...}`
— the same `case`-on-type lives in 8 components. The fix is a
`UserBadge` component or a render-prop / compound pattern.

### TanStack Query / SWR cache-key anarchy
Cache keys hard-coded inline (`useQuery(['users', id], …)`) duplicated
across dozens of components → renaming the entity breaks invalidation
everywhere. Centralize in `queryKeys.users.byId(id)` factories.

### Untyped `onChange` and event payloads
`(e: any) => …` is a type contract surrendered. Catch with
`type-coverage --strict`.

## Vertical slicing in React/TS

### Feature-folder colocation
Each feature owns its slice:

```
src/features/billing/
  index.ts          ← public API
  components/
  hooks/
  queries/
  types.ts
  __tests__/
```

`index.ts` is the *only* entry point other slices import. Internals
(`hooks/`, `queries/`) are private.

### Boundary enforcement
Two ESLint mechanisms:

```js
// eslint.config.js — features/*/index.ts is public; other paths are private
{
  files: ['src/features/**/!(index).ts*'],
  rules: {
    'import/no-restricted-paths': ['error', {
      zones: [{ target: './src/features/*', from: './src/features/*' }]
    }]
  }
}
```

Or `eslint-plugin-boundaries` for a more declarative approach.

Presence of either is a strong slicing signal. Absence + 30+ feature
folders is a strong "implicit slicing only" finding.

### Direction inversion
Domain-shaped feature folders (`billing/`, `notifications/`) should not
import from each other. They may all import from a shared infrastructure
slice (`lib/`, `shared/`). Cross-feature imports are findings.

### Composition patterns to recommend
The user's existing skills cover the design choices:
- `react-composition` — hooks, compound components, render props, HOCs, and view/logic separation
- `headless-component-designer` — the workflow that enforces all of above

The findings should *cite these by name* rather than re-explaining the
patterns inline.

## Contract surface

- **Component props**: type definitions for props are the contract; missing
  types are missing contracts.
- **Context value shapes**: same.
- **Public hooks**: their return shape is a contract; renames are breaking.
- **API client types**: `types.ts` mirroring backend serializers — is
  there a sync mechanism (codegen, tRPC, GraphQL) or manual drift?
- **Route definitions** (React Router): each path is a public surface for
  deep-linking.

## Variation points

### Healthy
- Strategy components selected by prop (`<Renderer kind={…} />`)
- Hook-based variation (`useVariant(experimentKey)`)
- Compound components with slot replacement
- Theme tokens / CSS variables
- LaunchDarkly / Statsig / GrowthBook flags

### Dirty
- `if (kind === 'a') ... else if (kind === 'b') ...` chains in JSX
- `process.env.NODE_ENV` checks inside components
- Near-duplicate components (`UserCardV2`, `UserCardLegacy`)
- Stale flags

## Tools to probe for

```bash
which fta-cli ts-prune knip madge depcruise jscpd
yarn list type-coverage 2>/dev/null
test -f .eslintrc.js && grep -l 'no-restricted-paths\|boundaries' .eslintrc.* eslint.config.*
```
