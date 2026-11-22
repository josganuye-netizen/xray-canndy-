import asyncio, os, re

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

async def handle_client(client_reader, client_writer):
    try:
        first_chunk = await asyncio.wait_for(client_reader.read(4096), timeout=10)
        if not first_chunk:
            client_writer.close()
            return

        # Jika payload 2 segmen (misal GET / ... [crlf][crlf] PATCH /trojan ...), baca segmen kedua jika belum terbaca
        if b"\r\n\r\n" in first_chunk and first_chunk.endswith(b"\r\n\r\n"):
            try:
                second_chunk = await asyncio.wait_for(client_reader.read(4096), timeout=1.5)
                if second_chunk:
                    first_chunk = second_chunk
            except asyncio.TimeoutError:
                pass

        host, port = pick_target(first_chunk)
        remote_reader, remote_writer = await asyncio.open_connection(host, port)

        # Normalisasi baris pertama HTTP agar Xray WS selalu menerima metode GET standar
        lines = first_chunk.split(b"\r\n")
        if lines and b"HTTP/" in lines[0]:
            parts = lines[0].split(b" ")
            if len(parts) >= 3 and parts[0] != b"GET":
                parts[0] = b"GET"
                lines[0] = b" ".join(parts)
            first_chunk = b"\r\n".join(lines)

        remote_writer.write(first_chunk)
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
    for p in ports:
        try:
            srv = await asyncio.start_server(handle_client, "0.0.0.0", p)
            servers.append(srv)
            print(f"Raw proxy listening on 0.0.0.0:{p}")
        except Exception as e:
            print(f"Skip port {p}: {e}")

    await asyncio.gather(*(s.serve_forever() for s in servers))

if __name__ == "__main__":
    asyncio.run(main())
