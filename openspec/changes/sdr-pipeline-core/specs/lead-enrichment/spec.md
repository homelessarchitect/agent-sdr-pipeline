# lead-enrichment Specification

## Purpose

Call Hunter.io to enrich the normalized lead object with company domain, email confidence score, and basic firmographic data. Merge results onto the lead object for use by outreach generation.

## Requirements

### REQ-04: Enrichment Call

The system MUST call the Hunter.io `/people/find` endpoint (or `/email-finder` as applicable) using the lead's `name` and `company` fields. The API key MUST be stored as an n8n credential — never hardcoded.

#### Scenario: Successful enrichment

- GIVEN a valid lead with `name = "Valentina Ríos"` and `company = "AgenteLab"`
- WHEN the Hunter.io HTTP node executes
- THEN the lead object is extended with at least: `enriched.domain`, `enriched.email_confidence`, `enriched.position` (if returned)
- AND the execution log shows 1 item output from the enrichment node

### REQ-05: Low-Confidence or Empty Enrichment

The system MUST handle the case where Hunter.io returns no data or a confidence score below 50. In this case the pipeline MUST continue (not halt) but MUST flag the lead as `enrichment_confidence: "low"` on the lead object so the HITL reviewer is informed.

#### Scenario: Hunter.io returns empty result

- GIVEN Hunter.io returns `{ "data": null }` for the submitted name/company
- WHEN the enrichment merge step runs
- THEN `enrichment_confidence` is set to `"low"` on the lead object
- AND pipeline continues to outreach generation with graceful generic personalization

#### Scenario: Confidence below threshold

- GIVEN Hunter.io returns a result with `score < 50`
- WHEN the enrichment merge step runs
- THEN `enrichment_confidence` is set to `"low"`
- AND the value is visible in the HITL Telegram message so the approver can factor it in

### REQ-06: Enrichment API Error

The system MUST handle HTTP errors from Hunter.io (4xx, 5xx, timeout) without crashing the pipeline. On error, the lead MUST be flagged with `enrichment_confidence: "failed"` and the pipeline MUST continue to HITL so the human can decide whether to proceed.

#### Scenario: Hunter.io 5xx error

- GIVEN Hunter.io returns a 500 response
- WHEN the HTTP error output fires
- THEN `enrichment_confidence` is set to `"failed"` on the lead object
- AND pipeline continues to outreach generation; HITL message shows enrichment failure warning
