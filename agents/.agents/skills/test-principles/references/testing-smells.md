# Testing smells and repairs

Use this as a diagnostic catalog. A smell is a prompt to ask what confidence the
test adds, not a reason to mechanically rewrite every test.

| Smell | What it usually means | Repair |
| --- | --- | --- |
| Tautological assertion | The test passes against a broken implementation | Introduce a defect mentally or mutate the implementation; assert a real outcome |
| Change detector | The test is coupled to a private name, call order, or data structure | Exercise the public contract and assert semantic results |
| Stub-then-assert | The test only proves the test double received its own programmed message | Assert the subject's outcome, or keep only a meaningful boundary side-effect assertion |
| Mock avalanche | The subject is coupled to too many owned collaborators | Use real collaborators, extract a boundary, or move the test up a level |
| Factory magic | The fixture's asserted value comes from an implicit default | Set the value explicitly in the example |
| Derived expectation | Production and test contain the same bug | Derive expected values from the requirement, an independently calculated example, or an invariant |
| Happy-path-only scope | A query returning everything would still pass | Add a record that must be excluded and use `contain_exactly` |
| Assertion duplication | A higher-level spec repeats a receiver's contract | Keep the receiver's test and assert only the sender's visible contribution |
| Fixture obesity | Setup is larger than the behavior under test | Delete setup one line at a time; keep only causal data |
| Mystery failure | The test name or assertion does not say what broke | Name the observable outcome and include the relevant context in the failure |
| Flaky test | Time, randomness, order, shared state, concurrency, or external systems leak into the result | Control the source, isolate state, and retain a small real-boundary test |

## Common tautologies

Do not use these as the only evidence of behavior:

```ruby
it { is_expected.to have_many(:students) }
it { expect(user).to respond_to(:full_name) }
it { expect(user).to callback(:send_welcome_email).after(:create) }
it { expect(user).to have_db_column(:email).of_type(:string) }
```

They can be light smoke coverage for plain framework declarations, but they do not
replace behavior tests when options or business consequences matter. For example,
test that archiving actually delivers or enqueues the mail, that a scoped query
excludes the wrong records, or that dependent records are actually handled as
promised.
