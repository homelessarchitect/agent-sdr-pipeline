# outreach-send Specification

## Purpose

Send the approved outreach email to the lead's email address via Resend. Executes only after explicit HITL approval. On send failure, the system retries and alerts — it does not silently drop.

## Requirements

### REQ-14: Send Only After Approval

The system MUST NOT send any email unless the HITL gate returned `action=approve`. The outreach-send node MUST be positioned exclusively on the approve branch of the HITL IF node.

#### Scenario: Email sent after approval

- GIVEN HITL gate returned `action=approve`
- WHEN the outreach-send node executes
- THEN the Resend API is called with `to = lead.email`, `subject = outreach.subject`, `html/text = outreach.body`
- AND the execution log shows 1 item output from the send node
- AND the email arrives in the recipient's inbox

#### Scenario: Reject branch — no send

- GIVEN HITL gate returned `action=reject`
- WHEN the reject branch executes
- THEN the outreach-send node is never reached
- AND no Resend API call is made

### REQ-15: Resend Credential

The system MUST authenticate to Resend using an API key stored as an n8n HTTP Header Auth credential. The `from` address MUST be a configured sender domain on the Resend account — not a raw personal email.

#### Scenario: Valid Resend credential

- GIVEN a valid Resend API key is stored in the n8n credential
- WHEN the HTTP node calls `POST https://api.resend.com/emails`
- THEN Resend responds with `200` and a message ID
- AND the execution log captures the message ID

### REQ-16: Send Failure Handling

The system MUST handle Resend API errors (4xx, 5xx) without silently halting. On failure, the system MUST send a Telegram alert to the operator chat indicating send failure with lead name and error detail. The system SHOULD retry once before alerting.

#### Scenario: Resend returns 5xx

- GIVEN Resend returns a 500 on the first attempt
- WHEN the error output of the HTTP node fires
- THEN a Telegram message is sent to the operator chat: "Send failed for [lead name]: [error]"
- AND the execution log does not show a silent 0-item halt — the alert node executes

#### Scenario: Resend returns 4xx (bad request)

- GIVEN Resend returns 422 (e.g., invalid from address)
- WHEN the error output fires
- THEN the Telegram operator alert fires immediately (no retry — 4xx is not transient)
- AND the execution log captures the HTTP status and response body
