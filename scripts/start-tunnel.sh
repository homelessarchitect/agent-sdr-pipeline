#!/usr/bin/env bash
# Expone el n8n local con un quick tunnel de Cloudflare para que los botones
# de aprobación de Telegram funcionen (Telegram rechaza URLs localhost en
# inline keyboards). El workflow descubre la URL pública en runtime vía el
# endpoint de métricas (/quicktunnel) — no hay que actualizar nada a mano.
#
# Correr ANTES de disparar leads. Dejarlo corriendo solo durante la demo:
# el túnel expone la instancia n8n completa (con su login) a internet.
set -euo pipefail

METRICS_PORT=20241

pkill -f "cloudflared tunnel --url http://localhost:5678" 2>/dev/null || true
sleep 1

cloudflared tunnel --url http://localhost:5678 --metrics 127.0.0.1:$METRICS_PORT >/tmp/cloudflared-sdr.log 2>&1 &

for _ in $(seq 1 30); do
  hostname=$(curl -s "http://127.0.0.1:$METRICS_PORT/quicktunnel" 2>/dev/null |
    python3 -c 'import sys,json;print(json.load(sys.stdin).get("hostname",""))' 2>/dev/null || true)
  if [ -n "$hostname" ]; then
    echo "Tunnel up: https://$hostname"
    exit 0
  fi
  sleep 1
done

echo "El túnel no levantó — revisar /tmp/cloudflared-sdr.log" >&2
exit 1
