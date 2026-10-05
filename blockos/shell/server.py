#!/usr/bin/env python3
"""BlockOS shell server.

Serves the BlockOS desktop (this directory) on http://127.0.0.1:8737 and exposes a
tiny JSON API the desktop uses to open real Linux apps and to power off or restart.

Only allowlisted commands can be run. POST requests must carry the header
"X-BlockOS: 1": a custom header forces a CORS preflight, which this server never
approves, so other web pages can't call the API. The Host header is checked too,
which blocks DNS-rebinding tricks.

On a Mac (the BlockOS app) the Apps page opens the matching Mac apps instead, and
the power buttons are turned off.

Usage: server.py [--port N] [--dry-run] [--idle-exit SECONDS]
  --dry-run         log the commands instead of running them (handy on a dev machine)
  --idle-exit N     quit when no BlockOS page has checked in for N seconds
"""

import argparse
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

SHELL_DIR = os.path.dirname(os.path.abspath(__file__))
IS_MAC = sys.platform == "darwin"

# Each app is a list of candidate commands; the first one that is installed is used.
APPS = {
    "terminal": [["x-terminal-emulator"], ["xfce4-terminal"], ["xterm"]],
    "files": [["pcmanfm"], ["thunar"], ["nautilus"]],
    "browser": [["chromium", "--new-window"], ["firefox-esr"], ["firefox"], ["x-www-browser"]],
    "editor": [["mousepad"], ["gedit"], ["gnome-text-editor"]],
    "taskmanager": [["xfce4-taskmanager"], ["lxtask"]],
    "calculator": [["galculator"], ["gnome-calculator"]],
}

MAC_APPS = {
    "terminal": ["open", "-a", "Terminal"],
    "files": ["open", os.path.expanduser("~")],
    "browser": ["open", "-a", "Safari"],
    "editor": ["open", "-a", "TextEdit"],
    "taskmanager": ["open", "-a", "Activity Monitor"],
    "calculator": ["open", "-a", "Calculator"],
}

POWER = {
    "poweroff": ["systemctl", "poweroff"],
    "reboot": ["systemctl", "reboot"],
}


def resolve(app):
    if IS_MAC:
        return MAC_APPS.get(app)
    for cmd in APPS.get(app, []):
        if shutil.which(cmd[0]):
            return cmd
    return None


def read_os_name():
    if IS_MAC:
        return "macOS " + platform.mac_ver()[0]
    try:
        with open("/etc/os-release", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return platform.system()


def read_meminfo():
    info = {}
    try:
        with open("/proc/meminfo", encoding="utf-8") as f:
            for line in f:
                key, value = line.split(":", 1)
                info[key] = int(value.split()[0]) * 1024
    except (OSError, ValueError):
        return None
    return {"total": info.get("MemTotal"), "available": info.get("MemAvailable")}


def read_uptime():
    try:
        with open("/proc/uptime", encoding="utf-8") as f:
            return float(f.read().split()[0])
    except (OSError, ValueError):
        return None


def system_info():
    debian = None
    try:
        with open("/etc/debian_version", encoding="utf-8") as f:
            debian = f.read().strip()
    except OSError:
        pass
    return {
        "hostname": socket.gethostname(),
        "os": read_os_name(),
        "debian": debian,
        "kernel": platform.release(),
        "arch": platform.machine(),
        "cpus": os.cpu_count(),
        "memory": read_meminfo(),
        "uptime": read_uptime(),
        "user": os.environ.get("USER", ""),
        "apps": {name: resolve(name) is not None for name in APPS},
    }


def spawn(cmd, dry_run):
    if dry_run:
        print("[dry-run] would run:", " ".join(cmd), file=sys.stderr)
        return
    # Detach so the app outlives this request and doesn't become a zombie of the server.
    subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        cwd=os.path.expanduser("~"),
    )


class Handler(SimpleHTTPRequestHandler):
    server_version = "BlockOS"
    dry_run = False
    port = 8737
    last_seen = time.monotonic()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SHELL_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        if self.dry_run:
            super().log_message(fmt, *args)

    def host_ok(self):
        host = self.headers.get("Host", "")
        return host in (f"127.0.0.1:{self.port}", f"localhost:{self.port}")

    def send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self.host_ok():
            return self.send_json(403, {"error": "bad host"})
        if self.path == "/api/info":
            return self.send_json(200, system_info())
        if self.path == "/api/ping":
            Handler.last_seen = time.monotonic()
            return self.send_json(200, {"ok": True})
        if self.path.startswith("/api/"):
            return self.send_json(404, {"error": "not found"})
        return super().do_GET()

    def do_POST(self):
        if not self.host_ok() or self.headers.get("X-BlockOS") != "1":
            return self.send_json(403, {"error": "forbidden"})
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            data = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            return self.send_json(400, {"error": "bad json"})

        if self.path == "/api/launch":
            cmd = resolve(str(data.get("app", "")))
            if not cmd:
                return self.send_json(404, {"error": "app not installed"})
            spawn(cmd, self.dry_run)
            return self.send_json(200, {"ok": True})

        if self.path == "/api/power":
            if IS_MAC:
                return self.send_json(400, {"error": "Restart and Shut down only work in the BlockOS virtual machine."})
            cmd = POWER.get(str(data.get("action", "")))
            if not cmd:
                return self.send_json(400, {"error": "unknown action"})
            spawn(cmd, self.dry_run)
            return self.send_json(200, {"ok": True})

        return self.send_json(404, {"error": "not found"})


def main():
    parser = argparse.ArgumentParser(description="BlockOS shell server")
    parser.add_argument("--port", type=int, default=int(os.environ.get("BLOCKOS_PORT", "8737")))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--idle-exit", type=float, default=0)
    args = parser.parse_args()

    Handler.dry_run = args.dry_run
    Handler.port = args.port
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    if args.idle_exit > 0:
        def watch():
            while time.monotonic() - Handler.last_seen < args.idle_exit:
                time.sleep(2)
            server.shutdown()
        threading.Thread(target=watch, daemon=True).start()
    print(f"BlockOS shell on http://127.0.0.1:{args.port}/", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
