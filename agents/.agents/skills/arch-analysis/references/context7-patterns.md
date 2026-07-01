# Context7 references for refactoring strategies

## Context7 References for Refactoring Strategies

When generating the **Direction** for findings or building Phase 4 plans, use
context7 to fetch current documentation on relevant refactoring patterns. This
grounds suggestions in established techniques with code examples.

### Available libraries

| Library ID | Content | Use for |
|------------|---------|---------|
| `/websites/refactoring_guru` | Extensive refactoring techniques catalog + code smells | Tactical refactoring suggestions (Extract Method, Move Function, etc.) |
| `/websites/refactoring_guru_design-patterns` | GoF design patterns with multi-language examples | Adapter, Facade, Strategy patterns for ACL, Strangler Fig, Branch by Abstraction |
| `/websites/sourcemaking_refactoring` | Code smells + refactoring techniques with interactive examples | Alternative explanations when refactoring_guru results aren't sufficient |
| `/websites/refactoring_guru_smells` | Code smell definitions and categories | Naming specific smells when citing evidence |
| `/sairyss/domain-driven-hexagon` | DDD + Hexagonal Architecture patterns | Anti-Corruption Layer, bounded contexts, enforcing architectural boundaries |

### When to query

- **Coupling findings** → query design patterns (Adapter, Facade, Mediator) and
  DDD hexagon (bounded contexts, ACL)
- **Complexity findings** → query refactoring smells (Long Method, God Class,
  Feature Envy) for naming, then techniques for resolution
- **State & Data Flow findings** → query DDD hexagon for aggregate boundaries
  and consistency patterns; query design patterns for Observer, Mediator
- **Duplication findings** → query refactoring techniques (Extract Method,
  Extract Class, Pull Up Method)
- **Error Handling findings** → query refactoring techniques (Replace Error
  Code with Exception, Replace Exception with Test) and design patterns
  (Strategy for error recovery, Chain of Responsibility for error propagation)
- **Structure findings** → query DDD hexagon for layer enforcement patterns
- **Extensibility / Variation findings** → query design patterns (Strategy,
  Template Method, Plugin, Registry, Factory)
- **Vertical Slicing findings** → query DDD hexagon for bounded contexts;
  cite Strangler Fig and Branch by Abstraction for incremental slicing
- **Contract Surface findings** → query Adapter, Facade, ACL; cite
  Parallel Change (Expand-Contract) for breaking-change rollouts

### Not in context7 (reference from web/books)

These strategic patterns aren't available as context7 libraries — cite them
by name and link when relevant:

- **Strangler Fig** — [martinfowler.com/bliki/StranglerFigApplication.html](https://martinfowler.com/bliki/StranglerFigApplication.html)
- **Branch by Abstraction** — [martinfowler.com/bliki/BranchByAbstraction.html](https://martinfowler.com/bliki/BranchByAbstraction.html)
- **Mikado Method** — [mikadomethod.info](https://mikadomethod.info/)
- **Parallel Change (Expand-Contract)** — [martinfowler.com/bliki/ParallelChange.html](https://martinfowler.com/bliki/ParallelChange.html)
- **Modular Monolith** — [shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity](https://shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity)
- **Vertical Slice Architecture** — Jimmy Bogard
- **Connascence** — [connascence.io](https://connascence.io/); Page-Jones, *What Every Programmer Should Know About OO Design* (1995)
- **The Pragmatic Programmer** — Hunt & Thomas, 20th anniversary ed. (2019)
- **Seam-based refactoring** — *Working Effectively with Legacy Code* (Feathers, 2004)
- **Evolutionary Architecture** — *Building Evolutionary Architectures* (Ford, Parsons, Kua, 2nd ed. 2023)
