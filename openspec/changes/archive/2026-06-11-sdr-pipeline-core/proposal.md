# Proposal: SDR Pipeline Core

## Intent

Build a end-to-end AI SDR pipeline as a portfolio demo that shows the full revenue
motion automated — raw lead → enrichment → personalized outreach → HITL approval →
send → calendar event → CRM record — with no human hands except the approval gate.

Target: 2-3 day timebox. The scope constraint IS part of what the demo sells
("piensa en sistemas de negocio, no en bots sueltos").

## Scope

### In Scope

- Lead intake via webhook (CSV row or single JSON payload: name + email + company)
- Enrichment via ONE provider (decision D1 below)
- LLM-generated outreach message using enrichment data (gpt-4o-mini, one CTA)
- HITL approval gate via ONE mechanism (decision D4 below)
- Send via ONE channel (decision D2 below) — only after approval
- Google Calendar event creation on approval
- CRM record creation in ONE target (decision D3 below)
- Sample lead set: 5 fictional LATAM B2B SaaS leads for the Loom demo
- Repo: `workflows/` (n8n JSON) + `docs/` (architecture diagram + README) + `sample-leads/`
- Deliverables: repo + Loom walkthrough + 1 build-in-public LinkedIn post

### Out of Scope

- Reply detection, follow-up cadences, multi-step sequences
- Lead sourcing / scraping
- Multi-channel or multi-ICP support
- Domain warmup, email deliverability tooling
- Dashboards, multi-tenant, or any product infrastructure
- Booking page (use a static Calendly/Cal.com link as the CTA — no integration needed)

## Fictional ICP + Demo Leads

**ICP:** LATAM B2B SaaS founders / agency owners, 5–50 employees, selling to other SMBs.
**Outreach language:** Spanish (aligns with Workana/LATAM market signal; differentiates
from English-only demos).

Sample leads (5):

| Name | Email | Company | Role |
|------|-------|---------|------|
| Martín Gómez | martin@nexocrm.io | NexoCRM | CEO |
| Valentina Ríos | vrios@agentelab.com | AgenteLab | Co-founder |
| Diego Paredes | d.paredes@pipefy.mx | Pipefy MX | Sales Lead |
| Camila Torres | ctorres@autonova.lat | Autonova | Founder |
| Sebastián Vera | svera@flowsync.co | FlowSync | Head of Growth |

## Open Decisions

### D1 — Enrichment Provider

| Option | Free tier | Data richness | API simplicity | Verdict |
|--------|-----------|---------------|----------------|---------|
| Hunter.io | 25 req/mo | Email + company domain, basic firmographics | REST, 1 call | ✅ RECOMMENDED |
| Apollo.io | 50 credits/mo | Rich: job title, LinkedIn URL, tech stack, headcount | REST, heavier schema | Good but overkill for demo |
| Clearbit (now Breyta/HubSpot) | None free | Richest | Well-documented | No free tier; ruled out |

**Recommendation (pending-user-validation):** Hunter.io. The free tier covers the 5 demo
leads with room to spare; the `/people/find` endpoint returns email confidence + company
domain in one call; simplicity keeps the demo focused on the pipeline, not the
enrichment layer.

### D2 — Outreach Channel

| Option | Setup cost | Demo credibility | Portfolio variety | Notes |
|--------|-----------|-----------------|-------------------|-------|
| Email (Gmail API) | Medium — OAuth in n8n | High | Good — distinct from WhatsApp demo | Gmail free; OAuth setup ~30 min with precedent from sibling |
| Email (SMTP/Resend free) | Low — API key only | High | Good | Resend free tier: 3k/mo; zero OAuth; single credential node |
| LinkedIn DM | High — requires unofficial API or manual | Medium | High | Scraping risk; no reliable n8n node |
| WhatsApp | Low — Cloud API already proven | High | **Duplicates sibling agent-whatsapp-rag** | Portfolio variety argues hard against this |

**Recommendation (pending-user-validation):** Email via Resend (transactional, free tier).
Zero OAuth friction, clean n8n credential (HTTP Header Auth), and the demo sends a
real email that lands in inbox — visible in the Loom. Gmail API is an alternative if
OAuth is already provisioned; prefer Resend for speed.

### D3 — CRM Target

| Option | Cost | Demo credibility | Setup time | Notes |
|--------|------|-----------------|------------|-------|
| Google Sheets | Free | Low–medium ("toy CRM") | ~5 min (OAuth already proven) | Gets the job done; looks basic |
| HubSpot Free | Free | High ("agency-real") | ~20 min (OAuth + API key) | Shows the actual tool agencies use; stronger demo story |
| Notion DB | Free | Medium | ~10 min (API key) | Looks modern but not a CRM signal |

**Recommendation (pending-user-validation):** HubSpot Free. The Workana demand signal
explicitly mentions HubSpot integration as a paid skill; showing it in the demo
converts the portfolio into a direct proof point. Setup cost is one OAuth connection
in n8n — acceptable within the 2-3 day timebox.

### D4 — HITL Approval Mechanism

| Option | Precedent | Setup | UX in Loom | Notes |
|--------|-----------|-------|------------|-------|
| Telegram + n8n Wait node (`onWebhookCall` + `$execution.resumeUrl` as inline buttons) | PROVEN — @homelessarchitect_bot live in sibling project | Near-zero (bot token already available) | Excellent — inline Approve/Reject buttons visible on camera | Recommended |
| Email approval link | None in this stack | Medium — needs unique token gen or webhook URL embed | Weak — email opens off-camera | Not recommended for demo |

**Recommendation (pending-user-validation):** Telegram HITL with n8n Wait node.
`$execution.resumeUrl` embedded as Approve / Reject inline keyboard buttons. Bot is
already live; the Loom money shot shows the notification arriving in Telegram and the
human tapping Approve — then the pipeline continues.

## Capabilities

### New Capabilities

- `lead-intake`: Webhook trigger accepting raw lead payload; normalization + schema validation
- `lead-enrichment`: Single-provider enrichment call; data merge onto lead object
- `outreach-generation`: LLM prompt producing personalized cold-email body (Spanish, one CTA)
- `hitl-approval-gate`: Telegram message with Wait node; blocks pipeline until Approve/Reject
- `outreach-send`: Send enriched + approved message via configured channel
- `calendar-booking`: Create Google Calendar event on approval
- `crm-record`: Upsert contact + deal record in configured CRM on approval

### Modified Capabilities

None — greenfield change.

## Approach

Single n8n workflow (main pipeline) orchestrating all capabilities in sequence:

```
Webhook → Normalize → Enrich (Hunter.io) → Generate copy (gpt-4o-mini)
  → Telegram HITL (Wait) → [Reject: stop] / [Approve: continue]
  → Send email (Resend) → Create Calendar event → Upsert HubSpot contact+deal → Done
```

All credentials stored as n8n credential objects (never hardcoded). Sample leads
triggered manually via n8n's "Test Workflow" or a small CSV-to-webhook helper workflow.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `workflows/sdr-pipeline-main.json` | New | Core pipeline workflow |
| `workflows/sdr-test-trigger.json` | New | Helper: sends sample lead rows via webhook |
| `sample-leads/leads.csv` | New | 5 fictional LATAM B2B leads |
| `docs/architecture.md` | New | Sequence diagram + node-by-node description |
| `README.md` | Modified | Fill in stack decisions, quickstart, Loom link |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hunter.io free tier exhausted mid-demo | Low (25 req; 5 leads) | Pre-run enrichments once; cache results in lead object |
| Resend email lands in spam during Loom | Med | Use a real receiving inbox; warm subject line; plain-text body |
| HubSpot OAuth setup takes >30 min | Low | Fallback to Google Sheets (swap one node) |
| n8n Wait node times out before approval in Loom | Low | Set resume timeout to 1h; approve within seconds |
| Telegram bot token not available | Very low | Bot proven live in sibling; reuse same token |

## Rollback Plan

All state lives in n8n workflow JSON files under `workflows/`. If a capability breaks:
1. Disable the affected node in n8n UI (node-level disable, no data loss)
2. Revert `workflows/*.json` via git checkout
3. Re-import via n8n REST API (`PUT /api/v1/workflows/{id}`)

No database migrations; no deployed services. Rollback cost: < 5 minutes.

## Dependencies

- n8n self-hosted Docker instance running (precedent from sibling project)
- Hunter.io account (free tier) + API key
- Resend account (free tier) + API key OR Gmail OAuth credential in n8n
- HubSpot Free account + Private App token
- Telegram bot token (reuse from @homelessarchitect_bot or create new)
- Google Calendar OAuth credential in n8n (already provisioned in sibling)
- OpenAI API key (gpt-4o-mini, already in use in sibling)

## Success Criteria — Loom Moments

- [ ] Lead enters as a single webhook call (name + email + company visible in payload)
- [ ] Enrichment node returns company data; AI message visible in execution log
- [ ] Telegram notification appears with Approve/Reject buttons and message preview
- [ ] Human taps Approve on camera; pipeline resumes in real time
- [ ] Email arrives in inbox (screenshare or phone visible in Loom)
- [ ] Google Calendar event created with prospect name + booking link
- [ ] HubSpot contact + deal record created, visible in HubSpot UI
- [ ] Total end-to-end time: < 2 minutes from webhook to CRM record
