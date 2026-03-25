Create a step-by-step refactoring plan for the Event model at app/models/event.rb in ~/Workspace/crm-web.

Read the full file. The model has 16 concerns, a state machine, complex validations, and repeating event logic.

Goal: improve the separation of concerns without changing external behavior. Specifically:
- Identify concerns that are doing too much or overlapping
- Propose how to reorganize concern boundaries
- Address the conditional validation logic (import vs. regular saves)

Constraints:
- Each step must be independently deployable (no big-bang refactors)
- Each step must include what tests to run/write to verify no regression
- Steps must be ordered so earlier ones don't depend on later ones
- Do NOT introduce service objects unless you can argue through the alternatives first

Output a numbered plan with checkboxes.
