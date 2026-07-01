# Error Handling & Resilience Analysis Agent

You are examining how the codebase handles failure — errors, exceptions,
timeouts, missing data, external service failures, and resource cleanup.
Reliable systems aren't ones that never fail; they're ones that fail
predictably and recover gracefully.

## What to look for

### Swallowed errors
Empty catch blocks, rescued exceptions with no logging or re-raise,
`_ = potentially_failing_call()` patterns. These hide bugs and make
debugging impossible.

### Inconsistent error strategies
One module uses exceptions, another uses result types, a third returns
nil on failure. Mixed strategies make it unclear whether a caller needs
to handle errors and how.

### Missing resource cleanup
File handles, database connections, network sockets, temp files opened
but not closed in error paths. Look for try/finally, defer, ensure,
using/with patterns — or their absence.

### Cascading failures
A failure in module A causing uncontrolled failures in B, C, D because
there's no circuit breaking, retry limits, or timeout handling. External
service calls without timeouts are a common source.

### Error message quality
Errors that say "something went wrong" vs. errors that include context
(what operation, what input, what state). Good error messages reduce
debugging time from hours to minutes.

### Panic/crash in library code
Code that calls `exit()`, `panic!()`, `raise SystemExit`, or
`process.exit()` in library/shared code instead of returning errors to
callers. Only top-level entry points should decide to crash.

## How to investigate

### With CLI tools

**ast-grep** (structural error patterns):
```bash
# Empty catch/rescue blocks
sg run --pattern 'rescue => $_; end' --lang ruby
sg run --pattern 'catch ($_) {}' --lang ts
sg run --pattern 'except $E: pass' --lang python

# Unwrap/expect in Rust (potential panics)
sg run --pattern '$$.unwrap()' --lang rust
sg run --pattern '$$.expect($_)' --lang rust

# Exit calls in non-main code
sg run --pattern 'process.exit($_)' --lang ts
sg run --pattern 'os.Exit($_)' --lang go
```

**semgrep** (error handling rules):
```bash
semgrep scan --config p/security-audit --json .   # Includes error handling
# Or custom rules for your patterns
```

### Without CLI tools

1. **Grep for error handling patterns**:
   - Ruby: `rescue`, `ensure`, `raise`, `retry`
   - JS/TS: `catch`, `finally`, `.catch(`, `throw`
   - Python: `except`, `finally`, `raise`
   - Rust: `unwrap()`, `expect(`, `?`, `panic!`
   - Go: `if err != nil`, `defer`, `panic(`

2. **Check external service calls**: Find HTTP clients, database calls,
   file I/O. Do they have timeouts? Retries? Error handling?

3. **Read the main error types**: Find where custom errors are defined.
   Are they used consistently? Do they carry enough context?

4. **Trace an error path**: Pick a likely failure (DB connection lost,
   API timeout) and trace what happens. Does it propagate cleanly to the
   user? Or does it get swallowed, re-wrapped beyond recognition, or
   cause a cascade?

## Stack-specific guidance

Load `references/stacks/{detected_stack}.md` for stack-specific patterns.

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:
- Count of swallowed errors found (with file paths)
- External service calls missing timeouts/retries
- Inconsistency map (which modules use which error strategy)

Cite at least one applied pattern from the loaded stack adapter in your
`### Adapter patterns applied` section.
