#!/bin/bash
set -euo pipefail

# One-file local Access Gate client.
# Usage:
#   BACKEND_URL="https://your-backend.example.com" ./access-gate.sh
#   ./access-gate.sh https://your-backend.example.com
#
# Every launch downloads the current HTML from the backend, then serves it
# locally. API/auth requests are proxied to the backend by the embedded
# localhost Python server, so the page stays same-origin and requires no CORS.

BACKEND_URL="${BACKEND_URL:-${1:-}}"
HOST="127.0.0.1"
PORT="${PORT:-8765}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/access-gate"
INDEX_FILE="$CACHE_DIR/index.html"

if [[ -z "$BACKEND_URL" ]]; then
  echo "Usage: BACKEND_URL=https://your-backend.example.com $0"
  echo "   or: $0 https://your-backend.example.com"
  exit 1
fi
BACKEND_URL="${BACKEND_URL%/}"
mkdir -p "$CACHE_DIR"
TMP="$INDEX_FILE.tmp"

echo "Syncing Access Gate from $BACKEND_URL ..."
if curl --fail --silent --show-error --location --connect-timeout 8 --max-time 30 --retry 2 -o "$TMP" "$BACKEND_URL/"; then
  if grep -qi '<html' "$TMP"; then
    mv "$TMP" "$INDEX_FILE"
    echo "Updated local cache."
  else
    rm -f "$TMP"
    echo "Backend did not return HTML."
    [[ -f "$INDEX_FILE" ]] || exit 1
  fi
else
  rm -f "$TMP"
  if [[ -f "$INDEX_FILE" ]]; then
    echo "Backend unavailable; using cached HTML."
  else
    echo "Initial sync failed and no cache exists."
    exit 1
  fi
fi

python3 - "$BACKEND_URL" "$HOST" "$PORT" "$INDEX_FILE" <<'PY'
from __future__ import annotations
import http.client
import http.server
import os
import socket
import sys
import urllib.parse
import webbrowser

backend_url, host, port_text, index_file = sys.argv[1:]
port = int(port_text)
parsed = urllib.parse.urlsplit(backend_url)
if parsed.scheme not in {"http", "https"} or not parsed.hostname:
    raise SystemExit("BACKEND_URL must be an http(s) URL")

scheme = parsed.scheme
backend_host = parsed.hostname
backend_port = parsed.port or (443 if scheme == "https" else 80)

PROXY_PREFIXES = ("/api/", "/auth/", "/retrieve/")

class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, content_type, data, extra=None):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        if extra:
            for k,v in extra.items(): self.send_header(k,v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _proxy(self):
        p = urllib.parse.urlsplit(self.path)
        if not p.path.startswith(PROXY_PREFIXES):
            self._send(404, "text/plain; charset=utf-8", b"Not found")
            return
        body = b""
        if self.command in {"POST", "PUT", "PATCH"}:
            body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        path = p.path + (("?" + p.query) if p.query else "")
        conn = http.client.HTTPSConnection(backend_host, backend_port, timeout=20) if scheme == "https" else http.client.HTTPConnection(backend_host, backend_port, timeout=20)
        headers = {}
        for k,v in self.headers.items():
            if k.lower() not in {"host","content-length","connection","origin","referer"}:
                headers[k] = v
        try:
            conn.request(self.command, path, body=body, headers=headers)
            r = conn.getresponse()
            data = r.read()
            self._send(r.status, r.getheader("Content-Type") or "application/octet-stream", data)
        except Exception as e:
            self._send(502, "application/json", ('{"error":"backend unavailable","detail":%r}' % str(e)).encode())
        finally:
            conn.close()

    def do_GET(self):
        p = urllib.parse.urlsplit(self.path)
        if p.path.startswith(PROXY_PREFIXES):
            self._proxy(); return
        if p.path in {"/", "/index.html"}:
            try: data = open(index_file,"rb").read()
            except OSError: self._send(500,"text/plain; charset=utf-8",b"Cached page unavailable"); return
            self._send(200, "text/html; charset=utf-8", data); return
        if p.path == "/health":
            self._send(200,"application/json",b'{"status":"local-ok"}'); return
        self._send(404,"text/plain; charset=utf-8",b"Not found")

    def do_POST(self): self._proxy()
    def log_message(self, fmt, *args): pass

server = http.server.ThreadingHTTPServer((host, port), Handler)
url = f"http://{host}:{port}/"
print(f"Access Gate: {url}")
print(f"Backend:     {backend_url}")
try:
    webbrowser.open(url, new=1)
except Exception:
    pass
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopping Access Gate.")
finally:
    server.server_close()
PY
