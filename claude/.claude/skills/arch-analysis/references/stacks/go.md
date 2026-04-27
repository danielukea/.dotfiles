# Stack Adapter: Go

## Coupling traps

- Importing from `cmd/` (application code) in library packages
- `internal/` packages leaking through interface gymnastics
- Package-level `init()` functions creating hidden coupling
- Excessive `interface{}` / `any` parameters

## Complexity hotspots

```bash
gocyclo -over 10 .                          # cyclomatic complexity
staticcheck ./...                           # advanced static analysis
go test -coverprofile=cover.out ./...       # for StinkScore harness
go tool cover -func=cover.out
scc --by-file --sort complexity .
```

## Extensibility traps

- Files with many `if err != nil` blocks obscuring the happy path
- Package-level variables mutated by multiple functions
- HTTP handlers doing business logic instead of delegating
- Hand-rolled type switches (`switch v := x.(type)`) repeated across files
- Concrete dependencies imported directly instead of accepting interfaces

## Vertical slicing

- `cmd/` for entry points, `internal/` for private packages, `pkg/` for
  public APIs
- Each domain in its own package; depend inward via interfaces
- `internal/<feature>/` is a natural slice boundary
- Direction enforcement via `go-arch-lint` or manual review

## Tools to probe for

```bash
which gocyclo staticcheck golangci-lint
```
