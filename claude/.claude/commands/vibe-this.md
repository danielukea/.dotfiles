---
description: Generate a spec from a brief description for AI implementation
arguments:
  - name: description
    description: Brief description of the feature, bug fix, or refactor
    required: true
---

# Vibe Spec Generator

Generate a specification for AI implementation from a brief description.

## Step 1: Determine spec location

Check for directories in order, use first that exists:

1. `.ai-shared/specs/`
2. `.claude/specs/`
3. Current working directory

## Step 2: Classify work type

From the description, classify as:

- **Feature**: New functionality
- **Bug**: Correcting broken behavior
- **Refactor**: Restructuring without behavior change

If unclear, ask the user.

## Step 3: Gather context

Before asking questions, proactively gather context:

- Use Glob/Grep to find related code paths
- Check for existing specs in the spec directory
- Use Figma or Playwright MCP tools (`mcp__figma__*`) if UI work is involved
- use DB mcp to evaluate db state if needed
- Search for related GitHub issues if referenced
- For a larger task use helper agents to gather context

## Step 4: Ask clarifying questions

Ask 2-5 targeted questions to resolve ambiguities. Focus on:

- Expected vs current behavior (bugs)
- User impact and edge cases (features)
- Scope boundaries and breaking changes (refactors)

## Step 5: Generate the spec

Read the appropriate template from `~/.claude/templates/`:

- Feature → `~/.claude/templates/feature-spec.md`
- Bug → `~/.claude/templates/bug-spec.md`
- Refactor → `~/.claude/templates/refactor-spec.md`

Fill in the template with gathered context and user answers.

## Step 6: Save

Save as `[type]-[kebab-case-title].md` in the determined location.
Confirm the file path with the user.

## Description

$ARGUMENTS
