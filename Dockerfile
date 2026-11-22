FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip tar python3 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip && unzip /tmp/xray.zip -d /usr/local/bin/ && chmod +x /usr/local/bin/xray && rm -f /tmp/xray.zip
RUN curl -fsSL https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_linux_amd64.tar.gz -o /tmp/caddy.tar.gz && tar -xzf /tmp/caddy.tar.gz -C /usr/bin caddy && chmod +x /usr/bin/caddy && rm -f /tmp/caddy.tar.gz
RUN curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
RUN mkdir -p /etc/xray /etc/caddy /var/log/xray /var/log/caddy && touch /var/log/xray.log /var/log/caddy.log
COPY Caddyfile /etc/caddy/Caddyfile
COPY config.json /etc/xray/config.json
COPY raw_proxy.py /app/raw_proxy.py
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
