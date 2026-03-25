Design a "merge contacts" feature for the CRM app at ~/Workspace/crm-web.

Requirements:
- Users can select 2+ contacts and merge them into one
- The surviving contact keeps all associations (tasks, notes, opportunities) from merged contacts
- Merged contacts are soft-deleted but recoverable for 30 days
- An audit trail records who merged what and when

Read the Contact model (app/models/contact.rb) to understand the existing structure before designing.

Provide:
1. Your recommended approach (which Rails patterns to use)
2. The full vertical slice: routes, controllers, models, tests
3. For every abstraction you introduce, argue why simpler alternatives don't work
