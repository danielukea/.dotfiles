# Architectural Analysis: crm-web (Wealthbox CRM)

## Stack & Size

| Dimension | Value |
|-----------|-------|
| **Framework** | Rails 7.2, React + TypeScript (migrating from Angular) |
| **Languages** | Ruby (20,777 files / 1.49M LoC), TypeScript (6,086 files / 583K LoC), JavaScript (647 files / 134K LoC) |
| **Database** | PostgreSQL (via ActiveRecord), OpenSearch |
| **Background Jobs** | SolidQueue (previously Sidekiq) |
| **Key Infrastructure** | AWS (S3, SQS, Bedrock, Lambda), AnyCable, Devise, Doorkeeper, Flipper |
| **Git History** | 82,134 commits |
| **Angular-React Migration** | 112 Angular files remain; 1,863 React/TS files; 25 react2angular bridge points |

### CLI Tools Used

| Tool | Status | Data Collected |
|------|--------|---------------|
| **scc** | Available | Per-file complexity, language breakdown |
| **skunk** | Available | StinkScore (complexity x coverage) for hotspot files |
| **brakeman** | Available | 50 security warnings (30 SQL injection, 9 dynamic render) |
| **jscpd** | Available | 158 JS/TS clones, 61 Ruby lib clones, 24 Composer clones |
| **ast-grep** | Available | Structural pattern searches for error handling |
| **rubocop** | Available | Linting (integrated in project workflow) |
| **dep-tree** | Available | Entropy check attempted (not configured for this project) |

---

## What's Working Well

- **Clear architectural direction**: CLAUDE.md documents Angular deprecation policy, feature gating patterns, LLM integration patterns, and import system docs. New developers have strong guardrails.
- **Feature-organized frontend**: `app/javascript/` is organized by domain (meetings, contacts, workflows, ai_assistant, files, etc.) rather than by technical layer. This promotes co-location and team ownership.
- **Mature dev tooling**: `bin/wealthbox` wrapper abstracts Docker/native mode, RSpec routing, and rubocop. CI via Semaphore with clear debugging workflow documented.
- **Strong Composer (AI) architecture**: The 214-file `app/lib/composer/` subsystem is well-organized into tools, chats, and approvals with clear separation of concerns.
- **Active modernization**: Recent 6-month churn shows heavy investment in meetings, custom objects, AI assistant, and file storage -- all in React/TypeScript, consistent with the migration direction.

---

## Top Findings (ranked by impact)

### 1. God Models with Extreme StinkScores

**Category**: Code Health & Complexity | **Severity**: high
**Flagged by**: Complexity & Churn, Coupling, Structure

**Evidence** (skunk output):

| File | StinkScore | Churn x Cost | Lines | Associations |
|------|-----------|-------------|-------|-------------|
| `app/controllers/meetings_controller.rb` | 2,566 | 108,685 | 637 | - |
| `app/models/user.rb` | 2,171 | 106,456 | 814 | 66 |
| `app/models/subscription.rb` | 2,104 | 93,800 | 735 | 63 |
| `app/models/account.rb` | 1,941 | 90,169 | 697 | 116 |
| `app/models/meeting.rb` | 1,780 | 75,581 | 627 | 19 |
| `app/models/login_profile.rb` | 1,764 | 81,447 | 702 | 44 |

All 6 files show 0% test coverage in skunk's analysis (no SimpleCov `.resultset.json` found). The `account.rb` model has **116 associations**, making it a central coupling point where any change risks ripple effects across the entire system. `user.rb` includes **28 concerns**, blending authentication, integrations, admin filters, permissions, and deletability into a single class.

**Impact**: These files are changed frequently (top churn files over 6 months) and are the most complex in the codebase. Every developer touching meetings, users, or accounts pays a cognitive tax. Bugs cluster here because the blast radius of changes is unknowable without reading thousands of lines.

**Direction**: Extract domain-specific behavior from `account.rb` and `user.rb` into bounded service modules. For `meetings_controller.rb` (637 lines, 84 changes in 6 months), decompose into focused controller concerns or route to separate controllers per action group.

---

### 2. Swallowed Errors in Composer Serializers

**Category**: Reliability & Error Handling | **Severity**: high
**Flagged by**: Error Handling, Structure

**Evidence**: 20+ instances of `rescue StandardError` with no variable capture and returning `nil` across Composer CRM tool serializers:

```ruby
# Pattern found in 15+ serializer files:
rescue StandardError
  nil
end
```

Files affected: `contact_serializer.rb`, `project_serializer.rb`, `opportunity_serializer.rb`, `get_opportunity_serializer.rb`, `list_opportunity_serializer.rb`, `task_serializer.rb`, `note_serializer.rb`, `workflow_serializer.rb`, `email_serializer.rb`, `event_serializer.rb`, and more.

Additionally, 38 files across `app/` use the `rescue StandardError => e` followed by `nil` pattern, and 201 files across the app use `rescue StandardError`.

**Impact**: When the AI assistant's tools silently return `nil` on errors, the LLM receives incomplete data without knowing it. This creates hallucination risk -- the AI sees a nil field and may fabricate or omit information. Debugging user-reported AI issues becomes nearly impossible because the error evidence is discarded at the serialization layer.

**Direction**: Replace bare `rescue StandardError` in serializers with either: (a) logging + Honeybadger notification while still returning nil (minimum), or (b) a structured error response that tells the Composer orchestrator a field failed to serialize. The Composer subsystem already has 186 Honeybadger.notify calls elsewhere -- these serializers should join that pattern.

---

### 3. SQL Injection Surface Area

**Category**: Architecture & Coupling (Security) | **Severity**: high
**Flagged by**: Error Handling (brakeman), Structure

**Evidence**: Brakeman reports **30 SQL injection warnings** and **50 total security warnings**:

- Medium confidence: `app/models/workflow.rb:120`, `app/models/concerns/full_text_search.rb:15`, `app/models/concerns/linked_to.rb:37`, `app/models/contact.rb:172`, `app/queries/accounts/workflow_templates_query.rb:20`
- `full_text_search.rb` and `linked_to.rb` are **concerns included in multiple models**, amplifying the attack surface
- 3 mass assignment warnings via `permit!` in email connect views
- 2 command injection warnings in API documentation generation

**Impact**: SQL injection in shared concerns (`full_text_search`, `linked_to`) means every model that includes them inherits the vulnerability. The CRM holds sensitive financial advisor and client data, making these findings higher-risk than typical web apps.

**Direction**: Audit the 8 medium-confidence SQL injection warnings first (shared concerns are highest priority). Replace string interpolation in queries with parameterized queries or Arel. Address `permit!` calls in email connect views with explicit parameter lists.

---

### 4. 168 Lib Subdirectories -- Unbounded Service Layer

**Category**: Maintainability & Conventions | **Severity**: medium
**Flagged by**: Structure, Coupling

**Evidence**: `app/lib/` contains **168 subdirectories** and **2,355 Ruby files**. Only 2 files exist in `app/services/`. This means all business logic beyond models and controllers lives in a single flat namespace under `lib/`.

Example subdirectories (sampled): `accounts`, `composer`, `contacts`, `email`, `email_connect`, `exchange`, `imports`, `integrations`, `lpl`, `meetings`, `nylas`, `nylas_v3`, `open_search`, `permissions`, `salesforce`, `sync`, `sync_engine`, `webhooks`, `workflow_engine`, `workflows`, and 140+ more.

There is no enforced layering -- `app/lib/meetings/` can freely call into `app/lib/sync/` which calls `app/lib/nylas_v3/` which calls `app/lib/email_connect/`. The directory structure is a flat bag of namespaces, not an architecture.

**Impact**: New developers cannot reason about which modules depend on which. Refactoring one integration risks breaking unrelated features because dependency paths are invisible. The 61 code clones detected by jscpd in `app/lib/` suggest similar logic is being reimplemented rather than shared, likely because developers can't find existing implementations in the flat structure.

**Direction**: Introduce a lightweight layering convention (e.g., `app/lib/integrations/`, `app/lib/domain/`, `app/lib/infrastructure/`) and document dependency direction rules. Start with the highest-churn areas: Composer (214 files), meetings, and imports. Consider using Packwerk or similar tools to enforce boundaries.

---

### 5. Angular Migration Drag

**Category**: Maintainability & Conventions | **Severity**: medium
**Flagged by**: Structure, Duplication, Complexity

**Evidence**:
- 112 Angular files remain in `app/javascript/angular/`
- 25 react2angular bridge files exist
- `angular-1.8.3.js` (36,604 lines) is the most complex file in the codebase at complexity score 2,832
- `calendar_controller.js` (705 lines, complexity 91) is the highest-complexity non-vendor Angular file
- Vendor JS files (`fullcalendar.js` at 15,148 lines, `jquery.atwho-1.5.4.js`, `bootstrap-datepicker.js`) are still needed by Angular components
- jscpd found duplication between Angular-era validators (`contacts/custom_field_numeric_range_validator.ts` and `contacts/numeric_range_validator.ts`)

**Impact**: The Angular remnants force maintaining two frontend frameworks, two build pipelines, and bridge code. The calendar is a user-facing feature still running on Angular + jQuery plugins. Each bridge point is a potential state synchronization bug. Vendor JS libraries needed only by Angular add ~53K lines of unmaintained code.

**Direction**: Prioritize migrating the calendar (highest-complexity Angular component) and then audit which vendor JS files can be removed after each Angular component is replaced.

---

### 6. Oversized React Components and State Sprawl

**Category**: Code Health & Complexity | **Severity**: medium
**Flagged by**: Complexity, Structure, State

**Evidence**:

Large React/TS files (actively churning):
| File | Lines | 6mo Changes |
|------|-------|-------------|
| `types.ts` | 1,644 | 80 |
| `OrganizationSettingsCustomObjectLayoutEditor.tsx` | 930 | 56 |
| `UploadFormPreviousCrm.tsx` | 656 | - |
| `Table.tsx` (reports) | 576 | - |
| `Editor.tsx` (dashboards) | 532 | - |
| `AssistantMessage.tsx` | 432 | 60 |

State management: 64 files in `app/javascript/state/` (Redux slices), plus 443 files using `useState` and 325 files using `useEffect`. The state directory mixes domain concerns (meetings, ai_assistant, files) with UI state (highlights, search dialogs, sync notices).

**Impact**: `types.ts` at 1,644 lines with 80 changes in 6 months is a shared monolithic type file -- every PR touching types risks merge conflicts. Components over 500 lines mix rendering, data fetching, and business logic, making them hard to test and review.

**Direction**: Split `types.ts` into domain-scoped type files co-located with their features. Extract the 5 largest components into composition patterns (container + presentation). Consider whether some Redux slices duplicate server state that should be managed by React Query/SWR instead.

---

### 7. High Churn in Routes File

**Category**: Architecture & Coupling | **Severity**: medium
**Flagged by**: Complexity & Churn

**Evidence**: `config/routes/tenant.rb` is **1,208 lines** and was the most-changed Ruby file in 6 months with **84 modifications**. Every new feature, every API endpoint change, and every resource addition touches this single file.

**Impact**: This is a merge conflict magnet. With 84 changes in 6 months, multiple developers are constantly editing the same file. It's also a read-time bottleneck -- understanding the full routing surface requires reading 1,200 lines.

**Direction**: Split tenant routes by domain (e.g., `routes/tenant/meetings.rb`, `routes/tenant/contacts.rb`, `routes/tenant/composer.rb`). Rails supports `draw(:filename)` for route splitting.

---

### 8. ActiveRecord Callbacks Creating Hidden Data Flow

**Category**: Data Integrity & State | **Severity**: medium
**Flagged by**: State, Coupling

**Evidence**: 130 model files contain ActiveRecord callbacks totaling 260 callback declarations. Core models chain callbacks that trigger business logic:

- `account.rb`: `after_create :generate_subscription, :setup_user_permission_for_stream_item_query, :add_custom_object_types`
- `account.rb`: `after_save :update_stream_items_for_name`
- `user.rb`: `after_create :setup_user_group, :setup_user_permission_for_stream_item_query`
- `subscription.rb`: `after_commit :handle_multi_account_on_plan_change`

**Impact**: Callbacks create invisible execution paths. Creating an Account silently generates a Subscription, sets up permissions, and adds custom object types. Testing requires understanding these hidden side effects. Debugging production issues requires tracing through callback chains that span multiple concerns and models.

**Direction**: For the highest-impact models (Account, User, Subscription), document the callback chain in comments or extract callback logic into explicit service objects that are called from controllers/jobs, making the data flow visible.

---

## Lower Priority

### Duplication
- **158 JS/TS clones** detected by jscpd, mostly in validator code and component patterns
- **24 clones in Composer** tools -- serializers share near-identical structure across entity types (contacts, opportunities, projects, etc.)
- **4 clones in controllers** -- attachment handling and S3 upload patterns repeated
- `add_on_product.rb` and `subscription_plan.rb` share identical Stripe metadata extraction logic

### Security (Lower Confidence)
- 30 SQL injection warnings from brakeman, but most are weak confidence. The medium-confidence ones in shared concerns are addressed in Finding #3
- Dynamic render path warnings (9) in older controllers -- lower risk with modern Rails content security defaults

### Convention Drift
- 219 model concerns vs 443 models -- nearly 1:2 ratio suggests concerns are being used as a primary decomposition strategy rather than for genuinely cross-cutting behavior
- Inconsistent error handling: 186 Honeybadger.notify calls, 486 Rails.logger calls, plus 38 `rescue StandardError => e; nil` patterns -- three different strategies in use
- `app/lib/feature_whitelist.rb` (49 changes in 6 months) is a high-churn configuration file that would benefit from a more structured approach

### Dead Code Candidates
- Vendor JavaScript files (`jquery.atwho-1.5.4.js`, `intro.js`, `bootstrap-datepicker.js`) that may only be needed by Angular components
- `app/javascript/vendor/compressjs/` (custom compression library) -- verify if still in use

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| **Total source files** | ~27,500 (Ruby + TS + JS) |
| **Total lines of code** | ~2.2M |
| **Ruby complexity (scc)** | 47,067 |
| **TypeScript complexity (scc)** | 25,364 |
| **JavaScript complexity (scc)** | 24,526 |
| **Worst StinkScore** | 2,566 (meetings_controller.rb) |
| **Average StinkScore (top 6)** | 2,054 |
| **Brakeman warnings** | 50 (30 SQL injection, 9 dynamic render, 3 mass assignment) |
| **jscpd clones (JS/TS)** | 158 |
| **jscpd clones (Ruby lib)** | 61 |
| **jscpd clones (Composer)** | 24 |
| **ActiveRecord callbacks** | 260 across 130 model files |
| **rescue StandardError usage** | 201 files |
| **Swallowed errors (rescue => nil)** | 38 files |
| **Angular files remaining** | 112 |
| **react2angular bridges** | 25 |
| **app/lib subdirectories** | 168 |
| **Routes file (tenant.rb)** | 1,208 lines, 84 changes/6mo |
| **Commits touching 15+ files** | 265 in last 6 months |
