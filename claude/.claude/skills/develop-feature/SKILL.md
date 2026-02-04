---
name: develop-feature
description: Full-cycle feature development from ticket to QA with TDD and single-responsibility PRs. Use when user says "develop this feature", "work on this ticket", "implement this", or provides a Linear/Basecamp/Trello ticket to implement.
allowed-tools: Read, Grep, Glob, Edit, Write, Task, Bash, WebFetch, AskUserQuestion, mcp__basecamp__*, mcp__plugin_wealthbox_atlassian__*, mcp__plugin_wealthbox_playwright__*, mcp__plugin_wealthbox_db__*
---

# Develop Feature

Full-cycle development workflow: ticket → context → plan → TDD → QA → done.

## When to Use This Skill

- User says "develop this feature", "work on this ticket", "implement this"
- User provides a Linear issue ID (e.g., `AIE-123`)
- User provides a Basecamp todo URL
- User provides a Trello card URL
- User wants to implement a feature end-to-end with proper planning and TDD

---

## Phase 1: Requirements Discovery

### 1.1 Identify and fetch ticket

Determine ticket type from user input:

**Linear** (e.g., `AIE-123`):
```
Use wealthbox:linear skill or gh to fetch issue details
```

**Basecamp** (URL containing `basecamp.com`):
```
mcp__basecamp__basecamp_get_todo - Fetch todo details
mcp__basecamp__basecamp_list_comments - Get discussion
mcp__basecamp__basecamp_get_document - Linked documents
```

**Trello** (URL containing `trello.com`):
```
WebFetch - Extract card details from URL
```

### 1.2 Extract from ticket

- Title and description
- Acceptance criteria (explicit or implied)
- User stories / who benefits
- Technical requirements mentioned
- Links to designs, docs, related work
- Dependencies on other tickets

### 1.3 Follow all linked context

Fetch from linked sources **in parallel**:

**Figma designs**:
```
mcp__plugin_figma_figma__get_screenshot - Capture design visuals
mcp__plugin_figma_figma__get_metadata - Component/layer info
```

**Confluence docs**:
```
mcp__plugin_wealthbox_atlassian__getConfluencePage - Page content
```

**Related tickets**:
Fetch and summarize any blocking or related issues.

**Existing PRs**:
Review approach and patterns used in related work.

### 1.4 Explore codebase

Use the **Explore agent** (Task tool with subagent_type=Explore):
- Where similar features are implemented
- Patterns used for this type of feature
- Shared components that could be reused
- Test patterns for this area of code

### 1.5 Save context

Create `.develop-feature/` directory in repo root if needed.

Save to `.develop-feature/[ticket-id]-context.md`:

```markdown
# [Ticket ID] - [Title]

## Requirements
[Condensed from ticket]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Technical Context
- Key files: [paths]
- Patterns to follow: [identified patterns]
- Shared components: [reusable components]

## Design References
- Figma: [links]
- Screenshots: [saved paths]

## Dependencies
- [Other tickets or services]

## Open Questions
- [Anything unclear]
```

**USER APPROVAL GATE 1**: "Here's what I understand about the requirements. Does this look correct? Any clarifications needed?"

---

## Phase 2: Planning

### 2.1 Architectural decisions

Use the **code-architect agent** for significant design decisions.

Consider:
- Codebase best practices
- ADRs in `docs/decisions/` (read relevant ones)
- In-flight PRs that might conflict
- Single responsibility: each PR does ONE thing

### 2.2 Break into PRs

Use the **project-planner agent** to decompose into vertical slices.

Typical ordering:
1. **Database/schema changes** - Always first, hardest to reverse
2. **Backend** - Models, services, controllers
3. **Shared components** - Reusable UI or logic
4. **Feature implementation** - The actual feature
5. **Polish** - Edge cases, error handling

Each PR should:
- Be reviewable in <30 minutes
- Be deployable independently (or feature-flagged)
- Include tests for its changes

### 2.3 Create PR plans

For each PR, save `.develop-feature/[ticket-id]-pr-[N].md`:

```markdown
# PR [N]: [Title]

## Purpose
[Single sentence describing what this PR accomplishes]

## Changes
- [ ] [file/component]: [what changes]
- [ ] [file/component]: [what changes]

## Tests
- [ ] [test description]
- [ ] [test description]

## Acceptance
- [ ] [criterion this PR satisfies]
```

### 2.4 Validate plan

Review against:
- [ ] Meets ALL requirements from ticket?
- [ ] Not over-engineered (minimum viable)?
- [ ] Follows codebase conventions?
- [ ] PRs truly single-responsibility?
- [ ] Test coverage adequate?

**Simplify if possible** - can PRs be combined? Any YAGNI?

**USER APPROVAL GATE 2**: "Here's the implementation plan broken into [N] PRs. Ready to start development?"

---

## Phase 3: Development (TDD)

Work through each PR plan using Red-Green-Refactor.

### 3.1 For each change in the PR:

**Red - Write failing test first**:
```bash
# RSpec (check for DevContainer vs Docker)
bundle exec rspec spec/path_spec.rb
# or via docker-runner
bin/docker/docker-runner bundle exec rspec spec/path_spec.rb

# Jest
yarn test path/to/test
```

**Green - Implement minimum code to pass**:
Write just enough code to make the test pass.

**Refactor - Clean up**:
```bash
# Ruby
bundle exec rubocop -a [file]

# JavaScript/TypeScript
yarn lint --fix
```

### 3.2 Validate with E2E tools

**UI changes** - Use Playwright MCP:
```
mcp__plugin_wealthbox_playwright__browser_navigate - Go to feature
mcp__plugin_wealthbox_playwright__browser_click - Test interactions
mcp__plugin_wealthbox_playwright__browser_take_screenshot - Capture result
```

**Data changes** - Use database queries:
```
mcp__plugin_wealthbox_db__execute_sql_crm_test - Verify data state
mcp__plugin_wealthbox_db__search_objects_crm_test - Find records
```

### 3.3 Track progress

Update PR plan files as items complete:
```markdown
## Changes
- [x] [file/component]: [what changes] ✅
- [ ] [file/component]: [what changes]
```

### 3.4 Complete PR

When all items done:
1. Run full test suite for affected areas
2. Run linters on all changed files
3. Create commit with clear message
4. Update PR plan status to COMPLETE
5. Move to next PR

---

## Phase 4: QA Validation

### 4.1 Create QA checklist

Save `.develop-feature/[ticket-id]-qa.md`:

```markdown
# QA: [Ticket ID]

## Acceptance Criteria
- [ ] [Criterion 1]: [How to verify]
- [ ] [Criterion 2]: [How to verify]

## Functional Tests
- [ ] Happy path: [steps]
- [ ] Edge case 1: [steps]
- [ ] Error handling: [steps]

## Visual/UI (if applicable)
- [ ] Matches Figma design
- [ ] Responsive behavior
- [ ] Accessibility

## Code Quality
- [ ] All tests pass
- [ ] Rubocop clean
- [ ] ESLint clean
- [ ] Brakeman clean (security)
```

### 4.2 Execute QA

For each item:
1. Perform the validation
2. Mark PASS ✅ or FAIL ❌
3. If FAIL, document the specific issue

Use tools:
- **Playwright MCP** for UI/E2E validation
- **Database queries** for data validation
- **Test suite** for regression testing

### 4.3 Evaluate results

**QA PASSED** if:
- All acceptance criteria validated ✅
- No critical bugs
- Code quality meets standards

**NEEDS WORK** if:
- Any acceptance criteria not met
- Bugs found needing fixes
- Code quality issues

If needs work → Return to Phase 3, fix issues, re-run QA.

**USER APPROVAL GATE 3**: "QA complete. [PASSED/N issues found]. Ready to create PR?"

---

## Phase 5: Complete

When QA passes:

### 5.1 Create PR(s)

```bash
gh pr create --title "[Ticket ID] [Description]" --body "$(cat <<'EOF'
## Summary
[What this PR does]

## Ticket
[Link to Linear/Basecamp/Trello]

## Test Plan
- [How to verify]

🤖 Generated with Claude Code
EOF
)"
```

### 5.2 Link back to ticket

Update the original ticket with PR link(s).

### 5.3 Summary output

```markdown
## Feature Complete: [Ticket ID]

- PRs: [links]
- Tests added: [count]
- Files changed: [count]
- QA: PASSED ✅
```

---

## Quality Checklist

Before marking complete:
- [ ] All acceptance criteria from ticket satisfied
- [ ] Tests written for new functionality
- [ ] Linters pass (rubocop, eslint)
- [ ] No security issues (brakeman)
- [ ] PR description links to ticket
- [ ] Context files in `.develop-feature/` updated

---

## Anti-Patterns to Avoid

1. **Skipping requirements discovery** - Always understand before coding
2. **Monolithic PRs** - Break into small, focused changes
3. **Tests after implementation** - Write tests first (TDD)
4. **Ignoring existing patterns** - Follow codebase conventions
5. **Over-engineering** - Minimum viable, no YAGNI
6. **Skipping QA** - Always validate before PR
