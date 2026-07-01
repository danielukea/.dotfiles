# React Composition — Pattern Reference

Full treatment of each composition pattern. Read the section for the pattern you're designing or reviewing. The parent `SKILL.md` has the decision flow and summaries; this file has complete examples, trade-offs, and pitfalls.

All examples are deliberately framework- and version-agnostic — plain React with hooks and Context. Adapt naming and typing to your project's conventions.

## Table of Contents

- [1. Custom Hooks](#1-custom-hooks)
- [2. Compound Components](#2-compound-components)
- [3. Container / Presentational](#3-container--presentational)
- [4. Render Props](#4-render-props)
- [5. Higher-Order Components](#5-higher-order-components)
- [Choosing between them](#choosing-between-them)

---

## 1. Custom Hooks

**The default mechanism for reusing stateful logic.** A custom hook is a `use`-prefixed function that calls other hooks. It lets multiple components share behavior (state, effects, subscriptions, derived values) without sharing markup and without wrapper components.

### Why hooks over the older patterns

Before hooks, sharing stateful logic meant HOCs or render props — both wrap components, and stacking them produces deeply nested "wrapper hell" that obscures data flow in the tree. Hooks add the behavior *inside* the component instead of wrapping it, so the component tree stays flat and it's clear where each piece of state comes from.

### Anatomy

```tsx
function useKeyPress(targetKey: string) {
  const [pressed, setPressed] = useState(false);

  useEffect(() => {
    const down = (e: KeyboardEvent) => { if (e.key === targetKey) setPressed(true); };
    const up = (e: KeyboardEvent) => { if (e.key === targetKey) setPressed(false); };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
    };
  }, [targetKey]);

  return pressed;
}
```

Any component can now call `useKeyPress("Escape")` instead of re-implementing listener setup/teardown.

### Conventions that age well

- **Name the return shape deliberately.** A tuple `[value, setValue]` mirrors `useState` and reads well for two values. An object `{ items, isLoading, refetch }` is clearer once there are several members or the order isn't obvious. Be consistent within a codebase.
- **Keep hooks focused.** One concern per hook. Compose small hooks rather than building one hook that does everything.
- **Compute derived state; don't sync it.** If a value can be computed from existing state/props, compute it in the body (`const fullName = `${first} ${last}``) instead of storing it in state and updating it from an effect. Effects that only mirror one state into another are a common bug source.
- **Follow the Rules of Hooks.** Call hooks only at the top level (never in conditionals/loops) and only from React functions or other hooks. A lint rule should enforce this.
- **Encapsulate subscriptions in named hooks.** A websocket/event subscription that must reconnect when an input changes belongs in a purpose-named hook (`useChannelSubscription(id)`) with the changing input in its dependency list — not a bare effect in a component.

### Pitfalls

- Over-eager `useMemo`/`useCallback` everywhere adds noise; reach for them when a referential identity actually matters (dependency arrays, memoized children), not reflexively.
- A hook that takes ten arguments and returns fifteen values is usually two or three hooks wearing a trenchcoat.

---

## 2. Compound Components

**For a set of components that belong together and coordinate shared state** — tabs, dropdowns, menus, accordions, selects, steppers. The parent owns the state and exposes it through Context; the children read it. Consumers compose the pieces declaratively without wiring state between them.

### Context + static properties

```tsx
const FlyOutContext = createContext<{ open: boolean; toggle: () => void } | null>(null);

function useFlyOut() {
  const ctx = useContext(FlyOutContext);
  if (!ctx) throw new Error("FlyOut.* must be used inside <FlyOut>");
  return ctx;
}

function FlyOut({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const value = useMemo(() => ({ open, toggle: () => setOpen(o => !o) }), [open]);
  return <FlyOutContext.Provider value={value}>{children}</FlyOutContext.Provider>;
}

function Toggle() {
  const { toggle } = useFlyOut();
  return <button onClick={toggle}><Icon /></button>;
}

function List({ children }: { children: React.ReactNode }) {
  const { open } = useFlyOut();
  return open ? <ul>{children}</ul> : null;
}

FlyOut.Toggle = Toggle;
FlyOut.List = List;
FlyOut.Item = ({ children }: { children: React.ReactNode }) => <li>{children}</li>;
```

Usage — one import, declarative composition, zero state management at the call site:

```tsx
<FlyOut>
  <FlyOut.Toggle />
  <FlyOut.List>
    <FlyOut.Item>Edit</FlyOut.Item>
    <FlyOut.Item>Delete</FlyOut.Item>
  </FlyOut.List>
</FlyOut>
```

### Key rules

- **Memoize the Context value** (`useMemo`) so children don't re-render every time the provider's parent renders.
- **Throw a clear error** when a sub-component is used outside its provider — it turns a confusing null into an obvious message.
- **Prefer Context over `React.Children.map` + `cloneElement`.** Cloning only reaches *direct* children (so you can't wrap a sub-component in a `<div>`), and it shallow-merges props, risking silent collisions. Context has neither limitation.
- For reusable libraries, a **factory** (`createTabs<T>()` returning `{ Provider, List, Trigger, Panel, useTabs }`) gives fully-typed, independently-scoped instances.

### When not to use it

If the sub-components don't actually share state, the Context machinery is overhead — a single component with props (or plain composition via `children`) is clearer.

---

## 3. Container / Presentational

**Separation of concerns between "what data" and "how it looks."**

- **Presentational** components care how things look. They receive data via props and render it — ideally pure functions, no fetching, no business logic. They're easy to reuse and trivially testable (pass props, assert output, no mocking).
- **Container** components care what data is shown — they fetch/derive it and hand it to presentational components.

### Prefer a hook for the "container" half

In modern React the data concern is best expressed as a **custom hook**, not a wrapper component. Same separation, one fewer layer:

```tsx
function useDogImages() {
  const [dogs, setDogs] = useState<string[]>([]);
  useEffect(() => {
    let cancelled = false;
    fetchDogImages().then(images => { if (!cancelled) setDogs(images); });
    return () => { cancelled = true; };
  }, []);
  return dogs;
}

// Presentational component calls the hook directly — no container wrapper needed.
function DogImages() {
  const dogs = useDogImages();
  return <div>{dogs.map(src => <img key={src} src={src} alt="dog" />)}</div>;
}
```

(In a real codebase, replace the raw `fetch`/effect with your project's data-fetching convention.)

### Treat it as a mindset

The lasting value isn't the literal two-component split — it's the discipline of keeping views pure and prop-driven. A pure view that takes data in and renders it out is reusable, designer-friendly, and testable regardless of how the data arrives. Reach for an explicit container only when it genuinely clarifies a complex screen.

---

## 4. Render Props

**Share behavior while letting the consumer control the surrounding markup.** A component owns some state or behavior and calls a function prop (commonly `children`) with that data; the consumer returns the JSX.

### Children-as-a-function (preferred form)

```tsx
function Input({ children }: { children: (value: string) => React.ReactNode }) {
  const [value, setValue] = useState("");
  return (
    <>
      <input value={value} onChange={e => setValue(e.target.value)} />
      {children(value)}
    </>
  );
}

// Consumer decides what to render with the shared value:
<Input>
  {value => (
    <>
      <Kelvin value={value} />
      <Fahrenheit value={value} />
    </>
  )}
</Input>
```

### Why and when

- **Explicit data flow.** Unlike HOCs, the data arrives as a visible function argument — no hidden injected props, no name collisions.
- **Good fit** when a component owns state/behavior but should not dictate the markup around it: a virtualized list that owns windowing but lets you render each item; a "downloader" that owns progress but lets you render the UI.

### Cons

- Deep nesting of multiple render-prop components recreates the wrapper-hell problem. If you're stacking them, a hook is almost always cleaner.
- A render prop can't carry its own lifecycle for the consumer; it only hands over data.

Most logic-sharing that once used render props is now better served by a hook. Keep render props for the genuine "you control the markup, I'll supply the data" cases.

---

## 5. Higher-Order Components

**A function that takes a component and returns an enhanced one.** Historically the way to apply shared, cross-cutting behavior (auth gating, layout, logging, injected data) to many components.

```tsx
function withStyles<P extends { style?: React.CSSProperties }>(Component: React.ComponentType<P>) {
  return (props: P) => {
    const style = { padding: "0.2rem", margin: "1rem", ...props.style }; // merge, don't clobber
    return <Component {...props} style={style} />;
  };
}
```

### Best fit

- The **same, uncustomized** behavior is needed by **many unrelated** components, *and*
- Each component must still work standalone without the behavior.

### Pitfalls (why hooks usually win now)

- **Prop collisions.** An HOC that injects `style`/`data`/etc. can silently overwrite a prop the component already had. Always merge or namespace injected props.
- **Wrapper hell.** Composing several HOCs (`withAuth(withLayout(withLogging(Component)))`) deepens the tree and makes it hard to tell which wrapper supplies which prop. Order matters and refactors get fragile.
- Most cross-cutting behavior is cleaner as a hook called *inside* the component — no wrapping, explicit at the call site.

Reach for an HOC only when the "same behavior, many components, must work standalone" trifecta genuinely holds (e.g., a blanket `withErrorBoundary`). Otherwise prefer a hook.

---

## Choosing between them

A practical ordering when you catch yourself about to share logic or structure an API:

1. **Can a custom hook do it?** Usually yes. Start here.
2. **Is this a coordinated set of sub-components?** Compound components (Context + static properties).
3. **Do I just need pure, reusable views?** Keep the view presentational; put data in a hook.
4. **Must the consumer own the surrounding markup?** Render props / children-as-function.
5. **Same uncustomized behavior across many standalone components?** HOC.

Each step down adds indirection. Justify it against the simpler option above — "a hook won't work here because…". If you can't finish that sentence, use the hook.
