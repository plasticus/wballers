#!/usr/bin/env python3
"""Local server for wballers player-edit.html."""

import json
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

ROOT = Path(__file__).parent
os.chdir(ROOT)
PLAYERS_FILE = ROOT / "players.json"


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        if self.path != "/save":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
            with open(PLAYERS_FILE, "w") as f:
                json.dump(data, f, indent=2)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "path": str(PLAYERS_FILE)}).encode())
            print(f"Saved {PLAYERS_FILE}")
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode())
            print(f"Save failed: {e}")

    def log_message(self, format, *args):
        print(format % args)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8001))
    print(f"Serving wballers from {ROOT}")
    print(f"Open http://localhost:{port}/")
    print(f"Saving will write to: {PLAYERS_FILE}")
    print("Press Ctrl+C to stop")
    server = HTTPServer(("localhost", port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
