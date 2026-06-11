# outreach-generation Specification

## Purpose

Use gpt-4o-mini to generate a personalized cold-email body in Spanish from the enriched lead object. Output is a structured object with subject line and body, passed to the HITL gate for review before any send.

## Requirements

### REQ-07: LLM Outreach Generation

The system MUST call gpt-4o-mini with a prompt that includes the lead's `name`, `company`, and at least one enrichment data point (domain, role, or position). The system MUST produce exactly: `subject` (max 9 words) and `body` (max 120 words, Spanish, one CTA). The OpenAI API key MUST be stored as an n8n credential.

#### Scenario: Enrichment data available

- GIVEN a lead with `name = "Diego Paredes"`, `company = "Pipefy MX"`, `enriched.domain = "pipefy.mx"`, `enriched.position = "Sales Lead"`
- WHEN the LLM node executes
- THEN the output contains a non-empty `subject` and `body`
- AND `body` references something specific to the lead or company (name, domain, or role)
- AND `body` contains exactly one CTA (a Calendly/Cal.com link placeholder)
- AND the language of `body` is Spanish

#### Scenario: Low-confidence enrichment — graceful fallback

- GIVEN `enrichment_confidence = "low"` on the lead object (no specific enrichment data)
- WHEN the LLM node executes
- THEN the prompt falls back to a generic but personalized template using only `name` and `company`
- AND `body` still contains one CTA in Spanish
- AND `subject` and `body` are non-empty

### REQ-08: Outreach Object Structure

The system MUST output the generated copy as a structured object: `{ "subject": "...", "body": "..." }`. Downstream nodes (HITL, send) MUST read from this named structure — raw LLM text MUST NOT be passed as an unstructured string.

#### Scenario: Output shape validation

- GIVEN the LLM node completes successfully
- WHEN the output item is inspected in the execution log
- THEN `json.subject` is a non-empty string
- AND `json.body` is a non-empty string
- AND no other field is required by downstream nodes
