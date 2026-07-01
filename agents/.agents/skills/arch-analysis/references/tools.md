# Recommended CLI Tools

Optional tools that enrich the analysis with quantitative data. The skill works
without any of them — agents fall back to grep/glob/read analysis.

## Polyglot (install these first)

| Tool | Install | What it adds |
|------|---------|-------------|
| **scc** | `brew install scc` | LOC + complexity per file, 200+ languages |
| **ast-grep** | `brew install ast-grep` | Structural code search using AST patterns |
| **jscpd** | `npm i -g jscpd` | Copy-paste detection, 150+ languages, JSON output |
| **semgrep** | `brew install semgrep` | Pattern-based static analysis, 30+ languages |
| **dep-tree** | `go install github.com/gabotechs/dep-tree@latest` | Dependency graphs + entropy score |

## Git analysis

| Tool | Install | What it adds |
|------|---------|-------------|
| **mergestat** | `brew install mergestat/tap/mergestat` | SQL queries on git history |
| **code-maat** | Java JAR from [GitHub](https://github.com/adamtornhill/code-maat) | Behavioral analysis: hotspots, temporal coupling, ownership |
| **git-quick-stats** | `brew install git-quick-stats` | Quick contributor and churn stats |

## Language-specific

### Ruby
| Tool | Install | Lens |
|------|---------|------|
| **skunk** | `gem install skunk` | StinkScore: complexity × (1 - coverage). Best single metric for hotspots. Requires SimpleCov data. |
| **rubocop** | `gem install rubocop` | Complexity metrics (`--only Metrics`) |
| **brakeman** | `gem install brakeman` | Security scanning |
| **reek** | `gem install reek` | Code smells (feature envy, data clump, etc.) |
| **flog** | `gem install flog` | ABC complexity per method |
| **flay** | `gem install flay` | Structural duplication (AST-based) |
| **packwerk** | add `packwerk` to Gemfile | **Vertical-slicing primary signal:** boundary enforcement for modular monoliths. Surfaces existing pack structure or its absence. |

### JavaScript / TypeScript
| Tool | Install | Lens |
|------|---------|------|
| **dependency-cruiser** | `npm i -g dependency-cruiser` | Rule-based dependency validation |
| **madge** | `npm i -g madge` | Circular deps + orphan modules |
| **knip** | `npm i -g knip` | Unused files, exports, deps (best-in-class dead code) |
| **fta-cli** | `npm i -g fta-cli` | Fast complexity scoring |
| **ts-prune** | `npm i -g ts-prune` | Dead exports |
| **type-coverage** | `npm i -g type-coverage` | % of code with non-`any`/`unknown` types — directly measures contract discipline |
| **eslint-plugin-boundaries** | `npm i -D eslint-plugin-boundaries` | **Vertical-slicing primary signal:** declarative slice-direction rules. Presence/absence is itself a slicing signal. |

### Python
| Tool | Install | Lens |
|------|---------|------|
| **radon** | `pip install radon` | Cyclomatic + cognitive complexity, JSON output |
| **vulture** | `pip install vulture` | Dead code detection |
| **deptry** | `pip install deptry` | Unused/missing dependencies |

### Rust
| Tool | Install | Lens |
|------|---------|------|
| **cargo-depgraph** | `cargo install cargo-depgraph` | Crate dependency graphs |
| **cargo-udeps** | `cargo install cargo-udeps` | Unused dependencies (requires nightly) |

### Go
| Tool | Install | Lens |
|------|---------|------|
| **staticcheck** | `go install honnef.co/go/tools/cmd/staticcheck@latest` | Advanced static analysis |

## One-liner install (macOS)

```bash
# Core polyglot tools
brew install scc ast-grep semgrep
go install github.com/gabotechs/dep-tree@latest

# JS/TS tools
npm i -g jscpd madge dependency-cruiser knip fta-cli

# Git analysis
brew install mergestat/tap/mergestat git-quick-stats
```

## What the agents do with these tools

- **Coupling agent**: dep-tree entropy, dependency-cruiser, madge --circular
- **Complexity & Churn agent**: scc --by-file, fta-cli, skunk (Ruby), Jest/SimpleCov/coverage.py for coverage, mergestat SQL queries, code-maat. Composes via `references/hotspot-harness.md`.
- **State agent**: ast-grep for state patterns, semgrep for data flow
- **Duplication agent**: jscpd for clone detection, ast-grep for structural patterns, flay for Ruby structural dup
- **Error handling agent**: ast-grep for catch/rescue blocks, semgrep rules
- **Structure agent**: knip for dead code, scc for file sizes, vulture, ts-prune
- **Extensibility agent**: ast-grep for switch-on-type patterns, semgrep for hard-coded providers, git log for change-impact history
- **Variation Points agent**: grep for feature flags / Flipper / LaunchDarkly, ls policy/strategy directories
- **Contract Surface agent**: `bin/rails routes`, ls serializers, OpenAPI presence, type-coverage on TS boundaries, ENV var grep
- **Vertical Slicing agent**: packwerk validate/check, dep-tree, ESLint boundaries config presence, manual slice-import grep
