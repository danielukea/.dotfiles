# Stack Adapter: Python

## Coupling traps

- `__init__.py` files that import everything (lazy-loading gone wrong)
- Circular imports resolved via import-inside-function hacks
- `from x import *` hiding the actual dependency surface
- Mixed abstraction levels in the same package (a `utils.py` that imports
  the whole framework)

## Complexity hotspots

```bash
radon cc -s --json src/                    # cyclomatic complexity
radon mi -s src/                           # maintainability index
vulture src/                               # dead code
deptry src/                                # unused/missing deps
coverage json                              # for StinkScore harness
```

## Extensibility traps

- Classes with 20+ methods (god class)
- Mixins stacked 4+ deep
- Module-level mutable state
- `if isinstance(x, …)` branches instead of polymorphism
- I/O mixed with business logic in the same function

## Vertical slicing

- Package-by-feature vs package-by-layer in `src/`
- `__all__` declarations as the public surface
- Namespace packages for slicing larger codebases
- Direction enforcement via `import-linter` contracts

## Tools to probe for

```bash
which radon vulture deptry pylint mypy ruff
```
