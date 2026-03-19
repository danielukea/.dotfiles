# Quality Checklists, Anti-Patterns, and Agent Integration Reference

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
| 7 | `code-architect` | Architectural gap analysis |
| 8 | `code-architect` | System design |
| 8 | `rails-architect` | Backend patterns (Rails) |
| 9 | `code-architect` | Validate slice decomposition |
