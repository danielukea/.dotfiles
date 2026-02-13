---
name: scope-project
description: Systematically scope projects by gathering context from multiple sources (Figma, Basecamp, Confluence, Jira, GitHub), asking clarifying questions, exploring related repositories, and breaking work into independent vertical slices. Use when user says "scope this project", "scope this feature", "help me plan this", or provides design/spec URLs needing breakdown.
allowed-tools: Read, Grep, Glob, Edit, Write, Task, WebFetch, AskUserQuestion, mcp__plugin_figma_figma__*, mcp__plugin_wealthbox_playwright__*, mcp__plugin_wealthbox_atlassian__*, mcp__basecamp__*
---

# Scope Project

Systematically scope projects by gathering comprehensive context, asking clarifying questions, and decomposing work into independent vertical slices that each deliver real user value.

## When to Use This Skill

- User says "scope this project", "scope this feature", "help me plan this"
- User provides Figma, Basecamp, Confluence, Jira, or GitHub URLs needing breakdown
- User asks for vertical slices or implementation planning
- User wants to understand what's involved before starting work

## Input Types Supported

- **Figma URLs**: Design files, FigJam boards, prototypes
- **Basecamp URLs**: Projects, todo lists, messages
- **Confluence/Jira URLs**: Pages, issues, epics
- **GitHub URLs**: Issues, PRs, repositories
- **Plain documents**: Requirements, specs, notes
- **Screenshots**: Uploaded images of designs or UI
- **Web URLs**: Any relevant external documentation

---

## Phase 1: Input Ingestion

Parse and classify all provided inputs:

1. **Identify URL types** by domain/pattern:
   - Figma: `figma.com/file/`, `figma.com/design/`, `figma.com/board/`
   - Basecamp: `3.basecamp.com/`
   - Confluence: `atlassian.net/wiki/`
   - Jira: `atlassian.net/browse/`, `atlassian.net/jira/`
   - GitHub: `github.com/`

2. **Extract identifiers**:
   - Figma: file key, node IDs from URL
   - Basecamp: account ID, project ID, todolist ID
   - Jira: issue key (e.g., `PROJ-123`)
   - Confluence: page ID, space key

3. **Note referenced repositories** mentioned in any source

4. **Ask the user**:
   - "Which repositories should I explore for this project?"
   - Present discovered repos from `~/Workspace/` as options

---

## Phase 1B: Triage Existing Work

**CRITICAL**: Before drafting any new TODOs, check what already exists.

If a Basecamp todo list is linked:

1. **Fetch all existing TODOs** from the list
2. **Check the codebase** for each TODO — is it already implemented?
3. **Present a triage table** to the user:

| # | Basecamp TODO | Verdict |
|---|---------------|---------|
| 1 | [Title] | **NEEDS WORK** — [reason] |
| 2 | [Title] | **ALREADY DONE** — [what exists in code] |
| 3 | [Title] | **SKIP** — [why it's unnecessary] |
| 4 | [Title] | **SEPARATE PR** — [being handled elsewhere] |

4. **Ask the user** how to handle already-done items (mark complete, consolidate, replace)
5. Only draft new/rewritten TODOs for items that actually need work

This prevents creating duplicate work and respects existing context.

---

## Phase 2: External Context Gathering

Fetch from all linked sources **in parallel**:

### Figma
```
mcp__plugin_figma_figma__get_screenshot - Capture design visuals
mcp__plugin_figma_figma__get_metadata - Get component/layer info
mcp__plugin_figma_figma__get_figjam - Extract FigJam decisions/flows
```

### Basecamp
```
mcp__basecamp__basecamp_get_project - Project overview
mcp__basecamp__basecamp_list_todolists - All todo lists
mcp__basecamp__basecamp_list_todos - Existing todos
mcp__basecamp__basecamp_list_messages - Discussions and decisions
```

### Confluence
```
mcp__plugin_wealthbox_atlassian__getConfluencePage - Page content
mcp__plugin_wealthbox_atlassian__searchConfluenceUsingCql - Related pages
mcp__plugin_wealthbox_atlassian__getConfluencePageDescendants - Child pages
```

### Jira
```
mcp__plugin_wealthbox_atlassian__getJiraIssue - Issue details
mcp__plugin_wealthbox_atlassian__searchJiraIssuesUsingJql - Related issues
mcp__plugin_wealthbox_atlassian__getJiraIssueRemoteIssueLinks - Linked resources
```

### Current UI (if applicable)
```
mcp__plugin_wealthbox_playwright__browser_navigate - Go to existing feature
mcp__plugin_wealthbox_playwright__browser_take_screenshot - Capture current state
```

### Web URLs
```
WebFetch - Fetch and process any external documentation
```

**USER APPROVAL GATE 1**: "Here's what I gathered from external sources. Does this capture the context correctly? Anything missing?"

---

## Phase 3: Repository Discovery & Exploration

For each repository identified:

1. **Read context files**:
   - `CLAUDE.md` - Project conventions and setup
   - `.claude/agents/*.md` - Available specialized agents
   - `docs/decisions/` or `docs/adrs/` - Architecture Decision Records

2. **Identify key patterns**:
   - Directory structure
   - Naming conventions
   - Test organization
   - Component patterns

3. **Note specialized agents available** for later phases

---

## Phase 4: Codebase Context Gathering

Search for related existing code:

```
Glob - Find files by pattern (components, models, controllers)
Grep - Search for related terms, similar features
Read - Examine key files identified
```

Focus on:
- **Existing components** that could be reused
- **Database schemas** (models, migrations)
- **API endpoints** (routes, controllers)
- **Test patterns** (how similar features are tested)
- **Similar features** as reference implementations

Take screenshots of current UI state for comparison with designs.

---

## Phase 5: Business Context Analysis (THE WHY)

Build understanding of the business context:

### Questions to Answer
- What problem is this solving for users?
- Who are the affected user personas?
- What's the expected business impact?
- What are the priority and timeline factors?
- What happens if we don't build this?

### Output: Business Context Section

```markdown
## Business Context

### Problem Statement
[One paragraph describing the user problem being solved]

### User Personas
- **[Persona 1]**: [How this affects them]
- **[Persona 2]**: [How this affects them]

### Success Metrics
- [Metric 1]: [Target]
- [Metric 2]: [Target]

### Priority Factors
- [Why this is being prioritized now]
```

---

## Phase 6: Requirements Synthesis (THE WHAT)

### Extract Requirements
Compile requirements from all context sources into categories:

- **Must Have**: Core functionality, blocking for release
- **Should Have**: Important but not blocking
- **Nice to Have**: Enhancements for future iterations

### Map to Acceptance Criteria
Each requirement becomes testable acceptance criteria.

**IMPORTANT: Write acceptance criteria as observable behaviors, NOT implementation details.**

These TODOs are for humans. Write what a QA person can observe and verify.

**Wrong** (implementation-focused):
- "Use `sourceTypes` prop to populate dropdown"
- "Initialize wizard with `formKey` pattern to reset state"
- "Use `useFieldArray` to manage relationship entries"

**Right** (behavior-focused):
- "Clicking 'Add Relationship' opens a multi-step wizard modal titled 'Add Relationship'"
- "Subtitle reads 'Select an Object'"
- "'Next' is disabled until a type is selected"
- "Going back to this step preserves the previous selection"

Keep implementation details in a separate **Technical Resources** section.

### Ask Clarifying Questions

**CRITICAL**: Never proceed with ambiguity. Ask questions in themed batches:

**Batch 1: Scope Boundaries**
- What's explicitly in scope vs out of scope?
- Are there features that look related but should be separate work?

**Batch 2: Behavior Ambiguities**
- What happens when [edge case]?
- How should [specific interaction] work?

**Batch 3: Edge Cases**
- What if user has no data?
- What if there are many items?
- What about error states?

**Batch 4: Dependencies**
- Does this depend on other work being completed?
- Are there external systems or APIs involved?

**Batch 5: Constraints**
- Performance requirements?
- Accessibility requirements?
- Browser/device support?

**USER APPROVAL GATE 2**: Present clarifying questions. Wait for answers before proceeding.

---

## Phase 7: Design Gap Analysis

Identify gaps between designs/requirements and implementation reality.

### UI Gaps
Use `design-system-expert` agent to analyze:
- Missing states (loading, empty, error)
- Responsive design considerations
- Accessibility gaps (ARIA, keyboard nav, screen readers)
- Design system inconsistencies
- Animation/interaction specifications

### Architectural Gaps
Use `code-architect` agent to analyze:
- New models/tables needed
- API changes required
- Integration points with existing systems
- Security considerations
- Performance implications

### Output: Gap Analysis Section

```markdown
## Design Gap Analysis

### UI Gaps
- [ ] [Gap 1]: [Description and recommendation]
- [ ] [Gap 2]: [Description and recommendation]

### Architectural Gaps
- [ ] [Gap 1]: [Description and recommendation]
- [ ] [Gap 2]: [Description and recommendation]

### Questions for Design/Product
- [Question needing resolution before implementation]
```

**USER APPROVAL GATE 3**: "These are the design gaps I identified. Any blockers here?"

---

## Phase 8: Implementation Planning (THE HOW)

Orchestrate specialized agents for technical planning:

### Agents to Invoke
- `code-architect` - Overall system design
- `rails-architect` - Backend patterns (if Rails project)
- `design-system-expert` - Component approach and styling

### Output: Technical Approach Section

```markdown
## Technical Approach

### Architecture Overview
[High-level description of how components fit together]

### Data Model
- [New/modified models and their relationships]

### API Design
- [New/modified endpoints]

### Component Hierarchy
- [Frontend component structure]

### Key Technical Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]
```

---

## Phase 9: Vertical Slice Decomposition

Break work into independent, deployable slices.

### Principles
- **Each slice delivers real user value independently**
- **Each slice is deployable on its own**
- **Minimize cross-dependencies between slices**
- **Earlier slices establish patterns for later ones**
- **Order by value of early feedback**

### Process

1. **Identify the "Walking Skeleton"** (Slice 1)
   - Minimal end-to-end flow
   - Proves the architecture works
   - Establishes patterns for subsequent slices

2. **Layer functionality in value-ordered increments**
   - Each slice adds observable user value
   - Not horizontal layers (all backend, then all frontend)

3. **Separate edge cases into later slices**
   - Core happy path first
   - Error handling and edge cases follow

4. **Validate independence**
   - Each slice should be reviewable/mergeable alone
   - No slice should require another unmerged slice

### Consolidation Pass

After drafting TODOs, **proactively ask**: "Can any of these be combined? Are there steps that pragmatically belong together?"

Prefer fewer, meatier TODOs over many granular ones. Group steps that:
- Share a component or data flow
- Would be awkward to review/test independently
- Would create unnecessary merge conflicts if done in parallel

Example: 7 wizard step TODOs → 3 consolidated TODOs (shell+step1, middle steps, final step+submission).

### Slice Template

```markdown
## TODO N: [Descriptive Name]

**Description**
[What and why — 2-3 sentences]

**Prerequisite:** [What must be done first, if any]

**Figma**
- [Link to relevant design frames]

**Acceptance Criteria**
- [ ] [Observable behavior 1 — what a QA person can verify]
- [ ] [Observable behavior 2]

**Technical Resources**
- [File paths, patterns, implementation hints — for developers]

**Out of Scope**
- [Feature X] → TODO M
- [Feature Y] → separate PR
```

**IMPORTANT: Every TODO MUST have an Out of Scope section** listing items explicitly excluded, with a pointer to which TODO or PR covers them. This prevents scope creep and makes boundaries clear for developers.

### Validate with project-planner Agent
Invoke `project-planner` to review slice decomposition for:
- Independence verification
- Dependency ordering
- Completeness check

**USER APPROVAL GATE 4**: "Does this slice breakdown look right? Any adjustments needed?"

---

## Phase 10: Flowchart & Documentation

### Generate Diagrams
Use `mcp__plugin_figma_figma__generate_diagram` to create:

1. **User Journey Flowchart** - How users move through the feature
2. **State Diagram** - Different states and transitions
3. **System Flow** - How data moves between components

Use vertical orientation (TD) by default. Focus on user actions and business outcomes.

### Final Output Structure

```markdown
# Project Scope: [Name]

## Executive Summary
[2-3 sentence overview of what's being built and why]

## Business Context (WHY)
[From Phase 5]

## Requirements (WHAT)
### Must Have
### Should Have
### Nice to Have

## Technical Approach (HOW)
[From Phase 8]

## Design Gap Analysis
[From Phase 7]

## Vertical Slices
[From Phase 9]

## Flowcharts
[Embedded or linked diagrams from Phase 10]

## Risk Register
- [Risk 1]: [Mitigation]
- [Risk 2]: [Mitigation]

## Open Questions
- [Question still needing resolution]

## References
- [Figma]: [URL]
- [Basecamp]: [URL]
- [Related PR]: [URL]
```

**USER APPROVAL GATE 5**: "Complete scope ready. Where would you like me to save this document?"

---

## Quality Checklists

### Context Gathering
- [ ] All URLs fetched and processed
- [ ] Screenshots of designs captured
- [ ] Screenshots of current UI captured
- [ ] All related repos identified
- [ ] CLAUDE.md files read for each repo
- [ ] ADRs reviewed if present
- [ ] Similar features identified as reference

### Existing Work Triage
- [ ] Existing Basecamp TODOs fetched and reviewed
- [ ] Each existing TODO checked against codebase for completion
- [ ] Triage table presented to user
- [ ] Already-done items identified and marked

### TODOs / Vertical Slices
- [ ] Each TODO delivers independent user value
- [ ] No circular dependencies
- [ ] Consolidation pass completed — no unnecessarily granular TODOs
- [ ] Acceptance criteria are observable behaviors (not implementation details)
- [ ] Every TODO has an Out of Scope section with pointers
- [ ] Technical details in Technical Resources, not in acceptance criteria
- [ ] File paths reference actual code
- [ ] Pragmatic skip decisions documented (unnecessary work identified)

---

## Anti-Patterns to Avoid

1. **Proceeding with ambiguity** - Always ask questions first
2. **Horizontal slices** - Never slice by layer (all backend, then frontend)
3. **Scope creep** - Each slice as small as possible while delivering value
4. **Assuming context** - Verify by reading code
5. **Skipping current state** - Always understand what exists first
6. **Implementation-focused acceptance criteria** - Write observable behaviors, not code patterns. "Clicking X does Y", not "Use hook Z"
7. **Missing out-of-scope** - Every TODO needs explicit boundaries pointing to responsible TODOs
8. **Too many granular TODOs** - Consolidate aggressively. Fewer meatier TODOs > many tiny ones
9. **Ignoring existing work** - Always triage existing Basecamp TODOs before drafting new ones
10. **Unnecessary TODOs** - If a future change makes a TODO irrelevant, skip it. If something is mostly automatic, fold it into an acceptance criterion instead of a separate TODO
11. **Monolithic flowcharts** - Create focused diagrams

---

## Agent Integration Reference

| Phase | Agent | Purpose |
|-------|-------|---------|
| 7 | `design-system-expert` | UI gap analysis |
| 7 | `code-architect` | Architectural gap analysis |
| 8 | `code-architect` | System design |
| 8 | `rails-architect` | Backend patterns (Rails) |
| 9 | `project-planner` | Validate slice decomposition |

---

## Key Principles

### Split by Assumption, Not Implementation
**Wrong**: "Add button", "Button opens modal", "Modal has form"
**Right**: "Add New opens flyout (single relationship)", "Relationship selection dialog (multiple relationships)"

### Use User-Focused Language
**Wrong**: "Handle one-to-one cardinality"
**Right**: "Warn before replacing existing link"

### Verify Before Assuming
Don't assume something is "for free" - search the codebase:
- Check if similar patterns exist
- If logic doesn't exist for your use case, note the gap
- Document gaps in the Technical Approach section

### Match Existing UI Patterns
Before designing new UI:
- Take screenshots of similar flows in the app
- Use the same components and interactions
- Reference the existing code in slice documentation

### Include Visual Documentation
Each slice should reference:
- Screenshots of the expected UI (from Figma)
- Current state screenshots for comparison
