#!/usr/bin/env python3
"""
devserver.py -- local preview server used while building the present.

Serves this folder over HTTP and, unlike a plain `python -m http.server`,
accepts the rendered canvas back:

    POST /__shot?name=bloom      body = raw PNG bytes
    -> writes build/shots/bloom.png

The page can only hand a frame back through the same origin it was served
from, so the upload endpoint lives here rather than on a second port.

This is build tooling only -- it is not part of Happy_Birthday_Erlin.html,
which is a single self-contained file and needs no server at all.

    python devserver.py [port]
"""

import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(ROOT, "build", "shots")


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/__shot":
            self.send_error(404, "only /__shot accepts POST")
            return

        name = (parse_qs(parsed.query).get("name") or ["shot"])[0]
        # Keep the filename to a safe basename; this server is reachable
        # from the browser, so don't let a name walk out of build/shots.
        name = os.path.basename(name).replace("..", "_") or "shot"
        if not name.lower().endswith(".png"):
            name += ".png"

        length = int(self.headers.get("Content-Length") or 0)
        data = self.rfile.read(length) if length else b""

        os.makedirs(SHOTS, exist_ok=True)
        path = os.path.join(SHOTS, name)
        with open(path, "wb") as fh:
            fh.write(data)

        sys.stderr.write(f"  saved {os.path.relpath(path, ROOT)}  ({len(data):,} bytes)\n")
        sys.stderr.flush()

        body = path.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # No caching, so a rebuilt page is picked up on reload.
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # the default logger is too noisy for a build loop


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8777
    os.makedirs(SHOTS, exist_ok=True)
    print(f"devserver on http://localhost:{port}  (root: {ROOT})")
    print(f"  POST /__shot?name=<n>  ->  build/shots/<n>.png")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
