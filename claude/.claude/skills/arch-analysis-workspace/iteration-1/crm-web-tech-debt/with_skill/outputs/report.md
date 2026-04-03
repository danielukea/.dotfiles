# Architectural Analysis: crm-web

## Stack & Size

| Attribute | Value |
|-----------|-------|
| **Primary stack** | Ruby on Rails (Ruby 3.2.4) + React (TypeScript) |
| **Legacy stack** | Angular (deprecated, migration in progress) |
| **Source files** | ~106,000 |
| **Git commits** | ~81,500 |
| **Ruby files (app/lib)** | ~2,930 (649 models, 493 controllers, 351 serializers, 328 jobs, 133 presenters) |
| **JS/TS files** | ~1,987 (1,169 React .tsx/.jsx, 336 Angular legacy) |
| **Admin panel files** | 132 ActiveAdmin resources |
| **Available analysis tools** | rubocop, brakeman |

---

## What's Working Well

- **Test co-location with source**: Temporal coupling data shows spec files consistently changing alongside their source (e.g., `meetings_controller.rb` + `meetings_controller_spec.rb`, `custom_object.rb` + `custom_object_spec.rb`). This signals a healthy test culture where tests are updated with code changes.
- **Layered app directory**: The `app/` directory has clear subdirectories for models, controllers, serializers, presenters, decorators, queries, validators, jobs, and policies. These represent well-understood Rails architectural layers.
- **Query objects pattern adopted**: 36 dedicated query objects in `app/queries/` show an intentional move to extract complex queries from models.
- **Feature flag management**: `app/lib/feature_whitelist.rb` (489 lines, high churn) centralizes feature gating, indicating conscious rollout control.
- **Composer module structure**: The AI/Composer module (`app/lib/composer/`, 203 files) is well-organized with tool-per-resource patterns under `tools/crm/`, clear separation of concerns (tools, chats, tool_approvals), and a LEARNINGS.md capturing team knowledge.
- **React migration progress**: 1,169 React components vs. 336 Angular files shows the Angular deprecation is well underway (~77% migrated by file count).

---

## Top Findings (ranked by impact)

### 1. God Models: Account, User, Subscription, LoginProfile

**Category**: Architecture & Coupling  |  **Severity**: high
**Flagged by**: Coupling, Complexity & Churn, State & Data Flow
**Evidence**:
- `Account` model: 699 lines, **116 associations** (has_many/has_one/belongs_to), 16+ includes/concerns
- `User` model: 804 lines, **65 associations**, 20+ includes/concerns
- `Subscription` model: 734 lines, 62 associations
- `LoginProfile` model: 682 lines, 43 associations
- `Account` has 5 memoization patterns; heavy callback chains including `after_create :generate_subscription, :setup_user_permission_for_stream_item_query, :add_custom_object_types`

**Impact**: Every new feature that touches users or accounts risks unintended side effects through callbacks and association chains. The 116 associations on Account mean virtually any change to a domain model could affect Account's behavior. This is the single largest coupling risk in the codebase.

**Direction**: Extract bounded contexts. Start with the most independent association clusters -- financial integrations (Capitect, Orion, Tamarac, etc.) could become an `Integrations` module with a thin interface to Account. Consider the "strangler fig" approach: new code references extracted modules, old associations stay until migrated.

---

### 2. Meetings Domain: High Churn + High Complexity Hotspot

**Category**: Code Health & Complexity  |  **Severity**: high
**Flagged by**: Complexity & Churn, Coupling, Structure & Conventions
**Evidence**:
- `meetings_controller.rb`: 637 lines, **65 changes in 6 months** (2nd most-changed app file), 16 CRUD actions
- `meeting.rb`: 626 lines, **68 changes in 6 months**, 19 associations
- Temporal coupling: controller + spec always change together (20 co-changes)
- This is the classic hotspot: high complexity x high churn = bug factory

**Impact**: The meetings domain is where active development is concentrated. Its size makes every change risky and review-intensive. New developers working on meetings must understand 1,263 lines across just two files before making changes.

**Direction**: Extract meeting-specific logic into service objects or form models. The controller likely has actions that could be split into a `Meetings::RecurrenceController`, `Meetings::NotesController`, etc. The model's 19 associations and callbacks should be split into concerns with clear responsibilities.

---

### 3. External HTTP Calls Without Timeouts or Consistent Error Handling

**Category**: Reliability & Error Handling  |  **Severity**: high
**Flagged by**: Error Handling & Resilience, Coupling
**Evidence**:
- 15+ HTTParty calls in models (`capitect/api_integration.rb`, `advice_pay/api_integration.rb`, `slack/notification.rb`, `mailchimp_integration.rb`, etc.) with **no explicit timeout configuration**
- `Net::HTTP` used directly in `constant_contact_integration.rb` and `mailchimp_integration.rb` without timeout
- 20+ `rescue StandardError => e` blocks (overly broad catches) across integrations
- Integration models handle HTTP, parsing, error handling, and business logic all in one class

**Impact**: A slow or unresponsive external service (Capitect, AdvicePay, Slack, Mailchimp, etc.) will block a Rails thread indefinitely. Under load, this can exhaust the thread pool and cause cascading failures across the entire application. The broad `rescue StandardError` patterns mask the real error, making production debugging difficult.

**Direction**: Introduce a shared HTTP client wrapper with default timeouts (e.g., 10s connect, 30s read), circuit breaking, and structured error responses. Consider a `BaseApiIntegration` concern or module that all integration models include. This also creates a single place to add observability (request logging, latency metrics).

---

### 4. Angular Legacy Code Still Actively Referenced

**Category**: Maintainability & Conventions  |  **Severity**: high
**Flagged by**: Structure & Conventions, Duplication & Patterns
**Evidence**:
- 336 Angular/legacy JS files still present in `app/assets/javascripts/` and `app/javascript/angular/`
- `app/assets/javascripts/env/routes.js.erb` is the **4th most-changed file** (54 changes in 6 months) and changes alongside `config/routes/tenant.rb` 35 times -- every new route requires updating this Angular route map
- `react2angular` bridge code exists in `app/javascript/vendor/react2angular`
- Angular-specific files like `angular_dialog.ts`, `angular_sortable.js`, `angular_helpers.ts` remain

**Impact**: The Angular route map (`routes.js.erb`) creates forced coupling: every route change requires touching this file, adding friction to every feature that adds endpoints. The 336 remaining Angular files represent ~17% of the frontend codebase that cannot benefit from modern React tooling, testing patterns, or component reuse.

**Direction**: Prioritize migrating the Angular route consumption to use the same mechanism React uses. Identify the 10 most-changed Angular files and prioritize their conversion. Track Angular file count as a metric to make migration progress visible.

---

### 5. Admin Panel Files Are Oversized and Monolithic

**Category**: Code Health & Complexity  |  **Severity**: medium
**Flagged by**: Complexity & Churn, Structure & Conventions
**Evidence**:
- `app/admin/subscriptions.rb`: **1,030 lines**, 39 changes in 6 months
- `app/admin/login_profiles.rb`: 953 lines
- `app/admin/imports.rb`: 831 lines
- `app/admin/accounts.rb`: 799 lines
- Total: 132 admin files, 16,486 lines of admin configuration code

**Impact**: ActiveAdmin DSL files at this size become difficult to modify safely. At 1,030 lines, `subscriptions.rb` is likely mixing display logic, custom actions, CSV exports, scopes, and form definitions in one file. Changes risk breaking unrelated admin functionality.

**Direction**: Split large admin files using ActiveAdmin's support for partial registration. Extract custom member/collection actions into dedicated admin concern modules. Consider whether complex admin workflows (import management, subscription billing) would be better served by dedicated internal tools.

---

### 6. Sidekiq Jobs Missing Explicit Retry Configuration

**Category**: Reliability & Error Handling  |  **Severity**: medium
**Flagged by**: Error Handling & Resilience
**Evidence**:
- 20+ job files lack `sidekiq_options` entirely, including data-sensitive jobs like:
  - `data_import_job.rb` -- processes user data imports
  - `contacts_export_job.rb` -- exports contact data
  - `account_export_job.rb` -- exports account data
  - `undo_data_import_job.rb` -- reverses imports
- Without explicit config, Sidekiq defaults to **25 retries over ~21 days**
- Contrast with jobs that explicitly set `retry: false` (e.g., `constant_contact_batch_contacts_send_job.rb`) showing awareness of the need

**Impact**: An import or export job that fails due to a transient error will retry 25 times. If the error produces side effects (partial writes, duplicate records), the retries compound the damage. Export jobs may generate incomplete files on each retry attempt.

**Direction**: Audit all jobs in `app/jobs/` and add explicit `sidekiq_options` with appropriate retry counts. Data mutation jobs should generally have `retry: false` or `retry: 1` with idempotency guards. Read-only/export jobs can safely retry 2-3 times.

---

### 7. Feature Whitelist as a Growing Monolith

**Category**: Maintainability & Conventions  |  **Severity**: medium
**Flagged by**: Complexity & Churn, Structure & Conventions
**Evidence**:
- `app/lib/feature_whitelist.rb`: 489 lines, **44 changes in 6 months**
- High churn indicates every new feature adds entries here
- File co-changes with its spec (23 times) confirm constant modification
- Single file managing all feature flags for the entire application

**Impact**: As the single source of truth for feature flags, this file becomes a merge conflict magnet when multiple developers work on features simultaneously. Its size makes it hard to audit which flags are still active vs. stale.

**Direction**: Consider a feature flag service or database-backed approach that doesn't require code changes to toggle features. In the short term, split the file by domain (e.g., `feature_whitelist/meetings.rb`, `feature_whitelist/composer.rb`) to reduce merge conflicts.

---

### 8. Model Callbacks Creating Hidden Data Flow

**Category**: Data Integrity & State  |  **Severity**: medium
**Flagged by**: State & Data Flow, Coupling
**Evidence**:
- 30+ `before_save`, `after_save`, `after_commit`, `before_validation` callbacks across core models
- `Account` model chains: `after_create :generate_subscription, :setup_user_permission_for_stream_item_query, :add_custom_object_types`
- `Contact` model: `after_save :destroy_fully_old_organization_link, if: :saved_change_to_organization_id?`
- `Tag` model: `after_commit :touch_documents`, `after_commit :sync_note_template_tag`
- Callbacks trigger cross-model side effects that are invisible to callers

**Impact**: Callbacks make it impossible to save a model without triggering all side effects. This prevents lightweight operations (e.g., updating just a name field on Account triggers subscription and permission setup logic). It also makes testing harder -- you must account for callback side effects in every test.

**Direction**: Migrate callbacks to explicit service objects. Instead of `after_create :generate_subscription`, have `AccountCreationService` call `SubscriptionGenerator` explicitly. This makes the data flow visible and testable in isolation.

---

## Lower Priority

### Maintainability & Conventions
- **God concerns**: `TenantManager` is included in 93 classes, `SoftDestroyable` in 80, `Permission` in 25, `DateTimeFieldsValidatable` in 24. These concerns are so widely used that changes to them have enormous blast radius. TenantManager in particular is a hidden coupling vector -- every model depends on it.
- **Serializer proliferation**: 134 serializers with some having 30+ methods (`todo_serializer.rb` has 31). Consider whether serializers are doing too much transformation vs. just serialization.
- **Presenter/Decorator overlap**: 133 presenters and 51 decorators -- two patterns for the same purpose (view-layer data formatting). Consolidate on one pattern.
- **Only 2 service objects**: `app/services/` contains just 2 files (`meetings/backfill_from_events.rb`, `reports/report_context.rb`). Business logic lives primarily in models and controllers rather than dedicated service objects. The team uses `app/lib/` extensively (2,281 files) as an alternative.

### Code Health & Complexity
- **Large demo account seed files**: `demo_accounts/files/meetings.rb` (1,723 lines), `dashboards.rb` (1,513 lines). These are data fixtures but their size suggests they could be generated from schemas or YAML.
- **ApplicationHelper at 554 lines**: Global helper methods should be split into domain-specific helpers.
- **Custom Objects domain high churn**: 194 files, 38 model changes in 3 months -- this is an actively evolving area that would benefit from architectural stabilization.

### Architecture & Coupling
- **184 controllers**: Large number suggests fine-grained routing but also potentially too many entry points. Some controller subdirectories (settings/, organization_workspace/) provide grouping.
- **Routes file churn**: `config/routes/tenant.rb` changed 77 times in 6 months (3rd most-changed app file), always coupled with `routes.js.erb` and `setup_rails_env.js`.

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Ruby files in app/ | ~2,930 |
| JS/TS files | ~1,987 |
| Angular files remaining | 336 (~17% of frontend) |
| React components | 1,169 |
| Models > 500 lines | 7 (User, Account, Subscription, LoginProfile, Meeting, Import, Contact) |
| Controllers > 500 lines | 1 (MeetingsController at 637) |
| Admin files > 500 lines | 4 (subscriptions, login_profiles, imports, accounts) |
| Largest TSX component | 930 lines (OrganizationSettingsCustomObjectLayoutEditor) |
| Serializers | 134 |
| Background jobs | 328 |
| Jobs missing retry config | 20+ |
| HTTParty calls without timeout | 15+ |
| ActiveRecord callbacks in models | 30+ |
| `rescue StandardError` occurrences | 20+ |
| Most-changed file (6 months) | db/structure.sql (203), config/locales/en.yml (123) |
| Most-changed app file | spec/javascript/jest_config/setup_rails_env.js (100) |
| Highest association count | Account (116), User (65), Subscription (62) |
| Most-included concern | TenantManager (93 classes), SoftDestroyable (80), Permission (25) |
