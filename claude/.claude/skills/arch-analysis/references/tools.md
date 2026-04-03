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

### JavaScript / TypeScript
| Tool | Install | Lens |
|------|---------|------|
| **dependency-cruiser** | `npm i -g dependency-cruiser` | Rule-based dependency validation |
| **madge** | `npm i -g madge` | Circular deps + orphan modules |
| **knip** | `npm i -g knip` | Unused files, exports, deps (best-in-class dead code) |
| **fta-cli** | `npm i -g fta-cli` | Fast complexity scoring |

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
- **Complexity & Churn agent**: scc --by-file, skunk (Ruby), mergestat SQL queries, code-maat
- **State agent**: ast-grep for state patterns, semgrep for data flow
- **Duplication agent**: jscpd for clone detection, ast-grep for structural patterns
- **Error handling agent**: ast-grep for catch/rescue blocks, semgrep rules
- **Structure agent**: knip for dead code, scc for file sizes, vulture
