#!/bin/sh
export GOGC=30
export GOMEMLIMIT=85MiB

PORT="${PORT:-80}"
sed -i "s/:80/:$PORT/g" /etc/caddy/Caddyfile

UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
sed -i "s/UUID_PLACEHOLDER/$UUID/g" /etc/xray/config.json
echo "=== Active Port: $PORT | UUID: $UUID ==="

/usr/local/bin/xray run -config /etc/xray/config.json &

if [ -n "$CF_TOKEN" ]; then
    /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" &
fi

export GOMEMLIMIT=40MiB
exec /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
