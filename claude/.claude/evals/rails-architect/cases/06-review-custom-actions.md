Review the PhoneCallsController at app/controllers/phone_calls_controller.rb in ~/Workspace/crm-web.

Read the full file. This controller has 13+ custom actions beyond standard REST (call_contact, create_meeting_and_call_contact, conference, incoming, connect_phone_call, phone_call_ended, save_phone_call, complete_phone_call, conference_participant_answered, recording_start, announce_recording_start_and_redirect, announce_recording_stop, recording_complete).

Focus your review on:
- Which custom actions should be extracted into separate controllers? Propose specific controller names and REST mappings.
- Is business logic leaking into the controller that belongs in models or concerns?
- Are there authorization or security concerns?

For each issue, classify severity (CRITICAL/HIGH/LOW), explain the fix, and note what tests would be needed.
