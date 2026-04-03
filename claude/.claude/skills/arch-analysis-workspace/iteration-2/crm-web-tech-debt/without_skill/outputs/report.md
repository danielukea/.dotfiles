# CRM-Web Tech Debt Audit

**Date:** 2026-04-02
**Codebase:** /Users/lukedanielson/Workspace/crm-web
**Stack:** Rails 7.2.3 / Ruby 3.4.8 / TypeScript + React / AngularJS (legacy)

---

## Executive Summary

CRM-Web is a large, mature Rails monolith (~4M lines of code, ~32K files) with a significant frontend presence spanning three generations of JavaScript frameworks. The codebase carries meaningful tech debt in several dimensions: legacy frontend code, oversized domain models, stale TODO comments dating back years, deprecated gem dependencies, and security warnings from dynamic code patterns. Duplication is well-controlled at 0.7% overall.

---

## 1. Codebase Size & Complexity

| Area | Files | Lines of Code | Complexity |
|------|-------|---------------|------------|
| **Ruby (total)** | 20,777 | 1,494,991 | 47,067 |
| **TypeScript** | 6,084 | 582,784 | 25,362 |
| **JavaScript** | 639 | 133,849 | 24,452 |
| **Sass/CSS** | 516 | 81,394 | 2 |
| **YAML** | 1,817 | 480,908 | 0 |
| **Overall** | 31,944 | 4,010,187 | 98,271 |

### Key Layer Sizes

| Layer | Files | Lines |
|-------|-------|-------|
| Models | 662 | 46,457 |
| Controllers | 500 | 28,649 |
| Jobs | 336 | 8,715 |
| Serializers | 363 | - |
| app/lib (service layer) | 2,355 | 122,371 |
| Concerns (model) | 219 | - |
| Concerns (controller) | 80 | - |
| Views (ERB) | 1,466 | - |
| Embedded API gem | 375 (Ruby) | 18,709 |

### Dependencies

| Type | Count |
|------|-------|
| Gems (direct) | 181 |
| Gems (total in lockfile) | ~1,187 |
| npm dependencies | 103 |
| npm devDependencies | 98 |
| Database migrations | 517 |

---

## 2. God Objects (Oversized Files)

### Models (300+ lines)

| File | Lines | Concern |
|------|-------|---------|
| `app/models/user.rb` | 814 | God model - authentication, permissions, feature flags, relationships |
| `app/models/subscription.rb` | 735 | Billing logic embedded in model |
| `app/models/login_profile.rb` | 702 | Authentication complexity |
| `app/models/account.rb` | 697 | Multi-tenant account logic |
| `app/models/meeting.rb` | 627 | Rapidly growing (214 changes in last year) |
| `app/models/import.rb` | 606 | Data import logic |
| `app/models/external_source_configuration.rb` | 477 | Integration config |
| `app/models/contact.rb` | 464 | Core domain model |
| `app/models/custom_field.rb` | 414 | Dynamic field system |
| `app/models/custom_object_type.rb` | 403 | Custom object schema |

### Controllers (300+ lines)

| File | Lines | Concern |
|------|-------|---------|
| `app/controllers/meetings_controller.rb` | 637 | Actively growing (180 changes in last year) |
| `app/controllers/contacts_controller.rb` | 482 | Core CRUD + complex filtering |
| `app/controllers/phone_calls_controller.rb` | 459 | Telephony integration |
| `app/controllers/custom_objects_controller.rb` | 411 | Dynamic object CRUD |
| `app/controllers/workflows_controller.rb` | 408 | Automation engine |
| `app/controllers/storage/files_controller.rb` | 352 | File management |
| `app/controllers/events_controller.rb` | 339 | Calendar events |
| `app/controllers/bulk_action_controller.rb` | 337 | Batch operations |
| `app/controllers/tasks_controller.rb` | 321 | Task management |
| `app/controllers/application_controller.rb` | 303 | Base controller bloat |

### Frontend (400+ lines)

| File | Lines |
|------|-------|
| `app/javascript/types.ts` | 1,644 (global type dump, 209 changes last year) |
| `app/javascript/shared/components/autocomplete/typo.ts` | 933 |
| `OrganizationSettingsCustomObjectLayoutEditor.tsx` | 930 |
| `app/javascript/imports/UploadFormPreviousCrm.tsx` | 656 |
| `app/javascript/reports/components/show/Table.tsx` | 576 |
| `app/javascript/dashboards/editor/Editor.tsx` | 532 |

---

## 3. Legacy Frontend Code (Critical)

The codebase runs **three generations of frontend technology simultaneously**:

### 3a. Sprockets + AngularJS (Legacy)
- **187 files** in `app/assets/javascripts/` (23,136 LOC via Sprockets pipeline)
- **68 AngularJS files** in `app/javascript/angular/` (8,551 LOC)
- **16 Handlebars templates** still in use
- `handlebars_assets` gem still in Gemfile
- TypeScript config still declares `angular` and `angular-mocks` as type dependencies
- Legacy JS files include jQuery plugins (`chosen-js`, `bootstrap-datepicker`)

### 3b. Modern Stack (TypeScript + React)
- **1,931 TypeScript/TSX files** (152K LOC) - the active frontend
- React components with esbuild bundling
- This is where active development happens

### Impact
The dual pipeline (Sprockets + esbuild) adds build complexity, increases CI time, and forces developers to understand two completely different frontend architectures. AngularJS reached end-of-life in December 2021.

---

## 4. Deprecated & Aging Dependencies

| Gem | Version | Issue |
|-----|---------|-------|
| `active_model_serializers` | ~> 0.8 | **Version 0.8 is ancient** (current is 0.10+). No longer maintained. |
| `google-api-client` | ~> 0.53 | Deprecated in favor of individual `google-apis-*` gems |
| `handlebars_assets` | ~> 0.23 | Legacy template engine, last released 2017 |
| `attr_encrypted` | ~> 4.0 | Unmaintained, superseded by Rails 7 encrypted attributes |
| `hashie` | ~> 3.6 | Legacy Mash-style hashes, often a code smell |
| `em-http-request` | ~> 1.1 | EventMachine-based HTTP (forked), legacy async pattern |
| `escape_utils` | ~> 1.2 | Minimal value with modern Ruby |
| `acts_as_paranoid` | ~> 0.10 | Soft-delete alternative to Rails `discard` gem |
| `sprockets` / `sprockets-rails` | ~> 4.2 / ~> 3.4 | Legacy asset pipeline, should migrate fully to esbuild/cssbundling |

---

## 5. Security Warnings (Brakeman)

**Total: 50 warnings** (5 High, 24 Medium, 21 Weak)

### High Confidence (5)

| Type | File | Issue |
|------|------|-------|
| Dangerous Send | `additional_infos_controller.rb:50` | `send(params[:section])` - user-controlled method execution |
| Dangerous Send | `data_files_controller.rb:15` | `send(params[:document_type].tableize)` |
| Dangerous Send | `storage/webhooks_controller.rb:31` | `send(params[:resource_type]...)` |
| Dynamic Render | `event_invites_controller.rb` | `render(partial => params[:template])` |
| *(1 more high)* | | |

### By Category

| Category | Count |
|----------|-------|
| SQL Injection | 30 |
| Dynamic Render Path | 9 |
| Dangerous Send | 3 |
| Mass Assignment | 3 |
| Command Injection | 2 |
| Redirect | 2 |
| Dangerous Eval | 1 |

The **30 SQL injection warnings** are concentrated in `app/queries/contacts/filter_query_builder.rb`, which constructs dynamic SQL using string interpolation of column/table names. While many may be safe due to whitelisting upstream, the pattern is inherently risky.

---

## 6. Code Duplication

**Overall duplication: 0.7%** (136 clones across 5,733 analyzed files) -- this is well-controlled.

| Format | Files | Clones | Duplicated Lines |
|--------|-------|--------|-----------------|
| Ruby | 4,799 | 96 | 1,717 (0.59%) |
| TypeScript | 653 | 29 | 480 (1.09%) |
| JavaScript | 281 | 11 | 134 (0.35%) |

Hotspots for duplication:
- `app/admin/` - Admin panel resource definitions share boilerplate (email_addresses, phone_numbers, websites, street_addresses)
- `app/admin/crm_migrations_tasks.rb` - Internal self-duplication
- `app/admin/prompt_templates.rb` / `task_templates.rb` - Structural clones

---

## 7. Stale TODO/FIXME Comments

**Total: 862** (837 TODO, 20 XXX, 5 FIXME)

### Egregiously Stale TODOs

Multiple TODOs in `app/models/slack/` reference **"Feb 24 2021"** -- over 5 years old:
- `notification_preferences.rb:22` - "TODO: remove after Feb 24 2021"
- `notification_exchange.rb:42` - "TODO - uncomment after Feb 24 2021"
- `notification_exchange.rb:49` - "TODO - delete after Feb 24 2021"
- `notification.rb:17` - "TODO: temp - remove after Feb 24 2021"
- `notification.rb:51` - "TODO: tmp - refactor after Feb 24 2021"
- `v2_available_channels.rb:5` - "TODO: uncomment after Feb 2021"

These indicate dead code branches that were never cleaned up after a Slack API migration.

---

## 8. Stylesheet Bloat

- **49,131 lines** of SCSS/CSS across 248 files
- No evidence of CSS-in-JS or utility-first approach for the React layer
- Largest files: `print.scss` (1,558), `_ai_assistant.scss` (1,544), `_workflows.scss` (1,439), `_global.scss` (1,427)
- `_helium-ui-overrides.scss` (732 lines) suggests friction between the design system and legacy styles

---

## 9. Routes Complexity

- **1,580 total lines** across 3 route files
- `config/routes/tenant.rb` alone is **1,208 lines**
- This scale of routing suggests the monolith handles an enormous surface area in a single process

---

## 10. Test Coverage Gaps

| Spec Type | Count |
|-----------|-------|
| Model specs | 501 |
| Controller specs | 93 |
| Request specs | 450 |
| **Total spec files** | **3,755** |
| **Total spec + support** | **4,403** |

With 662 models and only 501 model specs, there is reasonable coverage. However, 500 controllers with only 93 controller specs (supplemented by 450 request specs) suggests some controllers lack direct test coverage. The embedded `api/` gem has its own spec directory.

---

## 11. Churn Hotspots (Last 12 Months)

Files changed most frequently since April 2025:

| Changes | File | Concern |
|---------|------|---------|
| 214 | `app/models/meeting.rb` | Rapidly evolving feature area |
| 209 | `app/javascript/types.ts` | Central type file is a bottleneck |
| 180 | `app/controllers/meetings_controller.rb` | Controller growing unchecked |
| 133 | `app/assets/javascripts/env/routes.js.erb` | Sprockets route file touched on every route change |
| 115 | `app/serializers/meeting_serializer.rb` | Serializer churn |
| 94 | `app/models/notetaker.rb` | New feature building complexity |
| 93 | `app/controllers/phone_calls_controller.rb` | Telephony changes |

The **meetings domain** dominates churn and is the primary area accumulating new tech debt.

---

## 12. TypeScript Configuration

- `strict` mode is **not enabled** (only `strictNullChecks` is on)
- Missing: `noImplicitAny`, `strictBindCallApply`, `strictFunctionTypes`, `strictPropertyInitialization`
- `skipLibCheck: true` hides potential type errors in dependencies
- Still declares legacy type dependencies: `angular`, `angular-mocks`, `bootstrap`, `chosen-js`, `jquery`, `underscore`

---

## 13. Architectural Patterns Assessment

### Positive Patterns
- **Queries layer** (`app/queries/`, 36 files) - dedicated query objects
- **Policies layer** (`app/policies/`, 60 files) - authorization separated from controllers
- **Presenters** (134 files) and **Decorators** (51 files) - view logic separated
- **Validators** (25 files) - custom validation extracted
- **Paper trail** for audit logging
- **Flipper** for feature flags
- **Console1984** for console audit trail

### Concerning Patterns
- **app/lib/** has **2,355 files / 122K LOC** -- this is larger than models + controllers combined, suggesting an ad-hoc service layer without clear boundaries
- Only **2 files** in `app/services/` (228 LOC) -- the service layer lives in `app/lib/` instead
- Embedded `api/` gem with its own Gemfile creates dependency management complexity
- `app/lib/demo_accounts/` contains 1,700+ line seed files with hardcoded data
- **Vendor JavaScript** committed to repo (`app/javascript/vendor/compressjs/`, 5,479 LOC)

---

## Priority Recommendations

### P0 - Security
1. **Fix 5 high-confidence Brakeman warnings** - especially the `send(params[:...])` patterns that allow arbitrary method execution
2. **Audit SQL injection patterns** in `filter_query_builder.rb` - replace string interpolation with parameterized queries or strict whitelists

### P1 - Active Debt Accumulation
3. **Split `meeting.rb` (814 LOC) and `meetings_controller.rb` (637 LOC)** - highest churn files, actively growing
4. **Break up `types.ts` (1,644 LOC)** - co-locate types with their domains instead of one central file
5. **Extract `user.rb` (814 LOC)** into concerns or value objects - classic god model

### P2 - Legacy Cleanup
6. **Remove AngularJS code** (68 files, 8,551 LOC) - AngularJS has been EOL since Dec 2021
7. **Migrate off Sprockets** - complete the transition to esbuild/cssbundling and remove the dual asset pipeline
8. **Delete stale Slack TODOs** - the Feb 2021 migration code branches can be cleaned up
9. **Remove vendored JavaScript** (`compressjs`) - use npm package instead
10. **Remove Handlebars templates** (16 files) and `handlebars_assets` gem

### P3 - Modernization
11. **Replace `active_model_serializers` 0.8** with a maintained serialization library (e.g., `alba`, `blueprinter`, or `jsonapi-serializer`)
12. **Replace `attr_encrypted`** with Rails 7 native encrypted attributes
13. **Replace `google-api-client`** with individual `google-apis-*` gems
14. **Enable TypeScript strict mode** incrementally (`noImplicitAny` first)
15. **Organize `app/lib/`** (2,355 files) into bounded contexts or extract into engines

### P4 - Ongoing Hygiene
16. **Triage 862 TODO comments** - delete resolved ones, convert actionable ones to tickets
17. **Reduce route file size** - extract `tenant.rb` (1,208 lines) into domain-specific route files
18. **Add controller-level tests** for undertested controllers
