import asyncio, os

ROUTES = {
    "/trojan": ("127.0.0.1", 10003),
    "/vmess": ("127.0.0.1", 10002),
    "/vless-hu": ("127.0.0.1", 10001),
    "/vless": ("127.0.0.1", 10000),
}
DEFAULT_TARGET = ("127.0.0.1", 10000)

async def pipe(reader, writer):
    try:
        while True:
            data = await reader.read(8192)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass

def pick_target(header_bytes):
    text = header_bytes.decode("latin1", errors="ignore")
    for path, target in ROUTES.items():
        if path in text:
            return target
    return DEFAULT_TARGET

def is_plain_root_probe(chunk):
    text = chunk.decode("latin1", errors="ignore").lower()
    has_tunnel_path = any(p in text for p in ROUTES.keys())
    has_upgrade = "upgrade:" in text or "connection: upgrade" in text
    lines = text.splitlines()
    first_line = lines[0].strip() if lines else ""
    is_root_get = first_line.startswith(("get / http/", "head / http/"))
    return is_root_get and not has_tunnel_path and not has_upgrade

async def handle_client(client_reader, client_writer):
    try:
        first_chunk = await asyncio.wait_for(client_reader.read(4096), timeout=10)
        if not first_chunk:
            client_writer.close()
            return

        second_chunk = b""
        if b"\r\n\r\n" in first_chunk and first_chunk.endswith(b"\r\n\r\n"):
            try:
                second_chunk = await asyncio.wait_for(client_reader.read(4096), timeout=1.5)
            except asyncio.TimeoutError:
                second_chunk = b""

        if is_plain_root_probe(first_chunk) and not second_chunk:
            body = b"OK"
            resp = (
                b"HTTP/1.1 200 OK\r\n"
                b"Content-Type: text/plain; charset=utf-8\r\n"
                b"Content-Length: 2\r\n"
                b"Connection: close\r\n\r\n" + body
            )
            client_writer.write(resp)
            await client_writer.drain()
            client_writer.close()
            return

        active_chunk = second_chunk if second_chunk else first_chunk
        host, port = pick_target(active_chunk)
        remote_reader, remote_writer = await asyncio.open_connection(host, port)

        lower_chunk = active_chunk.lower()
        if b"upgrade:" in lower_chunk:
            lines = active_chunk.split(b"\r\n")
            if lines and b"HTTP/" in lines[0]:
                parts = lines[0].split(b" ")
                if len(parts) >= 3 and parts[0] != b"GET":
                    parts[0] = b"GET"
                    lines[0] = b" ".join(parts)
                active_chunk = b"\r\n".join(lines)

        remote_writer.write(active_chunk)
        await remote_writer.drain()

        await asyncio.gather(
            pipe(client_reader, remote_writer),
            pipe(remote_reader, client_writer),
        )
    except Exception:
        try:
            client_writer.close()
        except Exception:
            pass

async def main():
    ports = {80, 5000}
    env_port = os.environ.get("PORT")
    if env_port and env_port.isdigit():
        ports.add(int(env_port))

    servers = []
    for p in sorted(ports):
        try:
            srv = await asyncio.start_server(handle_client, "0.0.0.0", p)
            servers.append(srv)
            print(f"Raw proxy listening on 0.0.0.0:{p}", flush=True)
        except Exception as e:
            print(f"Skip port {p}: {e}", flush=True)

    if servers:
        await asyncio.gather(*(s.serve_forever() for s in servers))

if __name__ == "__main__":
    asyncio.run(main())
