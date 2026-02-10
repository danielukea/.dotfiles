# Memories (CLAUDE.md)

Guide to building institutional knowledge through CLAUDE.md files.

## Purpose

CLAUDE.md is a living document that accumulates lessons learned - a repository of do's and don'ts that the AI (and team members) benefit from.

## What to Include

- Corrections to recurring mistakes
- Team-specific rules and preferences
- Common errors to avoid
- Project conventions that differ from defaults
- Guardrails encoded in plain language

Examples:
- "Never deploy to production on Fridays"
- "Always run unit tests before merging"
- "Use snake_case for database columns, camelCase for JS variables"
- "The legacy API requires auth header X, not Y"

## What to Exclude

- General knowledge Claude already has
- Standard programming concepts
- Common library usage (unless project-specific)
- Verbose explanations

Litmus test: Would a senior developer already know this? If yes, don't include it.

## Maintenance

- **Prune periodically**: Remove outdated or irrelevant entries
- **Keep concise**: Every token counts in the context window
- **Update via PRs**: Treat CLAUDE.md changes as code changes
- **Review regularly**: Ensure entries still apply

## Location Patterns

### Project-level (`project/CLAUDE.md`)
- Project-specific conventions
- Architecture decisions
- Local development setup
- Team workflows

### User-level (`~/.claude/CLAUDE.md`)
- Personal preferences
- Cross-project patterns
- Tool configurations
- Reference documentation pointers

## Feedback Loop

The CLAUDE.md pattern creates continuous improvement:

1. AI makes a mistake
2. Human corrects it
3. Add entry to CLAUDE.md to prevent recurrence
4. AI internalizes the rule going forward

This greatly reduces repeated mistakes and aligns the agent with your standards.

## Team Integration

- Include CLAUDE.md in code reviews
- Tag Claude to update it when new patterns emerge
- Share learnings across the team
- Onboard new members by pointing them to CLAUDE.md
