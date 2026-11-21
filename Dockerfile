FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip \
    && unzip /tmp/xray.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -f /tmp/xray.zip

RUN curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=amd64" -o /usr/bin/caddy \
    && chmod +x /usr/bin/caddy

RUN curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

RUN mkdir -p /etc/xray /etc/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY config.json /etc/xray/config.json
COPY start.sh /start.sh

RUN chmod +x /start.sh && caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

CMD ["/bin/sh", "/start.sh"]
