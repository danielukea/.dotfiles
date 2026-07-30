# Claude Code User Configuration

Personal configuration and reference documentation for Claude Code.

## Proactive Documentation

When the user is creating, modifying, or discussing these topics, read the relevant documentation BEFORE providing guidance:

- **Writing or editing skills**: use the `write-skill` skill — its template/guidance is the format authority; don't copy a peer skill's shape (they may have drifted), and a passing `validate_skill.sh` is not a passed review (run its judgment passes)
- **Writing or reviewing Ruby/Rails code**: use the `rails` skill — the Rails way first, the codebase's local conventions second; default to less abstraction, not more
- **Writing CLAUDE.md entries**: Read [~/.agents/docs/MEMORIES.md](~/.agents/docs/MEMORIES.md) first
- **Testing/evaluating**: Read [~/.agents/docs/TESTING.md](~/.agents/docs/TESTING.md) first
- **Team setup**: Read [~/.agents/docs/TEAM_WORKFLOWS.md](~/.agents/docs/TEAM_WORKFLOWS.md) first
- **Any git branch operation (diffing, logging, creating a branch)**: Read [~/.agents/docs/GIT_WORKFLOW.md](~/.agents/docs/GIT_WORKFLOW.md) first

## Reference Documentation

Detailed guides for extending Claude Code:

- [Skills](~/.agents/docs/SKILLS.md) - Principles for building and maintaining skills
- [Memories](~/.agents/docs/MEMORIES.md) - Institutional knowledge patterns (CLAUDE.md)
- [Testing](~/.agents/docs/TESTING.md) - Evaluation and iteration practices
- [Team Workflows](~/.agents/docs/TEAM_WORKFLOWS.md) - Collaboration and sharing patterns
- [Sources](~/.agents/docs/SOURCES.md) - Primary sources and references
- [Git Workflow](~/.agents/docs/GIT_WORKFLOW.md) - Resolving branch state safely across any repo

## Working with libraries

For version-specific or unfamiliar library/framework/API questions, fetch current docs from the official source (via web) rather than relying on training memory.

## Planning

When planning, use targeted pseudo-code — short snippets anchored to real file/function names — instead of prose descriptions or full implementations.


