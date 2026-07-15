# Sources and provenance

This skill is a practical synthesis, not a claim that the industry has one
universal testing formula. The sources below are the main influences and are useful
for resolving tradeoffs:

- [Kent Beck, *Test-Driven Development: By Example*](https://www.pearson.com/en-us/subject-catalog/p/test-driven-development-by-example/P200000009421/9780321146533) — short feedback loops, test-first design, and incremental behavior.
- [Martin Fowler, “Mocks Aren't Stubs”](https://martinfowler.com/articles/mocksArentStubs.html) — classicist versus mockist testing, interaction-based design, and test doubles.
- [Martin Fowler, “The Practical Test Pyramid”](https://martinfowler.com/articles/practical-test-pyramid.html) and [“Test Pyramid”](https://martinfowler.com/bliki/TestPyramid.html) — multiple test granularities, cost/feedback tradeoffs, and avoiding redundant higher-level coverage.
- [Gerard Meszaros, xUnit Test Patterns](https://xunitpatterns.com/) — test organization, test doubles, maintainability patterns, and test smells.
- [Kent C. Dodds, “The Testing Trophy and Testing Classifications”](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications) — why test distribution should optimize confidence and return on investment rather than follow a rigid shape.
- [Matt Pocock, TDD skill](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md), [good and bad tests](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/tests.md), and [mocking guidance](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/mocking.md) — concise seam-first rules, tautology examples, and system-boundary mocking.
- [Google Testing Blog, “Test Sizes”](https://testing.googleblog.com/2010/12/test-sizes.html) — the practical role of small, medium, and large tests and the cost of broad tests.
- [RSpec, “Verifying doubles”](https://rspec.info/features/3-12/rspec-mocks/verifying-doubles/) — prefer doubles that check the interface they stand in for.
- [Ruby on Rails Guides, “Testing Rails Applications”](https://guides.rubyonrails.org/testing.html) — Rails test levels, integration workflows, system-test tradeoffs, jobs, and request behavior.
- [Michael Feathers, “Testing Warranties”](https://michaelfeathers.silvrback.com/testing-warranties) — public interfaces, seams, and using testability pressure as design information.
