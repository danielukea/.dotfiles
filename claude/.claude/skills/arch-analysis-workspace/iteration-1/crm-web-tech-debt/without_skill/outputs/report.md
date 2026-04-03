# Tech Debt Audit: crm-web

**Date**: 2026-04-02
**Codebase**: Wealthbox CRM (`crm-web`)
**Stack**: Rails 7.2 / Ruby 3.2.4 / React 18 / TypeScript / Angular (deprecated) / PostgreSQL
**Scale**: ~1.37M lines of code, 507 migrations, 231 gems, 201 npm dependencies

---

## Executive Summary

The crm-web codebase is a mature, large-scale Rails + JavaScript CRM application undergoing an active Angular-to-React migration. The codebase has strong conventions documented via CLAUDE.md, ADRs, and coding guidelines. However, several categories of tech debt are present: an incomplete frontend framework migration, multiple overlapping build/template/library systems, god objects in the model layer, and a significant volume of linting suppressions. The team is clearly aware of many of these issues and has documented them, but the aggregate weight is significant.

---

## 1. Angular-to-React Migration (HIGH priority)

**Status**: Angular is officially deprecated per project policy, but ~197 Angular files remain in `app/javascript/angular/`. The modern React codebase has ~1,169 TSX files and growing. There are 25 files using `react2angular` as a bridge layer with 55 bridge call sites.

**Key concerns**:
- The Angular code has been present since February 2019 (7+ years)
- The `react2angular` bridge bypasses the centralized `ReactRootManager`, meaning Angular-hosted React roots are invisible to cleanup during Turbolinks navigation (documented as HIGH in SUGGESTIONS.md)
- Angular dependencies remain in `package.json` (angular, angular-classy, angular-media-queries, angular-resource, angular-sanitize, angularjs-rails-resource)
- Angular types are still listed in `tsconfig.json`
- The `app/javascript/angular/components/workflows/` directory has the most bridge usage, suggesting workflows is the largest remaining Angular surface

**Recommendation**: Create a tracking board for remaining Angular components. Prioritize workflow components since they have the most bridge complexity. Remove Angular npm dependencies as components are migrated.

---

## 2. God Objects in the Model Layer (HIGH priority)

Several models are excessively large and carry too many responsibilities:

| Model | Lines | Concerns Mixed In |
|-------|-------|--------------------|
| User | 804 | 22+ includes |
| Subscription | 734 | - |
| Account | 699 | - |
| LoginProfile | 682 | - |
| Meeting | 626 | - |
| Import | 606 | - |
| Contact | 462 | - |

The `User` model is the most extreme case with 22+ concern includes covering integrations (Blueleaf, Capitect, Nylas, Google Calendar, Outlook Calendar), permissions, feature flags, admin filters, notifications, and more. The CLAUDE.md itself has a lengthy special-purpose rule just for `User` scoping because the model's state machine is so complex.

There are 216 model concerns total, indicating heavy use of the concern pattern to manage god objects rather than decomposing them.

**Recommendation**: Extract integration-specific behavior from User into dedicated service objects. Consider the Command pattern (already used in `app/lib/`) more aggressively for business logic that currently lives in model callbacks and concerns.

---

## 3. Multiple Frontend Paradigms (MEDIUM-HIGH priority)

The frontend has accumulated multiple overlapping technology layers:

**JavaScript frameworks** (3 active):
- Angular 1.x (deprecated, 197 files)
- React 18 (primary, 1,169+ TSX files)
- jQuery (452 `$()` calls across JavaScript files)

**Template engines** (3 active):
- Slim (1,415 views - primary)
- ERB (48 views)
- Handlebars (16 templates, with `handlebars_assets` gem still in Gemfile)

**CSS approaches** (3 active):
- SCSS (244 files via asset pipeline)
- Tailwind CSS 4 (configured, growing)
- CSS (4 files)

**Build tools** (4 configs):
- `esbuild.js` - primary JS bundler
- `babel.config.js` - transpilation
- `scss.js` - SCSS compilation
- `postcss.config.js` - CSS processing

**Utility libraries** (overlapping):
- Both `lodash` AND `underscore` are dependencies
- `moment.js` (108 imports) - maintenance-mode library, 70KB+

**Recommendation**: Prioritize removing jQuery as components are migrated to React. Replace moment.js with `date-fns` or native `Intl` APIs. Remove underscore in favor of lodash (or native JS). Remove Handlebars templates and the `handlebars_assets` gem.

---

## 4. Linting Suppressions (MEDIUM priority)

The codebase has a high volume of linting suppressions that mask code quality issues:

| Type | Count |
|------|-------|
| `rubocop:disable` / `rubocop:todo` | 1,676 |
| TypeScript `any` types | 389 |
| `eslint-disable` comments | 89 |
| `TODO` comments | 166 |
| `FIXME` comments | 1 |

1,676 Rubocop suppressions is a significant number. Each one represents a known deviation from the team's style and safety rules. The 389 `any` type usages undermine TypeScript's value, especially given that `strict` mode is not fully enabled (only `strictNullChecks` is on).

**Recommendation**: Run a triage pass on rubocop suppressions - categorize by cop name and batch-fix the easy ones (frozen string literal, line length). Enable TypeScript `strict: true` incrementally. Set a team goal to reduce `any` usage by 50%.

---

## 5. Legacy Serialization (MEDIUM priority)

The project uses `active_model_serializers ~> 0.8`, which is an unmaintained major version (current is 0.10.x, and even that has been effectively abandoned). There are **351 serializer files** in `app/serializers/`.

AMS 0.8 predates the JSON:API standard, has known performance issues, and receives no security patches.

**Recommendation**: For new endpoints, use Rails' built-in `render json:` with explicit hash construction or a modern serializer like `jsonapi-serializer` or `alba`. Plan a gradual migration for existing serializers.

---

## 6. Raw SQL and Query Safety (MEDIUM priority)

- **239 string-based `.where()` clauses** - these can be SQL injection vectors if interpolating user input
- **149 raw SQL calls** (`find_by_sql`, `execute`, `exec_query`) - harder to maintain and audit

While the CLAUDE.md mandates OWASP Top Ten compliance, the volume of string-based where clauses warrants a targeted security audit.

**Recommendation**: Grep for string interpolation inside `.where()` calls and prioritize converting any that use user input to parameterized queries. Use `Arel` or hash-based conditions where possible.

---

## 7. Test Coverage Gaps (MEDIUM priority)

| Layer | Source Files | Test Files | Ratio |
|-------|-------------|------------|-------|
| Ruby | 4,827 | 3,651 | 75.6% |
| JavaScript/TypeScript | 1,987 | 797 | 40.1% |

Frontend test coverage at 40% file-level ratio is low, especially during an active migration. Additionally:
- 59 feature specs exist despite the CLAUDE.md explicitly discouraging them ("slow, flaky, expensive to maintain")
- `jest.retryTimes(2)` globally masks flaky tests
- The `userEvent.setup()` migration is incomplete (343 occurrences of direct calls remain)

**Recommendation**: Increase JS/TS test coverage, prioritizing the react2angular bridge layer and new React components. Remove or convert feature specs to request + unit spec combinations. Address the `jest.retryTimes` masking issue.

---

## 8. Soft Delete via acts_as_paranoid (LOW-MEDIUM priority)

The `acts_as_paranoid` gem implements soft deletes globally. This adds hidden complexity to every query (default scopes filter deleted records), makes joins unpredictable, and has caused subtle bugs in many Rails projects.

**Recommendation**: For new models, use explicit `discarded_at` with `discard` gem or a simple concern. Don't extend acts_as_paranoid to new models.

---

## 9. ADR Numbering Conflict (LOW priority)

There are two ADRs numbered `0010`:
- `0010_hardcoded-activesync-suffix-for-eas-host-detection.md`
- `0010_optimize-newrelic-costs-through-sampling.md`

This breaks the CLAUDE.md rule that "newer ADRs supersede older ones" based on index number.

**Recommendation**: Renumber one to `0014` (next available).

---

## 10. Dependency Count (LOW priority)

- **231 gems** in Gemfile
- **103 production npm dependencies** + 98 devDependencies

This is a high dependency count that increases supply chain risk, build times, and maintenance burden. Notable legacy dependencies:
- `handlebars_assets` - only 16 templates remain
- `angular` and related packages - deprecated
- `underscore` - duplicates lodash functionality
- `active_model_serializers 0.8` - unmaintained

**Recommendation**: Audit gems with `bundle outdated` and npm packages with `yarn outdated`. Remove unused dependencies, particularly the Angular and Handlebars packages once their usage reaches zero.

---

## Summary of Priorities

| Priority | Area | Effort | Impact |
|----------|------|--------|--------|
| HIGH | Angular migration completion | Large | Reduces dual-framework complexity |
| HIGH | God object decomposition (User, Account, Subscription) | Large | Improves maintainability and testability |
| MEDIUM-HIGH | jQuery removal | Medium | Eliminates a framework layer |
| MEDIUM | Rubocop/TypeScript lint suppression triage | Medium | Improves code quality baseline |
| MEDIUM | Serializer modernization | Large | Security and performance |
| MEDIUM | Raw SQL audit | Small | Security |
| MEDIUM | Frontend test coverage | Ongoing | Reduces regression risk |
| LOW-MEDIUM | acts_as_paranoid containment | Small | Prevents spread of complexity |
| LOW | Duplicate library removal (underscore, moment) | Small | Reduces bundle size |
| LOW | ADR numbering fix | Trivial | Consistency |

---

## Existing Documentation

The team has already documented several of these issues:
- `NICE_TO_HAVE.md` - React 18 migration follow-ups (5 items)
- `SUGGESTIONS.md` - Detailed code review findings (7 HIGH, 22 MEDIUM, 11 LOW)
- `docs/decisions/` - 14 ADRs covering architectural choices
- `CLAUDE.md` - Comprehensive coding standards and rules

This audit complements the existing documentation by providing a higher-level, cross-cutting view of systemic tech debt rather than per-PR findings.
