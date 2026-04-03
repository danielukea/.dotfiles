---
name: prd
description: Build a PRD for a Linear project through an interview-driven workflow. Gathers context from Linear (project, documents, issues), interviews you section-by-section, and saves a structured PRD to the project's notes folder. Use when user says "prd", "write a prd", "create prd", or invokes /prd.
user-invokeable: true
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_wealthbox_linear__get_project, mcp__plugin_wealthbox_linear__list_documents, mcp__plugin_wealthbox_linear__get_document, mcp__plugin_wealthbox_linear__list_issues, mcp__plugin_wealthbox_linear__list_milestones, mcp__plugin_wealthbox_linear__get_issue
---

# PRD Skill

Build a Product Requirements Document for a Linear project.

## Input

The user provides a Linear project name, URL, or ID as an argument. If no argument is given, ask for it.

## Step 0: Resolve project

Parse the argument to extract a Linear project identifier. Fetch the project:

```
mcp__plugin_wealthbox_linear__get_project(query: <identifier>, includeMembers: true, includeMilestones: true, includeResources: true)
```

If the project is not found, ask the user to clarify.

## Step 1: Gather context from Linear

Run these in parallel:

1. **List project documents** — `list_documents(projectId: <id>)` — then fetch each document's content with `get_document`. Look for pitches, audits, specs, or any existing PRD-like content.
2. **List project issues** — `list_issues(project: <id>, limit: 100)` — scan for patterns: what work is planned, what's in progress, what's done.

Read any existing project notes in `~/Workspace/notes/projects/` that match the project name (use Glob to search).

Synthesize what you learned into a brief internal summary (do not output yet).

## Step 2: Interview — Context section

Present the gathered context to the user, then ask questions to fill the Context section:

Use AskUserQuestion for each:

1. **Problem** — "Based on what I gathered, here's my understanding of the problem: [summary]. Is this accurate, or how would you refine it?"
2. **Solution** — "What is the high-level solution approach?"
3. **Primary Customer** — "Who is the primary customer or user for this? Is there a pilot customer?"

Also ask: "Are there any reference links I should include at the top? (spike PRs, meeting transcripts, design docs, etc.)"

## Step 3: Interview — Requirements

Walk through requirements one at a time. For each requirement:

1. Ask: "What's the next requirement? Describe what the system should do. (Say 'done' when all requirements are captured.)"
2. For each requirement the user describes:
   - Assign it a sequential ID (REQ-01, REQ-02, ...)
   - Draft 2-4 acceptance criteria (AC-01.1, AC-01.2, ...)
   - Present the drafted requirement back and ask if it's accurate or needs changes
3. Continue until the user says "done"

Guidelines for requirements:
- Each requirement should describe ONE capability or behavior
- Include API endpoints if applicable (method + path)
- Acceptance criteria should be testable and specific
- Cross-reference other requirements where relevant (e.g., "see REQ-02")

## Step 4: Interview — Design Decisions

Ask: "What deliberate decisions have you made about what to defer, exclude, or simplify? These are conscious tradeoffs — things you chose NOT to do and why."

For each item, capture:
- The decision (framed as an active choice, not a passive exclusion)
- The rationale
- A link if relevant (e.g., separate Linear project)

Present the table back for review.

## Step 5: Interview — Open Design Questions

Ask: "Are there any unresolved design questions that need team discussion before implementation?"

Capture each as a numbered item with a brief description.

## Step 6: Draft and review

Assemble the full PRD using this structure:

```markdown
# PRD: <title>

Linear Project: [<name>](<url>)
<additional reference links>

---

## Context

### Problem

<problem statement>

### Solution

<solution summary>

### Primary Customer

<customer description>

## Requirements

### REQ-01: <name>

<description>

**Acceptance Criteria:**

- AC-01.1: <criterion>
- AC-01.2: <criterion>

### REQ-02: <name>
...

---

## Design Decisions

| Decision | Rationale | Link |
|----------|-----------|------|
| ... | ... | ... |

---

## Open Design Questions

These items need team discussion before implementation:

1. **<topic>** — <description>
```

Present the full draft to the user for review. Ask: "Here's the draft PRD. What would you like to change?"

Iterate until the user approves.

## Step 7: Save

Determine the output path:
- If a project folder already exists in `~/Workspace/notes/projects/`, save there as `prd.md`
- Otherwise, ask the user for the folder name, create it, and save as `prd.md`

Tell the user: "PRD saved to `<path>`. When you're happy with it, you can push the content to the Linear project description."
