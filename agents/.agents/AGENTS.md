# Agent User Configuration

Canonical personal configuration shared by every coding agent (Claude Code, Codex, Gemini
CLI). Tool-specific context files delegate here — **edit this file, not those.**

## Proactive Documentation

When creating, modifying, planning, or discussing these topics, read the relevant
documentation BEFORE planning or providing guidance:

- **Planning or proposing an approach** (plan mode, "how should we do this", any design question): Read [~/.agents/docs/PLANNING.md](~/.agents/docs/PLANNING.md) first — it gates on checking for relevant skills before you draft
- **Writing or editing skills**: use the `write-skill` skill — its template/guidance is the format authority; don't copy a peer skill's shape (they may have drifted), and a passing `validate_skill.sh` is not a passed review (run its judgment passes)
- **Writing or reviewing Ruby/Rails code**: use the `rails` skill — the Rails way first, the codebase's local conventions second; default to less abstraction, not more
- **Writing CLAUDE.md / AGENTS.md entries**: Read [~/.agents/docs/MEMORIES.md](~/.agents/docs/MEMORIES.md) first
- **Testing/evaluating**: Read [~/.agents/docs/TESTING.md](~/.agents/docs/TESTING.md) first
- **Team setup**: Read [~/.agents/docs/TEAM_WORKFLOWS.md](~/.agents/docs/TEAM_WORKFLOWS.md) first
- **Any git branch operation (diffing, logging, creating a branch)**: Read [~/.agents/docs/GIT_WORKFLOW.md](~/.agents/docs/GIT_WORKFLOW.md) first

## Reference Documentation

Detailed guides for extending this agent setup:

- [Skills](~/.agents/docs/SKILLS.md) - Principles for building and maintaining skills
- [Memories](~/.agents/docs/MEMORIES.md) - Institutional knowledge patterns (CLAUDE.md / AGENTS.md)
- [Testing](~/.agents/docs/TESTING.md) - Evaluation and iteration practices
- [Team Workflows](~/.agents/docs/TEAM_WORKFLOWS.md) - Collaboration and sharing patterns
- [Sources](~/.agents/docs/SOURCES.md) - Primary sources and references
- [Git Workflow](~/.agents/docs/GIT_WORKFLOW.md) - Resolving branch state safely across any repo
- [Planning](~/.agents/docs/PLANNING.md) - Checking for skills before drafting, and how to write a plan

## Working with libraries

For version-specific or unfamiliar library/framework/API questions, fetch current docs from the official source (via web) rather than relying on training memory.
