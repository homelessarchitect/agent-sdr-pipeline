# Design: SDR Pipeline Core

## Technical Approach

Single n8n workflow (`sdr-pipeline-main`) orchestrating all seven capabilities in
sequence. A second helper workflow (`sdr-test-trigger`) fires sample leads via HTTP
Request to the main webhook — this is the ONLY way to simulate the pipeline
programmatically (manual triggers cannot fire via the n8n REST API).

Data flows forward as a single n8n item accumulating fields via Set nodes. Context
after item-replacing nodes (Hunter.io HTTP Request, OpenAI) is recovered via
`$('NodeName').first().json` — the proven pattern from agent-whatsapp-rag.

Stack decisions: Hunter.io enrichment, Resend email, HubSpot Free CRM,
Telegram HITL via Wait node. Fallback for CRM: Google Sheets (one node swap).

---

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| Enrichment | Hunter.io `/people/find` | Apollo.io (overkill), Clearbit (no free tier) | 25 req/mo covers 5 demo leads; 1 REST call; simplest schema |
| Outreach channel | Resend HTTP Request (API key) | Gmail OAuth | Zero OAuth friction; free tier 3k/mo; real inbox delivery for Loom |
| CRM | HubSpot Free (Private App token) | Google Sheets | Proves the Workana skill signal; one token, no OAuth |
| HITL mechanism | Telegram + n8n Wait node (`onWebhookCall`) | Email approval link | Bot already live in sibling; inline buttons = camera-visible money shot |
| LLM model | gpt-4o-mini via `@n8n/n8n-nodes-langchain.openAi` | Claude API | Proven node in sibling; legacy `n8n-nodes-base.openAi` confirmed broken for chat completions |
| Lead accumulation | Set node spreading all fields onto one item | Separate items per step | n8n fan-in is complex; single item keeps downstream `$json.*` stable |

---

## Data Flow

```
[Webhook: POST /sdr-lead]
        |
        v
[Normalize Lead]           — Set: name, email, company; validate required fields
        |
        v
[Dedup Check]              — Code: compare email against stored executions (in-memory map)
        |                    → if duplicate: respond 409 and halt
        v
[Hunter.io Enrich]         — HTTP Request GET /people/find?email=&company=
        |
        v
[Merge Enrichment]         — Set: spread $('Normalize Lead').first().json +
        |                    hunter position, linkedin_url, domain onto item
        v
[Generate Outreach]        — @n8n/n8n-nodes-langchain.openAi; structured JSON output
        |                    subject + body (Spanish, one CTA = Calendly link)
        v
[Parse Outreach JSON]      — Code: JSON.parse($json.message.content)
        |                    onError: continueErrorOutput → [Fallback Outreach]
        v
[Send Telegram Preview]    — Telegram node (credential from UI, not $env)
        |                    message: name + subject + body preview + approve/reject buttons
        v
[Wait for Approval]        — Wait node, resumeOn: webhook, timeout: 1h
        |
        v
[IF Approved]              — $json.query.action === 'approve'
       / \
      /   \
[APPROVE]  [REJECT]
     |          |
     v          v
[Send Email]  [HubSpot Mark Rejected]
[Create Calendar Event]       |
[HubSpot Contact + Deal]   [Done]
     |
     v
  [Done]
```

**CSV batch path:** `sdr-test-trigger` workflow reads `data/sample-leads.json` via
Code node and iterates, posting each lead as a separate HTTP Request to the main
webhook. This keeps batch testing separate from single-lead path.

---

## Wait/Resume Mechanics (Critical — gates the build)

### How it works

1. Before sending the Telegram message, the workflow has an active execution ID.
   n8n exposes `$execution.resumeUrl` as a special variable available at runtime.

2. `$execution.resumeUrl` is a full URL like:
   `https://{N8N_HOST}/webhook/{executionId}/webhook`
   Appending `?action=approve` or `?action=reject` creates the approve/reject URLs.

3. The Telegram `Send Message` node sends an `inlineKeyboard` with two buttons:
   - "Aprobar" → URL: `={{ $execution.resumeUrl }}?action=approve`
   - "Rechazar" → URL: `={{ $execution.resumeUrl }}?action=reject`
   Both are URL-type buttons (not callback — URL buttons open in browser and hit the URL
   directly, which is what n8n needs to resume the execution).

4. The Wait node (`resumeOn: webhook`, `options.webhookSuffix: ""`) pauses the execution.
   When either button is tapped, the browser GETs the resume URL with the `?action=` param.
   n8n resumes the execution and the Wait node outputs `$json.query.action = "approve"|"reject"`.

5. The downstream IF node reads `={{ $json.query.action === 'approve' }}`.

### Double-click guard

The resume URL is single-use — n8n marks the execution as resumed on first call.
A second tap returns a 404 or "execution not waiting" error in the browser, which is
acceptable for a demo. Production hardening would add an idempotency key in a DB.

### Node configuration

```json
{
  "type": "n8n-nodes-base.wait",
  "typeVersion": 1,
  "parameters": {
    "resume": "webhook",
    "options": {
      "webhookSuffix": ""
    }
  }
}
```

Wait node timeout default is 1 hour. Set via `options.maxWaitTime` if needed. The
execution is suspended (not polling) — zero resource consumption while waiting.

### Critical constraint

`$execution.resumeUrl` is ONLY available at execution time and ONLY AFTER the
workflow has been activated (not in test/manual runs in the UI). For the Loom demo:
activate the workflow, trigger via webhook, then tap the Telegram button. If you
run via "Test Workflow" in the UI, the resume URL will be undefined.

---

## Node Graph — Names and Types

| # | Node Name | Type | typeVersion | Notes |
|---|-----------|------|-------------|-------|
| 1 | `Lead Intake` | `n8n-nodes-base.webhook` | 2 | POST /sdr-lead, responseMode: lastNode |
| 2 | `Normalize Lead` | `n8n-nodes-base.set` | 3.4 | Map name/email/company; trim whitespace |
| 3 | `Dedup Check` | `n8n-nodes-base.code` | 2 | In-memory email set; emit or halt |
| 4 | `Hunter Enrich` | `n8n-nodes-base.httpRequest` | 4.2 | GET https://api.hunter.io/v2/people/find; neverError: true |
| 5 | `Merge Enrichment` | `n8n-nodes-base.set` | 3.4 | Spread lead + hunter fields |
| 6 | `Generate Outreach` | `@n8n/n8n-nodes-langchain.openAi` | 1.8 | gpt-4o-mini, structured JSON, system + user prompt |
| 7 | `Parse Outreach JSON` | `n8n-nodes-base.code` | 2 | JSON.parse; onError: continueErrorOutput |
| 8 | `Fallback Outreach` | `n8n-nodes-base.set` | 3.4 | Static subject+body if parse fails |
| 9 | `Send Telegram Preview` | `n8n-nodes-base.telegram` | 1.2 | Credential from UI; inline keyboard |
| 10 | `Wait for Approval` | `n8n-nodes-base.wait` | 1 | resume: webhook; timeout: 1h |
| 11 | `Route Decision` | `n8n-nodes-base.if` | 2 | $json.query.action === 'approve' |
| 12 | `Send Email` | `n8n-nodes-base.httpRequest` | 4.2 | POST https://api.resend.com/emails; Header Auth |
| 13 | `Create Calendar Event` | `n8n-nodes-base.googleCalendar` | 1.3 | OAuth; summary + description + booking link |
| 14 | `HubSpot Upsert Contact` | `n8n-nodes-base.hubspot` | 2 | Contact: email as unique key |
| 15 | `HubSpot Create Deal` | `n8n-nodes-base.hubspot` | 2 | Deal linked to contact; stage: lead_sent |
| 16 | `Mark Rejected` | `n8n-nodes-base.hubspot` | 2 | Contact + note: "Outreach rejected via HITL" |
| 17 | `Respond 200` | `n8n-nodes-base.respondToWebhook` | 1.1 | Fires on intake; responseMode: lastNode |

**Error branches:** nodes 4 (`Hunter Enrich`), 6 (`Generate Outreach`), 12 (`Send Email`)
use `onError: continueErrorOutput`. Their error branches emit a Set node with
`status: "error"` + `error_step` field, then terminate gracefully.

---

## Interfaces / Contracts

### Lead Intake Payload (POST /sdr-lead)

```json
{
  "name": "Martín Gómez",
  "email": "martin@nexocrm.io",
  "company": "NexoCRM"
}
```

### Normalized Lead Item (after node 2)

```json
{
  "name": "Martín Gómez",
  "email": "martin@nexocrm.io",
  "company": "NexoCRM",
  "received_at": "2026-06-09T12:00:00Z"
}
```

### Enriched Lead Item (after node 5)

```json
{
  "name": "...", "email": "...", "company": "...", "received_at": "...",
  "position": "CEO",
  "linkedin_url": "https://linkedin.com/in/...",
  "domain": "nexocrm.io",
  "hunter_confidence": 92,
  "hunter_found": true
}
```

### Outreach JSON (structured output from node 6)

```json
{
  "subject": "¿Cómo NexoCRM está automatizando su pipeline de ventas?",
  "body": "Hola Martín, ..."
}
```

### HubSpot Objects

- **Contact**: `email` (unique), `firstname`, `lastname`, `company`, `jobtitle`
- **Deal**: `dealname` = "{company} — SDR Demo", `pipeline` = "default", `dealstage` = "appointmentscheduled", `amount` = 0, associated contact ID

### Environment Variables

```
# n8n core
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/

# Access guards (REQUIRED)
N8N_RESTRICT_FILE_ACCESS_TO=/data
N8N_BLOCK_ENV_ACCESS_IN_NODE=false

# API keys (read via $env in workflow expressions)
OPENAI_API_KEY=sk-...
HUNTER_API_KEY=...
RESEND_API_KEY=re_...
HUBSPOT_ACCESS_TOKEN=pat-...

# Telegram (CHAT_ID via $env; bot token via UI credential)
TELEGRAM_CHAT_ID=...

# Calendar booking link (static — injected into email CTA)
CALENDLY_LINK=https://calendly.com/...
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `workflows/sdr-pipeline-main.json` | Create | Core pipeline — all 17 nodes |
| `workflows/sdr-test-trigger.json` | Create | Loops sample-leads.json, POSTs each to main webhook |
| `data/sample-leads.json` | Create | 5 fictional LATAM leads with real company domains |
| `prompts/outreach-system.txt` | Create | System prompt: ICP persona, tone, JSON output schema |
| `prompts/outreach-user.txt` | Create | User prompt template with enrichment variables |
| `docker-compose.yml` | Create | n8n service; hardening vars; no file volume needed |
| `.env.example` | Create | All vars from the env section above |
| `docs/architecture.md` | Create | Sequence diagram + node-by-node walkthrough |
| `README.md` | Modify | Fill stack decisions, quickstart, Loom link |

---

## Testing Strategy

No automated test runner (JSON project). Validation is manual.

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Node-by-node | Each node's output shape | Trigger via webhook; inspect n8n execution log |
| Happy path | Full approve flow end-to-end | Activate workflow; POST lead; tap Approve in Telegram; verify email + calendar + HubSpot |
| Reject path | Rejection branch | POST lead; tap Reject; verify HubSpot note created, email NOT sent |
| Error path | Hunter 4xx / OpenAI error | Temporarily break API key; confirm error branch fires, no silent halt |
| Dedup | Duplicate email | POST same email twice; confirm second call halts at Dedup Check |
| 0-output guard | No silent halts | Inspect every node: 0 output items = bug; add `alwaysOutputData` where needed |

---

## Migration / Rollout

No migration required. Greenfield. Deployment steps:

1. `docker compose up -d`
2. Import `workflows/sdr-pipeline-main.json` via n8n REST API (POST /api/v1/workflows)
3. Re-attach credentials (PUT wipes credentials — always re-attach on push)
4. Import `workflows/sdr-test-trigger.json`
5. Activate `sdr-pipeline-main` in UI (required for $execution.resumeUrl to work)
6. POST a sample lead and walk through the full flow

Rollback: `git checkout workflows/*.json` then re-import. Cost < 5 min.

---

## Open Questions

- [ ] Is the Telegram bot token the same one from @homelessarchitect_bot (sibling), or does this demo need its own bot? Answer determines credential setup step.
- [ ] Google Calendar OAuth — already provisioned in n8n from sibling, or needs re-auth? If fresh container, OAuth flow required before build.
- [ ] HubSpot pipeline and stage IDs — must query HubSpot API after account creation; stage `"appointmentscheduled"` is the default in HubSpot Free but pipeline ID varies per account.
- [ ] `$execution.resumeUrl` availability in older n8n versions — confirm n8n version running in Docker is >= 1.22 (when Wait node resume via webhook was stabilized).
