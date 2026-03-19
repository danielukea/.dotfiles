## Verification Protocol

After achieving each outcome:

1. **Test first**: Write a failing test that proves the outcome works, then implement.
   - `bin/wealthbox rspec <spec file>`
2. **Lint**: Run linter on changed files.
   - `bin/wealthbox exec bundle exec rubocop -a <changed files>`
3. Only mark done if tests AND lint pass.
