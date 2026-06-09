# agent-sdr-pipeline

> 🚧 **In development** — demo build, not a product.

**AI SDR pipeline.** Raw lead → enrichment → AI-personalized outreach → booked meeting → CRM. The full revenue motion as an automated system, with a human approving every outbound message.

**The hook:** a lead enters as a name + email and exits as a calendar event and a CRM record — untouched by hands until the approval step.

## Planned stack

- **Orchestration:** n8n
- **LLM:** Claude (Anthropic API) for personalization
- **Enrichment:** single provider (kept simple on purpose)
- **Channel:** one outreach channel only
- **Booking:** Google Calendar
- **CRM:** single pipeline
- **Safety net:** human-in-the-loop approval before anything is sent

## Scope guardrail

This is a **demo**: one channel, one CRM pipeline, one ICP. No multi-channel sequencing engine.

## Status

- [ ] SDD planning (proposal → spec → design → tasks)
- [ ] Build
- [ ] Loom walkthrough
