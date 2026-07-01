# Stack Adapter: Rust

## Coupling traps

- `pub` used too liberally (effectively no encapsulation)
- Feature flags creating conditional coupling
- `use super::*` / `use crate::*` pulling in too much
- Trait objects (`Box<dyn Trait>`) used where generics would document
  intent better, or vice versa

## Complexity hotspots

```bash
scc --by-file --sort complexity --format json .
cargo tarpaulin --out Json                  # for StinkScore harness
cargo clippy -- -D clippy::cognitive_complexity
cargo udeps                                 # unused deps (nightly)
cargo-depgraph --workspace-only             # crate dep graph
```

## Extensibility traps

- Files with deep `match` nesting
- `unsafe` blocks in frequently changed code (high-risk hotspot)
- Generic-heavy modules with poor type-level documentation
- Builder patterns where 4+ required fields are stringly typed

## Vertical slicing

- Workspace crates as the natural slice boundary
- `mod` hierarchy inside a crate as the secondary boundary
- `pub(crate)` / `pub(super)` for explicit visibility direction
- Direction enforcement via `cargo-modules` or manual review

## Tools to probe for

```bash
which cargo-tarpaulin cargo-depgraph cargo-udeps
```
