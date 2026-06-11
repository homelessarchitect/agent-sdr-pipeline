# hitl-approval-gate Specification

## Purpose

Block pipeline execution until a human explicitly approves or rejects the generated outreach. No email, calendar event, or CRM record is created without explicit approval. This is the mandatory human checkpoint of the pipeline.

## Requirements

### REQ-09: Telegram Notification with Approval Buttons

The system MUST send a Telegram message to a configured chat ID containing: lead name, company, enrichment confidence level, the generated email subject and body preview, and two inline keyboard buttons labeled "Aprobar" and "Rechazar". Each button MUST embed the `$execution.resumeUrl` with an `action` query parameter (`approve` or `reject`).

#### Scenario: Notification delivered

- GIVEN a lead has passed enrichment and outreach generation
- WHEN the Telegram send node executes
- THEN a message arrives in the configured Telegram chat within 5 seconds
- AND the message displays lead name, company, email subject, and body preview
- AND two inline buttons "Aprobar" and "Rechazar" are visible
- AND the execution log shows the Wait node in a paused state

### REQ-10: Approve Path

The system MUST resume pipeline execution when the "Aprobar" button is tapped (i.e., the resumeUrl is called with `action=approve`). On resume, the pipeline MUST continue to outreach send, calendar booking, and CRM record in sequence.

#### Scenario: Human taps Aprobar

- GIVEN the Wait node is paused awaiting a webhook callback
- WHEN the "Aprobar" button is tapped in Telegram
- THEN the resumeUrl receives a GET/POST with `action=approve`
- AND the Wait node resumes and passes 1 item to the approve branch
- AND outreach-send, calendar-booking, and crm-record all execute in sequence

### REQ-11: Reject Path

The system MUST stop all downstream execution (no email sent, no calendar event, no CRM deal) when "Rechazar" is tapped. The system MUST update the CRM contact status to `outreach_status: "rejected"`. Pipeline MUST terminate cleanly — no error state.

#### Scenario: Human taps Rechazar

- GIVEN the Wait node is paused
- WHEN the "Rechazar" button is tapped
- THEN the resumeUrl receives `action=reject`
- AND the Wait node routes to the reject branch
- AND no email is sent, no calendar event is created
- AND HubSpot contact is updated with `outreach_status = "rejected"`
- AND execution completes without error

### REQ-12: Timeout / No Response

The system MUST define a Wait node timeout. If the resumeUrl is never called within the timeout window, the execution MUST terminate without sending any outreach. The system MUST NOT treat timeout as an implicit approval.

#### Scenario: Approval window expires

- GIVEN the Wait node is paused and no button is tapped
- WHEN the configured timeout (1 hour) elapses
- THEN the execution terminates — no email sent, no calendar event, no CRM record
- AND the execution log shows the execution as timed out / completed without approval

### REQ-13: Double-Click Protection

The system SHOULD handle the case where the same resumeUrl approval link is called more than once (e.g., button tapped twice in Telegram). The second call MUST NOT trigger a duplicate send. Because n8n resumes a given execution only once, the second webhook call to the already-resumed execution MUST return a non-200 response or be silently ignored by n8n.

#### Scenario: Approve button tapped twice

- GIVEN an execution was already resumed via approve
- WHEN the same resumeUrl is called a second time
- THEN n8n rejects or ignores the duplicate resume call
- AND only one email is sent, one calendar event created, one CRM record upserted
