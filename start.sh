#!/bin/sh
set -e
export GOGC=30
export GOMEMLIMIT=85MiB

PORT="${PORT:-80}"
if [ "$PORT" != "80" ]; then
    sed -i "s/:80/:$PORT/g" /etc/caddy/Caddyfile
fi

UUID="${UUID:-8f4e2c1a-7b9d-4e3f-9a12-5d6c8e0f1a2b}"
sed -i "s/UUID_PLACEHOLDER/$UUID/g" /etc/xray/config.json

echo "=== STARTING XRAY & CADDY | PORT=$PORT | UUID=$UUID ==="

GOMEMLIMIT=40MiB /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &
if [ -n "$CF_TOKEN" ] && ! pgrep -x cloudflared >/dev/null 2>&1; then
    /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" >/var/log/cloudflared.log 2>&1 &
fi

exec /usr/local/bin/xray run -config /etc/xray/config.json
