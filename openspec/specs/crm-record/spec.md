# crm-record Specification

## Purpose

Upsert a contact and associated deal record in HubSpot to reflect the lead's pipeline status. Runs on both the approve path (full record with deal) and the reject path (contact updated with rejected status). Also serves the deduplication check in lead-intake.

## Requirements

### REQ-19: Contact Upsert on Approval

The system MUST upsert a HubSpot contact using the lead's email as the unique identifier. Fields to set: `firstname`, `lastname` (split from `name`), `email`, `company`, `outreach_status = "sent"`. The system MUST use HubSpot's upsert endpoint so duplicate contacts are not created on re-run.

#### Scenario: New contact on approval

- GIVEN HITL gate returned `action=approve`
- WHEN the HubSpot contact upsert node executes
- THEN a new contact appears in HubSpot with `email`, `company`, `outreach_status = "sent"`
- AND the execution log shows 1 item output from the contact node

#### Scenario: Existing contact on approval (re-run)

- GIVEN a HubSpot contact with the same email already exists
- WHEN the upsert executes
- THEN the existing contact is updated rather than a duplicate created
- AND `outreach_status` is updated to `"sent"`

### REQ-20: Deal Creation on Approval

The system MUST create a HubSpot deal associated with the upserted contact. Minimum deal fields: `dealname` = "[Company] — SDR Outreach", `pipeline` = default pipeline, `dealstage` = first stage ("Contactado" or equivalent). The HubSpot Private App token MUST be stored as an n8n credential.

#### Scenario: Deal created after contact upsert

- GIVEN a contact was upserted successfully
- WHEN the HubSpot deal creation node executes
- THEN a deal record appears in HubSpot linked to the contact
- AND deal name, pipeline, and stage match the configured values
- AND the execution log shows 1 item output from the deal node

### REQ-21: Contact Status on Rejection

The system MUST upsert (create or update) a HubSpot contact on the reject path with `outreach_status = "rejected"`. No deal is created for rejected leads.

#### Scenario: Contact updated on rejection

- GIVEN HITL gate returned `action=reject`
- WHEN the reject branch executes
- THEN a HubSpot contact is upserted with `outreach_status = "rejected"`
- AND no HubSpot deal is created
- AND the execution log shows the contact node output, no deal node output

### REQ-22: Deduplication Check at Intake

The system MUST query HubSpot by email at the lead-intake stage to detect duplicate leads (REQ-03). A contact with `outreach_status` of any value MUST be treated as a duplicate and halt the pipeline.

#### Scenario: HubSpot lookup returns existing contact

- GIVEN a contact with `email = "martin@nexocrm.io"` exists in HubSpot with any `outreach_status`
- WHEN the dedup check node runs after intake validation
- THEN pipeline halts; execution log records "duplicate lead — skipped"
- AND no enrichment call is made

#### Scenario: HubSpot lookup returns no contact

- GIVEN no contact with the incoming email exists in HubSpot
- WHEN the dedup check runs
- THEN pipeline continues to lead-enrichment

### REQ-23: CRM API Error Handling

The system MUST handle HubSpot API errors (auth failure, rate limit, 5xx) without crashing the execution. On error, a Telegram operator alert MUST fire with lead name and error detail.

#### Scenario: HubSpot returns 401 (invalid token)

- GIVEN the HubSpot Private App token is expired or invalid
- WHEN the contact upsert node fires
- THEN the error output sends a Telegram operator alert: "CRM record failed for [lead name]: 401"
- AND the execution does not terminate as a silent 0-item halt
