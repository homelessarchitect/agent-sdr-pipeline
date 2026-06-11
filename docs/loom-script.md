# Guion del Loom — AI SDR Pipeline (≤ 5 min)

> Demo en cámara del happy path completo + reject path. Cubre los shots requeridos
> por la task 6.3: POST visible, enrichment output, Telegram con botones, tap Aprobar
> en cámara, email en inbox, evento en Calendar, contacto+deal en HubSpot.

## Pre-flight (antes de apretar grabar)

- [ ] n8n arriba: `curl -s http://localhost:5678/healthz` → `{"status":"ok"}`
- [ ] **Túnel arriba: `./scripts/start-tunnel.sh`** — sin túnel, el nodo
      `Build Approval Links` corta con error claro (Telegram no acepta botones
      apuntando a localhost). Apagarlo al terminar: expone el n8n a internet.
- [ ] Workflow `SDR Pipeline Main` ACTIVO en la UI
- [ ] Borrar de la UI las ejecuciones viejas en estado `waiting` (panel limpio en cámara)
- [ ] Telegram abierto — los botones **✅ Aprobar / ❌ Rechazar** son inline keyboard
      real con URL pública del túnel: funcionan desde el Desktop Y desde el celular
- [ ] Ventanas listas (en este orden de aparición):
  1. Terminal con los dos `curl` ya tipeados en el historial
  2. n8n — canvas del workflow + panel de executions
  3. Telegram Desktop
  4. Gmail `darienplatzi@gmail.com` (ahí llega el email — Resend free tier)
  5. Google Calendar (vista semana)
  6. HubSpot — Contacts
- [ ] Ensayo opcional: correr el flujo con un lead inventado (`laura@demoflow.io`).
      Cualquier email nuevo pasa el dedup. Guardar `martin` y `ctorres` para el take.

## Leads del take

```bash
# Happy path (Aprobar)
curl -X POST http://localhost:5678/webhook/sdr-lead \
  -H "Content-Type: application/json" \
  -d '{"name":"Martín Gómez","email":"martin@nexocrm.io","company":"NexoCRM","position":"CEO","domain":"nexocrm.io"}'

# Reject path (Rechazar)
curl -X POST http://localhost:5678/webhook/sdr-lead \
  -H "Content-Type: application/json" \
  -d '{"name":"Camila Torres","email":"ctorres@autonova.lat","company":"Autonova","position":"Founder","domain":"autonova.lat"}'
```

## Minuto a minuto

### 0:00–0:30 — Hook + problema (cara o canvas de n8n)
> "Esto es un AI SDR: entra un lead, se enriquece solo, la IA escribe el outreach,
> y un humano aprueba desde Telegram antes de que salga nada. Email, cita y CRM,
> todo automático. Te lo muestro de punta a punta."

### 0:30–1:00 — Arquitectura (canvas de n8n)
Recorrer el canvas de izquierda a derecha SIN entrar en detalle. Señalar tres cosas:
1. Dedup ANTES de gastar en APIs (corta duplicados sin quemar créditos)
2. El nodo **Wait** — "acá el pipeline se pausa y espera a un humano"
3. Las ramas de error → alertas a Telegram (degrada, no colapsa)

### 1:00–1:30 — Disparo (formulario en el navegador)
Abrir `http://localhost:5678/form/sdr-lead-form` y llenar el form con Martín en cámara
(workflow `SDR Form Intake` lo mapea y POSTea al webhook). LA frase clave:
> "Este formulario es una fuente más: por detrás hay un webhook, así que acá se
> enchufa tu landing, tus Lead Ads o tu lista de prospección — cualquier cosa
> que haga un POST."
Alternativa minimalista: el `curl` en terminal (mismo efecto, menos visual).

### 1:30–2:15 — Ejecución en vivo (n8n executions)
Abrir la ejecución que acaba de aparecer. Mostrar:
- Output de **Hunter Enrich** / **Merge Enrichment**: el lead ahora tiene cargo,
  LinkedIn, confidence. (Si Hunter no encuentra el dominio fake: narrarlo a favor —
  "no lo encontró, y el pipeline sigue igual marcando la confianza como baja")
- Output de **Generate Outreach**: el subject y el body que escribió la IA
- La ejecución detenida en **Wait for Approval** (estado waiting)

### 2:15–2:45 — HITL (Telegram)
Mostrar el mensaje: preview del lead + subject + body y los botones inline
**✅ Aprobar / ❌ Rechazar** (URL pública vía túnel — funcionan desde cualquier
dispositivo).
> "Nada salió todavía. El humano decide en el punto exacto de no retorno —
> desde el celular, desde donde sea."
Click en **Aprobar** en cámara (Telegram Desktop para que quede en pantalla).

### 2:45–3:45 — Los 4 resultados (una ventana por resultado, ritmo rápido)
1. **Gmail**: el email de outreach en el inbox (aclarar: "free tier de Resend entrega
   al dueño de la cuenta; en producción va al lead con dominio verificado")
2. **Google Calendar**: evento "Outreach: Martín Gómez / NexoCRM" — mañana 10:00
3. **HubSpot**: contacto martin@nexocrm.io con `outreach_status: sent`
4. **HubSpot**: deal "NexoCRM — SDR Demo" asociado al contacto
> "Un POST. Cuatro resultados. Cero copy-paste."

### 3:45–4:30 — Reject path (cierre técnico)
Correr el `curl` de Camila → llega el Telegram → tap **Rechazar**.
Mostrar en HubSpot: contacto con `outreach_status: rejected` + nota, SIN email,
SIN evento.
> "El 'no' del humano también queda registrado en el CRM. Trazabilidad completa."

### 4:30–5:00 — Cierre + CTA
> "Stack: n8n, OpenAI, Hunter, Resend, Google Calendar y HubSpot — todo en tiers
> gratuitos. El repo está en GitHub con el setup completo. Si querés esto conectado
> a TU formulario y TU CRM, hablemos."

## Contingencias durante el take

| Pasa esto | Hacés esto |
|---|---|
| Telegram llega sin botones / nodo Build Approval Links en error | El túnel no está corriendo → `./scripts/start-tunnel.sh` y retake |
| Hunter no enriquece (dominio fake) | Narrarlo como graceful degradation — suma, no resta |
| No llega el Telegram | Revisar ejecución en n8n; si murió, retake con lead inventado nuevo |
| El email tarda en Gmail | Seguir con Calendar/HubSpot y volver al inbox al final |
| Quemaste martin y ctorres | Borrar los contactos en HubSpot o inventar lead nuevo |
