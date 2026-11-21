#!/bin/sh
export GOGC=30
export GOMEMLIMIT=85MiB

PORT="${PORT:-80}"
if [ "$PORT" != "80" ]; then
    sed -i "s/:80/:$PORT/g" /etc/caddy/Caddyfile
fi

UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
sed -i "s/UUID_PLACEHOLDER/$UUID/g" /etc/xray/config.json
echo "=== Active Port: $PORT | UUID: $UUID ==="

/usr/local/bin/xray run -config /etc/xray/config.json >/var/log/xray.log 2>&1 &
GOMEMLIMIT=40MiB /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &

if [ -n "$CF_TOKEN" ]; then
    /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" >/var/log/cloudflared.log 2>&1 &
fi

tail -f /var/log/caddy.log /var/log/xray.log
