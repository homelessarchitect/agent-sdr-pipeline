# agent-sdr-pipeline

**AI SDR pipeline on n8n.** A raw lead enters as a name + email and exits as a personalized outreach email, a calendar event, and a CRM record — untouched by human hands except for **one approval tap on Telegram**.

🎬 **[Watch the 5-minute demo (Loom)](https://www.loom.com/share/0c3c716d649d427d87434d7218cbd70f)**

## What it does

```
Lead (form / webhook / CSV)
  → normalize + dedup against CRM   (before spending on APIs)
  → enrich (Hunter.io)
  → AI writes the outreach (OpenAI)
  → 📲 human approves or rejects from Telegram   ← the pipeline PAUSES here
       ├─ approve → email (Resend) → calendar event → HubSpot contact + deal
       └─ reject  → HubSpot contact marked "rejected" (the "no" is also tracked)
```

One POST in, four outcomes out. Full architecture in [`docs/architecture.md`](docs/architecture.md).

## Why human-in-the-loop

Everything **before** the Wait node is reversible (reads + a draft). Everything **after** touches the real world (email, calendar, CRM). The human decides exactly at the point of no return — from a phone, anywhere. This is the answer to "AI SDR that spams on its own".

## Stack

| Concern | Choice |
|---|---|
| Orchestration | n8n (self-hosted, Docker) |
| LLM | OpenAI (JSON-validated output + static fallback) |
| Enrichment | Hunter.io |
| Email | Resend |
| Booking | Google Calendar |
| CRM | HubSpot (free tier) |
| Approval channel | Telegram inline buttons |
| Public approval URLs | Cloudflare quick tunnel (runtime discovery — zero config) |

Everything runs on free tiers.

## Quickstart

**Prerequisites:** Docker, `cloudflared` (`brew install cloudflared`), and accounts/keys for OpenAI, Hunter.io, Resend, HubSpot (private app token), a Telegram bot, and a Google Cloud project with the Calendar API enabled.

```bash
git clone https://github.com/homelessarchitect/agent-sdr-pipeline.git
cd agent-sdr-pipeline
cp .env.example .env          # fill in your keys
docker compose up -d           # n8n at http://localhost:5678
```

1. **Import workflows** — in the n8n UI import the three files from `workflows/`:
   `sdr-pipeline-main.json`, `sdr-form-intake.json`, `sdr-test-trigger.json`.
2. **Create credentials** (n8n UI → Credentials) and attach them where nodes ask:

   | n8n credential | Type | Value |
   |---|---|---|
   | OpenAI | OpenAI API | your API key |
   | Telegram | Telegram API | bot token (also set your own `chatId` in the Telegram nodes) |
   | Hunter-API | HTTP Query Auth | `api_key` = Hunter key |
   | Resend-API | HTTP Header Auth | `Authorization: Bearer <key>` |
   | HubSpot-API | HTTP Header Auth | `Authorization: Bearer <private app token>` |
   | Google Calendar | Google Calendar OAuth2 | OAuth client + sign in |

3. **Start the tunnel** — `./scripts/start-tunnel.sh`. Telegram rejects `localhost` URLs in
   inline buttons; the pipeline discovers the tunnel's public URL at runtime, so the
   ephemeral hostname never needs configuring.
4. **Activate** `SDR Pipeline Main` and `SDR Form Intake`.
5. **Fire a lead** — open `http://localhost:5678/form/sdr-lead-form`, or:

   ```bash
   curl -X POST http://localhost:5678/webhook/sdr-lead \
     -H "Content-Type: application/json" \
     -d '{"name":"Martín Gómez","email":"martin@nexocrm.io","company":"NexoCRM","position":"CEO","domain":"nexocrm.io"}'
   ```

   Approve from the Telegram message and watch the email, calendar event, and
   HubSpot contact + deal appear.

## Design decisions worth stealing

- **Dedup before spend** — the CRM duplicate check runs before Hunter and OpenAI, so a repeated lead costs zero API credits.
- **Degrade, don't collapse** — enrichment failure continues with `confidence: failed`; LLM failure falls back to a static template; a calendar error alerts the operator and the CRM write still runs. Every error branch notifies Telegram. Loud failure > silent halt.
- **Ingestion ≠ processing** — the form workflow is an *adapter* that maps fields and POSTs to the same webhook. New sources (lead ads, chatbots, CSV batches via `sdr-test-trigger`) plug in without touching the pipeline.
- **Runtime tunnel discovery** — approval buttons need public URLs; a Code node reads the cloudflared metrics endpoint per execution, so tunnel restarts require no reconfiguration.

## Demo notes (intentional shortcuts)

- Resend free tier only delivers to the account owner's inbox — the email `to` is overridden in the Send Email node. In production: verified domain + the lead's address.
- The Telegram `chatId` is hardcoded in the alert/preview nodes — replace with your own.
- This is a **demo, not a product**: one channel, one CRM pipeline, one ICP. No multi-tenant, no dashboards, no sequencing engine.

## Project structure

```
workflows/    n8n workflow JSON (source of truth, import these)
prompts/      system + user prompts for outreach generation
scripts/      start-tunnel.sh
data/         sample leads for the test trigger
docs/         architecture deep-dive + Loom recording script
openspec/     SDD planning artifacts (proposal → specs → design → tasks)
```
