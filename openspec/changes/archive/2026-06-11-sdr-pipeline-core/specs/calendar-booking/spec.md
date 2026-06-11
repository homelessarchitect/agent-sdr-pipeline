# calendar-booking Specification

## Purpose

Create a Google Calendar event on approval to reserve a discovery call slot for the lead. Executes after outreach-send succeeds. The event serves as a visual confirmation of pipeline completion in the Loom demo.

## Requirements

### REQ-17: Calendar Event Creation on Approval

The system MUST create a Google Calendar event after the outreach email is sent. The event MUST include: title referencing the lead's name and company, description containing the CTA booking link (Calendly/Cal.com URL), and a scheduled time (default: next business day at a fixed time). The Google Calendar OAuth credential MUST be stored as an n8n credential.

#### Scenario: Event created after approval

- GIVEN HITL gate returned `action=approve` and the email was sent successfully
- WHEN the Google Calendar node executes
- THEN a new event appears in the configured Google Calendar
- AND the event title contains the lead's name and company
- AND the event description contains the booking link CTA
- AND the execution log shows 1 item output from the calendar node

#### Scenario: Reject branch — no event

- GIVEN HITL gate returned `action=reject`
- WHEN the reject branch executes
- THEN no Google Calendar event is created

### REQ-18: Calendar API Error Handling

The system SHOULD handle Google Calendar API errors (auth failure, quota exceeded) without halting the overall execution. On calendar error, the system MUST send a Telegram operator alert and allow the CRM record step to still execute.

#### Scenario: Google Calendar API returns 403

- GIVEN the OAuth token has expired or lacks calendar scope
- WHEN the Google Calendar node fires
- THEN the error output triggers a Telegram operator alert: "Calendar event failed for [lead name]: [error]"
- AND the crm-record node still executes after the alert
- AND the execution log does not show a silent 0-item halt on the CRM branch
