#!/usr/bin/env python3
"""grill_server — ephemeral localhost bridge between the grilling deck and the agent.

A dumb bridge, deliberately: the deck POSTs answers, the agent long-polls them,
the agent POSTs injections, the deck streams them over SSE. It never parses an
answer as an instruction — answers are whitelisted, coerced to strings, and
handed to the agent as data. The security posture is loopback bind +
per-session token; the agent is the sole buffer writer.

Run standalone (spawned by `bin/grill start`):
    grill_server.py --topic T --token TOK --port 0 --deck DECK --buffer BUF \
        --session-file /tmp/grill-T-session.json [--idle-timeout 1800]
"""

import argparse
import json
import queue
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# The only keys an answer may carry. Everything else is dropped so a submit can
# never smuggle an injection op (`op`/`html`) or a dunder past the boundary.
ANSWER_FIELDS = ("topic", "decision", "choice", "notes", "ts")

POLL_WAIT_DEFAULT_S = 25.0
SSE_HEARTBEAT_S = 15.0
IDLE_CHECK_INTERVAL_S = 30.0


def sanitize_answer(raw):
    """Whitelist + coerce a posted answer to data. `choice` alone may stay null."""
    out = {}
    for key in ANSWER_FIELDS:
        if key not in raw:
            continue
        value = raw[key]
        out[key] = None if (key == "choice" and value is None) else str(value)
    return out


def _ts_sort_key(record):
    """Sort a poll batch by ts so a later submit applies last (last-write-wins)."""
    ts = record.get("ts", "")
    try:
        return (0, float(ts))
    except (TypeError, ValueError):
        return (1, str(ts))


class GrillServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        *,
        topic,
        token,
        deck_path,
        buffer_path,
        port=0,
        idle_timeout_s=1800,
        session_file=None,
    ):
        super().__init__(("127.0.0.1", port), GrillHandler)
        self.topic = topic
        self.token = token
        self.deck_path = deck_path
        self.buffer_path = buffer_path
        self.idle_timeout_s = idle_timeout_s
        self.session_file = session_file

        self.answers = queue.Queue()
        self._subscribers = []
        self._subscribers_lock = threading.Lock()
        self.last_activity = time.monotonic()
        self._stopped = False

    # --- activity + idle lifecycle ---

    def touch_activity(self):
        self.last_activity = time.monotonic()

    def idle_expired(self, now):
        return now - self.last_activity > self.idle_timeout_s

    def remove_session_file(self):
        if self.session_file:
            Path(self.session_file).unlink(missing_ok=True)

    def start_idle_watch(self):
        threading.Thread(target=self._idle_watch, daemon=True).start()

    def _idle_watch(self):
        while not self._stopped:
            time.sleep(min(IDLE_CHECK_INTERVAL_S, self.idle_timeout_s))
            if self.idle_expired(time.monotonic()):
                self.remove_session_file()
                threading.Thread(target=self.shutdown, daemon=True).start()
                return

    def server_close(self):
        self._stopped = True
        super().server_close()

    # --- SSE fan-out ---

    def register_subscriber(self, sub):
        with self._subscribers_lock:
            self._subscribers.append(sub)

    def unregister_subscriber(self, sub):
        with self._subscribers_lock:
            self._subscribers.remove(sub)

    def broadcast(self, frame):
        with self._subscribers_lock:
            subs = list(self._subscribers)
        for sub in subs:
            sub.put(frame)
        return len(subs)


class GrillHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):
        pass

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._serve_deck()
        elif parsed.path == "/health":
            self._send_json(200, {"ok": True, "topic": self.server.topic})
        elif parsed.path == "/poll":
            if self._authed(parsed):
                self._handle_poll(parsed)
        elif parsed.path == "/events":
            if self._authed(parsed):
                self._handle_events()
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/answers":
            if self._authed(parsed):
                self._handle_answers()
        elif parsed.path == "/inject":
            if self._authed(parsed):
                self._handle_inject()
        else:
            self.send_error(404)

    # --- auth ---

    def _authed(self, parsed):
        supplied = parse_qs(parsed.query).get("token", [None])[0] or self.headers.get("X-Grill-Token")
        if supplied != self.server.token:
            self._send_json(401, {"error": "unauthorized"})
            return False
        self.server.touch_activity()
        return True

    # --- handlers ---

    def _handle_answers(self):
        self.server.answers.put(sanitize_answer(self._read_json()))
        self._send_json(200, {"ok": True})

    def _handle_poll(self, parsed):
        wait = float(parse_qs(parsed.query).get("wait", [POLL_WAIT_DEFAULT_S])[0])
        items = []
        try:
            items.append(self.server.answers.get(timeout=wait))
        except queue.Empty:
            pass
        while True:
            try:
                items.append(self.server.answers.get_nowait())
            except queue.Empty:
                break
        items.sort(key=_ts_sort_key)
        self._send_json(200, items)

    def _handle_inject(self):
        payload = self._read_json()
        frame = f"data: {json.dumps(payload)}\n\n"
        delivered = self.server.broadcast(frame)
        self._send_json(200, {"delivered": delivered})

    def _handle_events(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        sub = queue.Queue()
        self.server.register_subscriber(sub)
        try:
            while True:
                try:
                    frame = sub.get(timeout=SSE_HEARTBEAT_S)
                except queue.Empty:
                    frame = ": keepalive\n\n"  # Comment frame; must not reset the idle clock.
                self.wfile.write(frame.encode())
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            self.server.unregister_subscriber(sub)

    def _serve_deck(self):
        html = Path(self.server.deck_path).read_text()
        meta = (
            f'<meta name="grill-token" content="{self.server.token}">\n'
            f'<meta name="grill-port" content="{self.server.server_address[1]}">\n'
            f'<meta name="grill-topic" content="{self.server.topic}">\n'
        )
        html = html.replace("<head>", "<head>\n" + meta, 1)
        self._send_bytes(200, "text/html; charset=utf-8", html.encode())

    # --- response helpers ---

    def _read_json(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        return json.loads(body) if body else {}

    def _send_json(self, status, obj):
        self._send_bytes(status, "application/json", json.dumps(obj).encode())

    def _send_bytes(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--topic", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--deck", required=True)
    parser.add_argument("--buffer", required=True)
    parser.add_argument("--session-file")
    parser.add_argument("--idle-timeout", type=int, default=1800)
    args = parser.parse_args()

    server = GrillServer(
        topic=args.topic,
        token=args.token,
        deck_path=args.deck,
        buffer_path=args.buffer,
        port=args.port,
        idle_timeout_s=args.idle_timeout,
        session_file=args.session_file,
    )
    server.start_idle_watch()
    server.serve_forever()


if __name__ == "__main__":
    main()
