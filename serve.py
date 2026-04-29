#!/usr/bin/env python3
"""Dev server for Taigi Mass Lookup.

Serves static files from this directory and proxies POST /api/tau to the
ithuan endpoint at https://hokbu.ithuan.tw/tau (which only allows requests
from suisiann.ithuan.tw, so a same-origin proxy is needed for browsers).

Usage:
    python3 serve.py            # http://localhost:8000
    python3 serve.py 8080       # custom port
"""
import http.server
import os
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

ITHUAN_URL = "https://hokbu.ithuan.tw/tau"
HERE = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=HERE, **kwargs)

    def do_POST(self):
        if urlparse(self.path).path != "/api/tau":
            self.send_error(404, "Not found")
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""

        req = urllib.request.Request(
            ITHUAN_URL,
            data=body,
            headers={
                "content-type": "application/x-www-form-urlencoded",
                "origin": "https://suisiann.ithuan.tw",
                "referer": "https://suisiann.ithuan.tw/",
                "user-agent": "taigi-mass-lookup-dev-proxy/1.0",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                payload = resp.read()
                self.send_response(resp.status)
                self.send_header(
                    "content-type",
                    resp.headers.get("content-type", "application/json"),
                )
                self.send_header("content-length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as e:
            self.send_error(e.code, e.reason)
        except Exception as e:
            self.send_error(502, f"Proxy error: {e}")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    server = http.server.ThreadingHTTPServer(("localhost", port), Handler)
    print(f"Serving Taigi Mass Lookup at http://localhost:{port}")
    print(f"  proxying POST /api/tau → {ITHUAN_URL}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
