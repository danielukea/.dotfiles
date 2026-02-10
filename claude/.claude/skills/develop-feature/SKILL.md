---
name: develop-feature
description: Full-cycle feature development from ticket to QA with TDD and single-responsibility PRs. Use when user says "develop this feature", "work on this ticket", "implement this", or provides a Linear/Basecamp/Trello ticket to implement.
allowed-tools: Read, Grep, Glob, Edit, Write, Task, Bash, WebFetch, AskUserQuestion, mcp__basecamp__*, mcp__plugin_wealthbox_atlassian__*, mcp__plugin_wealthbox_playwright__*, mcp__plugin_wealthbox_db__*
---

# Develop Feature

Full-cycle development workflow: ticket → context → plan → TDD → QA → done.

**CRITICAL**: This skill enforces TDD and QA. You MUST NOT skip these phases.

## Workflow Overview

```
Phase 1: Requirements    → USER APPROVAL GATE 1
Phase 2: Planning        → RAILS-ARCHITECT REVIEW → USER APPROVAL GATE 2
Phase 3: TDD Development → Tests written BEFORE code
Phase 4: QA Validation   → RAILS-ARCHITECT CODE REVIEW → USER APPROVAL GATE 3
Phase 5: Complete        → PR created

         ┌─────────────────────────────────────┐
         │   PHASE 3 ←→ PHASE 4 LOOP          │
         │   (repeat until QA + Review pass)   │
         └─────────────────────────────────────┘
```

**IMPORTANT**: Phases 3 and 4 form a loop. If QA fails or code review finds issues, return to Phase 3 to fix, then re-run Phase 4. This loop continues until ALL checks pass.

---

## Phase 0: Check for Existing Context (ALWAYS RUN FIRST)

Before starting any discovery work, check if context already exists from a previous session.

### 0.1 Check for `.develop-feature/` directory

```bash
ls -la .develop-feature/ 2>/dev/null || echo "No existing context"
```

### 0.2 If context exists, identify ticket files

Look for files matching the ticket ID pattern:
- `[ticket-id]-context.md` - Requirements and technical context
- `[ticket-id]-pr-*.md` - PR plans
- `[ticket-id]-architect-review.md` - Architecture review
- `[ticket-id]-qa.md` - QA checklist
- `[ticket-id]-code-review.md` - Code review results

### 0.3 Determine current phase

Read existing files to determine where work left off:

| Files Present | Current Phase |
|---------------|---------------|
| None | Start Phase 1 |
| `*-context.md` only | Phase 1 complete, start Phase 2 |
| `*-context.md` + `*-pr-*.md` | Phase 2 in progress |
| `*-pr-*.md` + `*-architect-review.md` | Phase 2 complete, start Phase 3 |
| Implementation code exists | Phase 3 in progress or complete |
| `*-qa.md` exists | Phase 4 in progress |
| `*-code-review.md` with approval | Phase 4 complete, ready for Phase 5 |

### 0.4 Present resume option to user

If existing context found, summarize and ask:

```
## Existing Context Found

I found previous work for this ticket:
- Context: [summary of requirements]
- Phase: [current phase]
- Progress: [what's done vs remaining]

Options:
1. **Resume** - Continue from where we left off
2. **Start Fresh** - Re-gather context (existing files will be updated)

Which would you like?
```

### 0.5 Resume workflow

If user chooses to resume:
- Read all existing context files
- Skip to the appropriate phase
- Continue from the next incomplete step

If user chooses to start fresh:
- Proceed with Phase 1 as normal
- Existing files will be updated with new information

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

## Tests (MUST be written BEFORE implementation)
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

### 2.5 Rails Architect Plan Review (MANDATORY)

**BEFORE presenting plan to user**, spawn the **rails-architect agent** to review:

```
Task tool with subagent_type=rails-architect

Prompt: "Review this implementation plan for [feature name].

Context file: .develop-feature/[ticket-id]-context.md
PR plans: .develop-feature/[ticket-id]-pr-*.md

Evaluate:
1. Does the architecture follow Rails conventions and codebase patterns?
2. Are the PRs properly decomposed (single responsibility)?
3. Are there any missing considerations (database indexes, N+1 queries, etc.)?
4. Is the test coverage plan adequate?
5. Any concerns about the approach?

Provide specific feedback and recommendations."
```

**Address all rails-architect feedback** before proceeding. Update PR plans if needed.

Save architect review to `.develop-feature/[ticket-id]-architect-review.md`:
```markdown
# Architect Review: [Ticket ID]

## Reviewer
rails-architect agent

## Feedback
[Summary of feedback]

## Recommendations
- [Recommendation 1]
- [Recommendation 2]

## Changes Made
- [How feedback was addressed]

## Approval
✅ Plan approved by rails-architect
```

**USER APPROVAL GATE 2**: "Here's the implementation plan broken into [N] PRs. The rails-architect has reviewed and approved the approach. Ready to start development?"

---

## Phase 3: TDD Development

**MANDATORY**: You MUST follow Red-Green-Refactor for EVERY change. Writing implementation code before tests is NOT allowed.

### 3.1 TDD Cycle (REQUIRED for each feature/change)

For EACH item in the PR plan, follow this EXACT sequence:

#### Step 1: RED - Write failing test FIRST

```bash
# Create the test file BEFORE any implementation
# Write tests that describe the expected behavior
```

**RSpec example**:
```ruby
# spec/controllers/example_controller_spec.rb
describe ExampleController do
  describe "POST #action" do
    it "creates a record" do
      expect { post :action, params: valid_params }
        .to change(Model, :count).by(1)
    end
  end
end
```

**Jest example**:
```typescript
// spec/javascript/components/Example.test.tsx
describe('<Example />', () => {
  it('renders the button', () => {
    render(<Example />);
    expect(screen.getByRole('button')).toBeInTheDocument();
  });
});
```

#### Step 2: RUN the test - verify it FAILS

```bash
# RSpec
bin/docker/docker-runner bundle exec rspec spec/path_spec.rb

# Jest
bin/docker/docker-runner yarn jest spec/javascript/path.test.tsx
```

**STOP**: The test MUST fail before proceeding. If it passes, your test isn't testing new behavior.

#### Step 3: GREEN - Write MINIMUM code to pass

Implement ONLY enough code to make the failing test pass. No more.

#### Step 4: RUN the test - verify it PASSES

```bash
# Same commands as Step 2
```

**STOP**: The test MUST pass before proceeding. If it fails, fix the implementation.

#### Step 5: REFACTOR - Clean up

```bash
# Ruby
bin/docker/docker-runner bundle exec rubocop -a [file]

# JavaScript/TypeScript
bin/docker/docker-runner yarn eslint [file] --fix
```

#### Step 6: REPEAT for next test case

Continue until all behavior for this change is tested.

### 3.2 TDD Checklist (verify after each change)

Before moving to next item in PR plan:
- [ ] Test was written BEFORE implementation
- [ ] Test failed initially (RED)
- [ ] Implementation made test pass (GREEN)
- [ ] Code is clean and linted (REFACTOR)
- [ ] No untested code paths

### 3.3 Track progress in PR plan

Update `.develop-feature/[ticket-id]-pr-[N].md` as you go:

```markdown
## Changes
- [x] [file/component]: [what changes] ✅ (TDD: RED→GREEN→REFACTOR)
- [ ] [file/component]: [what changes]

## Tests
- [x] [test description] ✅ PASSING
- [ ] [test description]
```

### 3.4 Complete PR development

When all items done:
1. Run full test suite for affected areas
2. Run linters on all changed files
3. Verify all tests pass
4. Update PR plan status to COMPLETE
5. **DO NOT create PR yet** - proceed to Phase 4 QA

---

## Phase 4: QA Validation

**MANDATORY**: You MUST complete QA before creating a PR. This phase cannot be skipped.

### 4.1 Create QA checklist

Save `.develop-feature/[ticket-id]-qa.md`:

```markdown
# QA: [Ticket ID]

## Acceptance Criteria Validation
| Criterion | How to Verify | Status |
|-----------|---------------|--------|
| [Criterion 1] | [Steps] | ⏳ |
| [Criterion 2] | [Steps] | ⏳ |

## Functional Tests
| Test Case | Steps | Expected | Status |
|-----------|-------|----------|--------|
| Happy path | [steps] | [expected] | ⏳ |
| Edge case 1 | [steps] | [expected] | ⏳ |
| Error handling | [steps] | [expected] | ⏳ |

## Visual/UI (if applicable)
- [ ] Matches Figma design
- [ ] Responsive behavior
- [ ] Accessibility

## Code Quality
- [ ] All RSpec tests pass
- [ ] All Jest tests pass
- [ ] Rubocop clean (no offenses)
- [ ] ESLint clean (no errors)
- [ ] Brakeman clean (no security issues)
```

### 4.2 Execute QA - Automated Checks

Run these commands and record results:

```bash
# Run all affected RSpec tests
bin/docker/docker-runner bundle exec rspec [spec files]

# Run all affected Jest tests
bin/docker/docker-runner yarn jest [test files]

# Rubocop on changed files
bin/docker/docker-runner bundle exec rubocop [changed files]

# ESLint on changed files
bin/docker/docker-runner yarn eslint [changed files]

# Brakeman security scan
bin/docker/docker-runner bundle exec brakeman -q
```

### 4.3 Execute QA - Manual/E2E Validation

Use Playwright MCP for UI validation:

```
mcp__plugin_wealthbox_playwright__browser_navigate - Navigate to feature
mcp__plugin_wealthbox_playwright__browser_click - Test interactions
mcp__plugin_wealthbox_playwright__browser_take_screenshot - Capture results
mcp__plugin_wealthbox_playwright__browser_snapshot - Get page state
```

Use database queries to verify data:

```
mcp__plugin_wealthbox_db__execute_sql_crm - Verify data state
mcp__plugin_wealthbox_db__search_objects_crm - Find records
```

### 4.4 Update QA checklist with results

For each item, mark:
- ✅ PASS - Working as expected
- ❌ FAIL - Not working, needs fix
- ⚠️ PARTIAL - Partially working, minor issues

### 4.5 Evaluate QA results

**QA PASSED** requires ALL of:
- [ ] All acceptance criteria validated ✅
- [ ] All functional tests pass ✅
- [ ] All automated tests pass ✅
- [ ] All linters clean ✅
- [ ] No security issues ✅

**IF ANY FAILURES** (Dev→QA Loop):
```
┌─────────────────────────────────────────────────────┐
│  QA FAILED → Fix in Phase 3 → Re-run Phase 4       │
│  (Loop continues until ALL checks pass)            │
└─────────────────────────────────────────────────────┘
```

1. Document the failures in QA checklist with specific details
2. **Return to Phase 3** to fix each issue using TDD:
   - Write/update test that catches the failure
   - Implement the fix
   - Verify test passes
3. **Re-run ALL of Phase 4** from the beginning (4.1-4.5)
4. **Repeat this loop** until all checks pass

**DO NOT proceed to 4.6 (Code Review) until QA passes.**

### 4.6 Rails Architect Code Review (MANDATORY)

**AFTER QA passes but BEFORE creating PR**, spawn the **rails-architect agent** to review the actual code:

```
Task tool with subagent_type=rails-architect

Prompt: "Review the implementation for [feature name].

Changed files: [list all modified/created files]
Test files: [list all test files]

Review for:
1. Code quality and Rails best practices
2. Proper use of concerns, services, and abstractions
3. Database query efficiency (N+1, missing indexes)
4. Security considerations
5. Test coverage adequacy
6. Any code smells or technical debt

Provide specific feedback with file:line references for any issues."
```

**Address all rails-architect feedback** before proceeding. Fix any issues identified.

Save code review to `.develop-feature/[ticket-id]-code-review.md`:
```markdown
# Code Review: [Ticket ID]

## Reviewer
rails-architect agent

## Files Reviewed
- [file1]
- [file2]

## Issues Found
| File | Line | Issue | Severity | Status |
|------|------|-------|----------|--------|
| [file] | [line] | [issue] | [High/Med/Low] | ⏳ |

## Recommendations
- [Recommendation 1]
- [Recommendation 2]

## Changes Made
- [How feedback was addressed]

## Approval
✅ Code approved by rails-architect
```

**IF CODE REVIEW FINDS ISSUES** (Dev→Review Loop):
```
┌─────────────────────────────────────────────────────┐
│  Review Failed → Fix in Phase 3 → Re-run 4.6       │
│  (Loop continues until architect approves)         │
└─────────────────────────────────────────────────────┘
```

1. Document the issues in code review file
2. **Return to Phase 3** to fix each issue using TDD
3. **Re-run QA checks** (4.2-4.5) to ensure fixes don't break anything
4. **Re-run Code Review** (4.6)
5. **Repeat this loop** until rails-architect approves

**ALL issues must be resolved** before proceeding to user approval.

**USER APPROVAL GATE 3**: Present QA and code review results to user:
```
## QA & Code Review Complete

### QA Results Summary
- Acceptance Criteria: X/X passed ✅
- Functional Tests: X/X passed ✅
- Automated Tests: All passing ✅
- Code Quality Checks: Clean ✅

### Rails Architect Code Review
- Issues Found: X (all resolved ✅)
- Recommendations: Addressed ✅
- Approval: ✅ Code approved

Ready to create PR?
```

---

## Phase 5: Complete

**ONLY proceed here after QA PASSED in Phase 4.**

### 5.1 Final verification

```bash
# One final test run
bin/docker/docker-runner bundle exec rspec [all affected specs]
bin/docker/docker-runner yarn jest [all affected tests]
```

### 5.2 Create PR

```bash
gh pr create --title "[Ticket ID] [Description]" --body "$(cat <<'EOF'
## Summary
[What this PR does]

## Ticket
[Link to Linear/Basecamp/Trello]

## Changes
- [Key change 1]
- [Key change 2]

## Test Plan
- [How to verify]

## QA Results
- All acceptance criteria validated ✅
- All tests passing ✅
- Linters clean ✅

🤖 Generated with Claude Code
EOF
)"
```

### 5.3 Link back to ticket

Update the original ticket with PR link.

### 5.4 Summary output

```markdown
## Feature Complete: [Ticket ID]

### PRs Created
- [PR link]

### Test Coverage
- RSpec: [X] new tests
- Jest: [X] new tests

### Files Changed
- [count] files modified
- [count] files created

### QA Status
✅ All acceptance criteria validated
✅ All tests passing
✅ Code quality checks passed
```

---

## Enforcement Rules

### NEVER skip these steps:

1. **Phase 1**: Requirements must be documented and approved
2. **Phase 2**: Plan must be reviewed by rails-architect and approved by user
3. **Phase 3**: Tests MUST be written BEFORE implementation (TDD)
4. **Phase 4**: QA MUST pass AND rails-architect MUST approve code
5. **Phase 5**: PR only after Phase 4 fully passes

### MANDATORY Loops:

- **Dev→QA Loop**: If QA fails, return to Phase 3, fix, re-run Phase 4. Repeat until pass.
- **Dev→Review Loop**: If code review fails, return to Phase 3, fix, re-run 4.2-4.6. Repeat until pass.
- **NEVER proceed to Phase 5** until both QA and code review pass.

### If user says "skip tests", "skip QA", or "skip code review":

Respond: "The develop-feature workflow requires TDD, QA validation, and rails-architect code review. These ensure code quality and prevent regressions. I can proceed with a faster approach if you prefer, but it won't follow this skill's methodology. Would you like to continue with full TDD+QA+Review, or switch to a simpler implementation approach?"

### Anti-Patterns to REJECT:

1. ❌ Writing implementation before tests
2. ❌ Skipping the RED phase (test must fail first)
3. ❌ Creating PR before QA validation
4. ❌ Marking QA as "passed" without actually running checks
5. ❌ Ignoring failing tests or linter errors
6. ❌ Skipping rails-architect plan review
7. ❌ Skipping rails-architect code review
8. ❌ Proceeding after QA/review failure without fixing and re-running
9. ❌ Creating PR with unresolved code review issues
