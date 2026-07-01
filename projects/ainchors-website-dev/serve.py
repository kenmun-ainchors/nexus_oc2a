#!/usr/bin/env python3
"""Local dev server for ainchors.com replica with route mapping.

Maps clean routes like /home, /about-us-814253 to pages/<route>/index.html.
Serves static assets from /assets.
Binds to 0.0.0.0 so Tailscale/remote clients can reach it.
"""
import os, sys, mimetypes, traceback
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

ROOT = Path(__file__).parent.resolve()
PAGES = ROOT / "pages"

class AinchorsHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def send_text(self, status, body):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        try:
            path = self.path.split("?")[0].lstrip("/")
            if path == "" or path == "/":
                target = PAGES / "home" / "index.html"
            else:
                candidate = PAGES / path / "index.html"
                if candidate.exists():
                    target = candidate
                else:
                    candidate2 = PAGES / f"{path}.html"
                    if candidate2.exists():
                        target = candidate2
                    else:
                        asset = ROOT / path
                        if asset.exists() and asset.is_file():
                            target = asset
                        else:
                            self.send_text(404, f"File not found: {self.path}")
                            return

            if not target.exists():
                self.send_text(404, f"File not found: {self.path}")
                return

            ctype, _ = mimetypes.guess_type(str(target))
            if ctype is None:
                ctype = "application/octet-stream"

            data = target.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            traceback.print_exc()
            try:
                self.send_text(500, f"Internal server error: {e}")
            except Exception:
                pass

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    os.chdir(str(ROOT))
    server = HTTPServer(("0.0.0.0", port), AinchorsHandler)
    print(f"=== AINCHORS Local Dev Replica ===")
    print(f"Serving from: {ROOT}")
    print(f"Local:   http://localhost:{port}")
    print(f"Tailscale: http://100.91.60.36:{port}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        sys.exit(0)
