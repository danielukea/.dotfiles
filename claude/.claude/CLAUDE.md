# Claude Code User Configuration

Personal configuration and reference documentation for Claude Code.

## Proactive Documentation

When the user is creating, modifying, or discussing agents or skills, read the relevant documentation BEFORE providing guidance:

- **Making an agent**: Read [docs/MAKING_AN_AGENT.md](docs/MAKING_AN_AGENT.md) first
- **Making a skill**: Read [docs/MAKING_A_SKILL.md](docs/MAKING_A_SKILL.md) first
- **Writing CLAUDE.md entries**: Read [docs/MEMORIES.md](docs/MEMORIES.md) first
- **Testing/evaluating**: Read [docs/TESTING.md](docs/TESTING.md) first
- **Team setup**: Read [docs/TEAM_WORKFLOWS.md](docs/TEAM_WORKFLOWS.md) first

## Reference Documentation

Detailed guides for extending Claude Code:

- [Making an Agent](docs/MAKING_AN_AGENT.md) - Multi-agent workflows and orchestration
- [Making a Skill](docs/MAKING_A_SKILL.md) - Skill authoring guide
- [Memories](docs/MEMORIES.md) - Institutional knowledge patterns (CLAUDE.md)
- [Testing](docs/TESTING.md) - Evaluation and iteration practices
- [Team Workflows](docs/TEAM_WORKFLOWS.md) - Collaboration and sharing patterns
- [Sources](docs/SOURCES.md) - Primary sources and references

## Ralph — Headless Plan Runner

`ralph` is a bash script at `~/.claude/scripts/ralph` (symlinked from `~/.dotfiles/claude/.claude/scripts/ralph`) that runs a headless `while true` loop, spawning a fresh `claude -p` per iteration to implement a plan file step by step.

### Usage
```
ralph <plan-file> [OPTIONS]
  --max-iterations <N>   (default: 20)
  --model <model>        (default: opus)
  --with-browser         Include Playwright tools for visual QA
  --dry-run              Show prompt without executing
```

### How It Works
- Each iteration gets a **clean context window** — no accumulated state
- Reads plan file, finds next `- [ ]` item, implements ONE step, runs tests/lint
- On success: marks step `- [x]` in the plan file
- On failure: leaves step unmarked, moves to next iteration (fail-forward)
- Checkpoints via `git commit` on a `ralph/<plan-name>` branch after each iteration
- Ctrl-C cleanly exits with a summary

### Writing Plan Files for Ralph
- Use markdown checkboxes: `- [ ]` for incomplete, `- [x]` for done
- Each step should be **independently implementable** — one logical change per checkbox
- Be specific: reference file paths, method names, and expected behavior
- Order steps so earlier ones don't depend on later ones
- Ralph detects completion by counting `- [ ]` lines via regex `^\s*- \[ \]`

### Best Practices
- **Always `--dry-run` first** to verify the prompt and step count look right
- **Use `--max-iterations 3`** for initial testing on a new plan
- **Keep steps small** — ralph implements one step per full Claude invocation, so smaller steps = more reliable
- **Review the branch before merging** — ralph commits with `--no-verify`, so run linters/CI yourself
- The prompt is hardcoded to use `bin/docker/docker-runner` for tests/lint — this assumes the crm-web docker environment. For other projects, the script prompt may need editing
- Ralph creates/checks out a `ralph/<plan-name>` branch — your original branch is untouched
- Default tools: `Bash Read Edit Write Grep Glob Task WebFetch`
- `--with-browser` adds Playwright MCP tools (navigate, screenshot, snapshot, click, fill_form, evaluate) and appends visual QA instructions to the prompt
