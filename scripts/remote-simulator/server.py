"""Temporary, authenticated app-only bridge to a loopback Appium server."""
import base64
import hmac
import json
import math
import os
from pathlib import Path
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).parent
TOKEN = os.environ["SIMULATOR_ACCESS_TOKEN"]
if len(TOKEN) < 32:
    raise RuntimeError("A random access token of at least 32 characters is required")
LOCK = threading.Lock()
STOP = threading.Event()
SESSION = None
EXPIRES = time.time() + 1800


def driver(method, route, body=None):
    request = urllib.request.Request(
        "http://127.0.0.1:4723" + route,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(request, timeout=300) as response:
        value = json.load(response)["value"]
    if isinstance(value, dict) and "error" in value:
        raise RuntimeError(value["error"])
    return value


def execute(script, args):
    return driver("POST", f"/session/{SESSION}/execute/sync", {"script": script, "args": [args]})


def initialize():
    global SESSION, EXPIRES
    result = driver("POST", "/session", {"capabilities": {"alwaysMatch": {
        "platformName": "iOS", "appium:automationName": "XCUITest",
        "appium:udid": os.environ["SIMULATOR_UDID"],
        "appium:app": os.path.abspath("build/Build/Products/Debug-iphonesimulator/RallyTrip.app"),
        "appium:bundleId": "de.rallytrip.app", "appium:noReset": True,
        "appium:newCommandTimeout": 1900, "appium:wdaLaunchTimeout": 240000,
        "appium:waitForIdleTimeout": 0.5, "appium:autoAcceptAlerts": True,
        "appium:showXcodeLog": True
    }}})
    SESSION = result["sessionId"]
    # A real interaction verifies that the bridge can control, not only view, the app.
    rect = driver("GET", f"/session/{SESSION}/window/rect")
    execute("mobile: tap", {"x": rect["width"] * .5, "y": rect["height"] * .44})
    source = driver("GET", f"/session/{SESSION}/source")
    if "Fahrt starten" not in source:
        raise RuntimeError("Smoke test failed: Tripmaster did not open")
    execute("mobile: terminateApp", {"bundleId": "de.rallytrip.app"})
    execute("mobile: launchApp", {"bundleId": "de.rallytrip.app"})
    EXPIRES = time.time() + 1800
    Path("remote-ready").write_text("ready")
    print("Interactive tap smoke test passed; session ready for 30 minutes.", flush=True)


def coordinate(data, key):
    value = data[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= 1:
        raise ValueError("Invalid coordinate")
    return value


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log credentials, request contents, or user input.

    def reply(self, status, data, content_type="application/json"):
        if not isinstance(data, bytes):
            data = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'")
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        if not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + TOKEN):
            self.reply(401, {"error": "Zugangsschlüssel fehlt oder ist ungültig."})
            return False
        if time.time() >= EXPIRES or STOP.is_set():
            self.reply(410, {"error": "Die Testsitzung ist beendet."})
            return False
        return True

    def do_GET(self):
        assets = {"/": ("index.html", "text/html; charset=utf-8"), "/app.js": ("app.js", "text/javascript"), "/style.css": ("style.css", "text/css")}
        if self.path in assets:
            name, kind = assets[self.path]
            return self.reply(200, (ROOT / name).read_bytes(), kind)
        if not self.authorized():
            return
        if self.path == "/status":
            return self.reply(200, {"remaining": max(0, int(EXPIRES-time.time()))})
        if self.path != "/frame":
            return self.reply(404, {"error": "Not found"})
        try:
            with LOCK:
                png = driver("GET", f"/session/{SESSION}/screenshot")
            self.reply(200, base64.b64decode(png), "image/png")
        except Exception:
            self.reply(503, {"error": "Simulator antwortet gerade nicht."})

    def do_POST(self):
        if not self.authorized():
            return
        if self.path != "/command":
            return self.reply(404, {"error": "Not found"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 4096:
                raise ValueError("Invalid body")
            command = json.loads(self.rfile.read(length))
            kind = command["kind"]
            with LOCK:
                if kind == "tap":
                    rect = driver("GET", f"/session/{SESSION}/window/rect")
                    execute("mobile: tap", {"x": coordinate(command, "x")*rect["width"], "y": coordinate(command, "y")*rect["height"]})
                elif kind == "swipe" and command.get("direction") in ("up", "down", "left", "right"):
                    execute("mobile: swipe", {"direction": command["direction"]})
                elif kind == "text" and isinstance(command.get("text"), str) and len(command["text"]) <= 200:
                    driver("POST", f"/session/{SESSION}/keys", {"text": command["text"], "value": list(command["text"])})
                elif kind == "restart":
                    execute("mobile: terminateApp", {"bundleId": "de.rallytrip.app"})
                    execute("mobile: launchApp", {"bundleId": "de.rallytrip.app"})
                elif kind == "stop":
                    STOP.set()
                else:
                    raise ValueError("Unknown command")
            self.reply(200, {"ok": True})
        except (ValueError, KeyError, TypeError):
            self.reply(400, {"error": "Ungültige Eingabe."})
        except Exception:
            self.reply(503, {"error": "Eingabe konnte nicht ausgeführt werden."})


if __name__ == "__main__":
    initialize()
    server = ThreadingHTTPServer(("127.0.0.1", 7999), Handler)
    server.timeout = 1
    while time.time() < EXPIRES and not STOP.is_set():
        server.handle_request()
    server.server_close()
    driver("DELETE", f"/session/{SESSION}")
