# Tasks: SDR Pipeline Core

## Phase 0: Stack Validation (GATE — must complete before provider-specific tasks)

- [ ] 0.1 [HUMAN] Confirm stack decisions: D1 Hunter.io, D2 Resend, D3 HubSpot Free, D4 Telegram HITL. Record final answer before proceeding to Phase 2.
- [ ] 0.2 [HUMAN] Confirm n8n instance to use: same container as agent-whatsapp-rag (recommended — reuses Telegram credential id `2FS5wXdKOH1ubUwk` and the running container). Record the base URL (e.g. `http://localhost:5678`).
- [ ] 0.3 Verify n8n Docker image version >= 1.22 (`docker inspect <container> | grep Image`). `$execution.resumeUrl` is undefined on earlier versions — pipeline cannot work without this.

---

## Phase 1: Infrastructure & Credentials (HUMAN-blocked items marked)

- [ ] 1.1 [HUMAN] Create Hunter.io account (free tier). Generate API key. Keep ready for n8n credential creation.
- [ ] 1.2 [HUMAN] Create Resend account (free tier). Generate API key. Configure a sender domain (or use `onboarding@resend.dev` for dev/demo). Keep ready.
- [ ] 1.3 [HUMAN] Create HubSpot Free account. Create a Private App with scopes: `crm.objects.contacts.write`, `crm.objects.deals.write`, `crm.objects.contacts.read`. Copy the access token.
- [ ] 1.4 [HUMAN] After HubSpot account is live, query pipeline ID and stage ID: `GET https://api.hubapi.com/crm/v3/pipelines/deals` with the token. Record `pipeline` (default) and `dealstage` (first stage ID) — these are account-specific and required by node 15.
- [ ] 1.5 [HUMAN] Confirm Google Calendar OAuth credential in n8n (reuse from sibling if available). If fresh: enable Calendar API in the GCP Cloud project (`Google Calendar API` must be enabled — 403 without it); complete OAuth flow in n8n UI (Credentials → New → Google Calendar OAuth2).
- [ ] 1.6 In n8n UI: add HTTP Header Auth credential named `Resend-API` with `Authorization: Bearer <RESEND_API_KEY>`. Verify: credential appears in list, no validation error.
- [ ] 1.7 In n8n UI: add HTTP Query Auth credential named `Hunter-API` with `api_key=<HUNTER_API_KEY>`. (Or use Generic Credential Type with query param.) Verify credential saved.
- [ ] 1.8 In n8n UI: add HubSpot credential (type: HubSpot API, token = Private App token). Verify: n8n HubSpot node accepts it.
- [x] 1.9 Create `docker-compose.yml` at repo root. Include n8n service with hardening env vars: `N8N_RESTRICT_FILE_ACCESS_TO=/data` and `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`. Map port 5678. Add `data/` volume for workflow persistence.
- [x] 1.10 Create `.env.example` at repo root with all required vars: `N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL`, `WEBHOOK_URL`, `OPENAI_API_KEY`, `HUNTER_API_KEY`, `RESEND_API_KEY`, `HUBSPOT_ACCESS_TOKEN`, `TELEGRAM_CHAT_ID`, `CALENDLY_LINK`.

---

## Phase 2: Workflow Skeleton — Decision-Independent Nodes (no credentials required)

_These tasks can start as soon as Phase 0 is done, regardless of Phase 1 HUMAN items._

- [x] 2.1 Create `workflows/sdr-pipeline-main.json` with nodes 1–3 (Lead Intake webhook, Normalize Lead Set, Dedup Check Code). `settings.executionOrder: "v1"`. Webhook path: `/sdr-lead`, `responseMode: lastNode`. Verify: POST to webhook returns 200; execution log shows 1 item after Normalize Lead.
- [x] 2.2 Write `data/sample-leads.json` with 5 LATAM leads (Martín Gómez, Valentina Ríos, Diego Paredes, Camila Torres, Sebastián Vera — real company domains from proposal). File must be valid JSON array. Verify: `cat data/sample-leads.json | python3 -m json.tool` exits 0.
- [x] 2.3 Write `prompts/outreach-system.txt`: ICP persona (LATAM B2B SaaS SDR), tone (direct, warm, Spanish), JSON schema instruction (`{"subject": "...", "body": "..."}`), max constraints (subject ≤ 9 words, body ≤ 120 words, 1 CTA = Calendly link).
- [x] 2.4 Write `prompts/outreach-user.txt`: template with `{{ name }}`, `{{ company }}`, `{{ position }}`, `{{ domain }}`, `{{ calendly_link }}` placeholders. Include fallback copy when enrichment fields are empty.
- [x] 2.5 Add nodes 6–8 to `sdr-pipeline-main.json` (Generate Outreach OpenAI node, Parse Outreach JSON Code node, Fallback Outreach Set node). Wire 6→7→8 with `onError: continueErrorOutput` on node 7. Verify: with a mocked lead item, node 6 outputs `message.content` with valid JSON; node 7 outputs `{ subject, body }`.
- [x] 2.6 Add node 10 (Wait for Approval) to `sdr-pipeline-main.json`. Config: `resume: "webhook"`, `options.webhookSuffix: ""`, timeout `options.maxWaitTime: 3600`. Verify: execution halts at Wait node; n8n execution log shows status "waiting".
- [x] 2.7 Add node 11 (Route Decision IF) wired after Wait. Condition: `$json.query.action === 'approve'`. Verify: creates two output branches (true/false) in the workflow graph.

---

## Phase 3: Provider-Specific Nodes (requires Phase 0 gate and Phase 1 credentials)

- [ ] 3.1 Add node 4 (Hunter Enrich HTTP Request) to `sdr-pipeline-main.json`. URL: `https://api.hunter.io/v2/people/find?email={{ $json.email }}&company={{ $json.company }}`. Attach `Hunter-API` credential. Set `neverError: true`. Verify: live call with `martin@nexocrm.io` + `NexoCRM` returns ≥ 1 item; execution log shows `data.result` or confidence field.
- [ ] 3.2 Add node 5 (Merge Enrichment Set) after Hunter Enrich. Spread all fields from `$('Normalize Lead').first().json` plus `position`, `linkedin_url`, `domain`, `hunter_confidence`, `hunter_found` from `$json.data.result`. Verify: item after node 5 contains both lead fields and hunter fields.
- [ ] 3.3 Add node 9 (Send Telegram Preview) after node 8. Message format: lead name, company, enrichment confidence, subject preview, body preview. Inline keyboard: two URL buttons — "Aprobar" (`={{ $execution.resumeUrl }}?action=approve`) and "Rechazar" (`={{ $execution.resumeUrl }}?action=reject`). Attach Telegram credential from UI (credential id `2FS5wXdKOH1ubUwk` if reusing sibling). Verify: authoring only — do NOT live-test yet (resumeUrl is undefined in manual runs).
- [ ] 3.4 Add node 12 (Send Email HTTP Request) on approve branch. POST `https://api.resend.com/emails`. Body: `{ "from": "<sender>", "to": "{{ $json.email }}", "subject": "{{ $json.subject }}", "text": "{{ $json.body }}" }`. Attach `Resend-API` credential. Set `onError: continueErrorOutput`. Verify: live call with a test email returns 200 + `messageId` in execution log.
- [ ] 3.5 Add node 13 (Create Calendar Event Google Calendar) on approve branch after node 12. Fields: `summary` = `"Outreach: {{ $json.name }} / {{ $json.company }}"`, `description` = body + Calendly link, `start.dateTime` = next business day 10:00 AM. Attach Google Calendar OAuth credential. Verify: event appears in calendar after live approval run.
- [ ] 3.6 Add node 14 (HubSpot Upsert Contact) on approve branch after node 13. Fields: `email`, `firstname`, `lastname`, `company`, `jobtitle` from enriched lead, `outreach_status: "sent"`. Use upsert endpoint (email as unique key). Attach HubSpot credential. Verify: contact appears (or updates) in HubSpot after run.
- [ ] 3.7 Add node 15 (HubSpot Create Deal) chained after node 14 on approve branch. `dealname` = `"{{ $json.company }} — SDR Demo"`. Use pipeline ID and dealstage ID collected in task 1.4. Associate with contact ID from node 14 output. Verify: deal appears in HubSpot linked to contact.
- [ ] 3.8 Add node 16 (Mark Rejected HubSpot) on reject branch from node 11. Upsert contact with `outreach_status: "rejected"`, add note `"Outreach rejected via HITL"`. Attach HubSpot credential. Verify: after reject tap, contact note appears in HubSpot; no email/calendar in execution log.
- [ ] 3.9 Add node 17 (Respond 200) as final node on both branches OR wired at intake. `responseMode: lastNode` pairs with Webhook node config. Verify: POST to webhook receives HTTP 200 response, not timeout.
- [ ] 3.10 Add error-alert branches for nodes 4, 6, 12 (Hunter, OpenAI, Resend). Each error output → Telegram message to operator: `"Error in {{ step }}: {{ $json.error.message }} — lead: {{ $json.email }}"`. Verify: break one API key → alert fires in Telegram, no silent 0-item halt.
- [ ] 3.11 Add error-alert branch for node 13 (Calendar). On error: Telegram alert → node 14 (CRM) still executes. REQ-18: calendar errors are non-fatal; CRM must run after alert. Verify: simulate 403 → alert fires → HubSpot node executes.

---

## Phase 4: Test Trigger Workflow

- [x] 4.1 Create `workflows/sdr-test-trigger.json`. Code node reads `data/sample-leads.json`; iterates via SplitInBatches; HTTP Request node POSTs each lead to main webhook URL. Verify: trigger workflow POSTs 5 items; 5 executions appear in main workflow execution log.

---

## Phase 5: Live End-to-End Verification (ACTIVATED workflow only)

_All tasks in this phase require the workflow to be ACTIVATED — not run via "Test Workflow" in n8n UI. Use production webhook URL._

- [ ] 5.1 Activate `sdr-pipeline-main` in n8n UI. Verify: workflow status = active; webhook URL is live (GET returns 405, not 404).
- [ ] 5.2 Live happy path: POST `martin@nexocrm.io` lead to webhook → confirm Telegram notification arrives with Approve/Reject buttons → tap Aprobar → verify email in inbox, Calendar event created, HubSpot contact+deal visible. All 4 outcomes required (REQ-10, REQ-14, REQ-17, REQ-19, REQ-20).
- [ ] 5.3 Live reject path: POST `vrios@agentelab.com` lead → tap Rechazar → verify HubSpot contact has `outreach_status: "rejected"`, NO email sent, NO calendar event (REQ-11, REQ-21).
- [ ] 5.4 Dedup path: POST `martin@nexocrm.io` a second time → verify pipeline halts at Dedup Check with "duplicate — skipped"; no Telegram sent (REQ-03, REQ-22).
- [ ] 5.5 Enrichment error path: temporarily set invalid Hunter API key → POST lead → verify pipeline continues to HITL with `enrichment_confidence: "failed"` visible in Telegram message (REQ-06). Restore key after.
- [ ] 5.6 Double-click guard: complete an approval run; manually re-tap Approve from the same Telegram message (or re-hit the resumeUrl) → verify n8n rejects second call (REQ-13); single email, single CRM record.
- [ ] 5.7 Wait timeout: configure `maxWaitTime: 60` (1 min) temporarily → POST lead → do NOT tap → confirm execution terminates after 60s with no email/calendar/CRM (REQ-12). Restore to 3600 after.

---

## Phase 6: Documentation & Demo Assets

- [ ] 6.1 Create `docs/architecture.md`. Include: sequence diagram (text/mermaid), node-by-node table (name, type, typeVersion, purpose), Wait/resume mechanics explanation, credential map. Verify: file renders in GitHub without errors.
- [ ] 6.2 Update `README.md`: stack decisions (D1–D4 final), quickstart (clone → docker-compose up → import workflows → set credentials → activate → POST sample lead), prerequisites, Loom link placeholder.
- [ ] 6.3 Record Loom walkthrough. Required shots: webhook POST visible, enrichment node output, Telegram notification with buttons, Approve tap on camera, email in inbox, Calendar event, HubSpot contact+deal. Duration: ≤ 5 min. Paste link in README.
