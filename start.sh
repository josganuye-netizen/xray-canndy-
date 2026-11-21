#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# Pakai UUID dari Environment Variable (atau otomatis generate kalau kosong)
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
sed -i "s/UUID_PLACEHOLDER/$UUID/g" /etc/xray/config.json
echo "Active VLESS UUID: $UUID"

# 1. Jalankan Xray
/usr/local/bin/xray run -config /etc/xray/config.json >/var/log/xray.log 2>&1 &

# 2. Jalankan Caddy
GOMEMLIMIT=40MiB /usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &

# 3. Jalankan Cloudflare Tunnel
if [ -n "$CF_TOKEN" ]; then
    /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" >/var/log/cloudflared.log 2>&1 &
fi

tail -f /dev/null
