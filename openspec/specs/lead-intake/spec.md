# lead-intake Specification

## Purpose

Accept a raw lead payload via webhook, validate required fields, normalize the data into a canonical lead object, and pass it downstream. This is the pipeline entry point.

## Requirements

### REQ-01: Webhook Acceptance

The system MUST accept an HTTP POST to a fixed webhook URL containing at minimum: `name`, `email`, `company`. Fields MAY include `role`. The system MUST reject payloads missing any required field with a 4xx response or a terminal error branch — no downstream node executes.

#### Scenario: Valid single-lead payload

- GIVEN a POST arrives with `{ "name": "Martín Gómez", "email": "martin@nexocrm.io", "company": "NexoCRM" }`
- WHEN the webhook trigger fires
- THEN the pipeline continues with a normalized lead object containing all three fields
- AND execution log shows 1 item output from the trigger node

#### Scenario: Missing required field

- GIVEN a POST arrives with `{ "name": "Martín Gómez", "company": "NexoCRM" }` (no email)
- WHEN the webhook trigger fires
- THEN the pipeline halts at the validation node — no enrichment or outreach node executes
- AND the execution log records the error with a message identifying the missing field

### REQ-02: Email Format Validation

The system MUST validate that `email` matches a basic RFC 5322 pattern (contains `@` and a domain with a TLD). Invalid formats MUST halt the pipeline before enrichment.

#### Scenario: Malformed email

- GIVEN a POST arrives with `{ "name": "Test", "email": "not-an-email", "company": "Acme" }`
- WHEN the validation step runs
- THEN pipeline halts; no Hunter.io call is made
- AND the execution log records "invalid email format"

### REQ-03: Deduplication by Email

The system SHOULD detect a duplicate lead (same `email` submitted twice within the same execution context) and halt the second execution without sending outreach. Because the pipeline is stateless per execution, deduplication is enforced by checking the CRM (HubSpot) for an existing contact with that email before proceeding.

#### Scenario: Duplicate email already in CRM

- GIVEN a contact with `email = "martin@nexocrm.io"` already exists in HubSpot
- WHEN a new lead payload with the same email arrives
- THEN the pipeline halts after the dedup check — no enrichment or outreach runs
- AND the execution log indicates "duplicate lead — skipped"

#### Scenario: New unique lead

- GIVEN no contact with the incoming email exists in HubSpot
- WHEN a new lead payload arrives
- THEN dedup check passes and pipeline continues to enrichment
