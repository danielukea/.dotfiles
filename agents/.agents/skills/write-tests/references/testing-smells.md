# Testing smells

Not a gate to run — signals that a test may be low-value. When one shows up, reconsider:

- Would this test still pass if the method returned `nil`? (tautology)
- Does it assert an internal call count instead of an observable outcome?
- Is the expected value copied from the implementation rather than derived from the spec?
- Is this assertion already owned by the receiver's own spec? (redundant coupling)
- Missing a "should not" case for a scope, filter, or validation?
- Would it break if you renamed an internal private method? (change-detector)
- Is every `let`/`before` line causally necessary, or would the test pass without it?
- Is the failure message uninformative?
- Request spec asserting status but not body shape (or vice versa)?
