"""Tests for grill_server — the security- and correctness-load-bearing bridge.

Stdlib unittest only (matches the dotfiles bash+python3 convention; no runtime
deps). Covers token + loopback bind, the answers-as-data whitelist, the gap-safe
poll queue, inject -> SSE frame fan-out, idle teardown + session-file lifecycle,
and last-write-wins by ts.
"""

import http.client
import json
import tempfile
import threading
import time
import unittest
from pathlib import Path

from grill_server import GrillServer, sanitize_answer

TOKEN = "test-token-abc123"


def _serve(server):
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return thread


class SanitizeAnswerTest(unittest.TestCase):
    """Answers are treated as DATA: whitelist keys, coerce to str."""

    def test_keeps_only_whitelisted_keys(self):
        raw = {
            "topic": "t",
            "decision": "D3",
            "choice": "B",
            "reasoning": "because",
            "notes": "a note",
            "ts": 1700000000,
        }
        self.assertEqual(
            sanitize_answer(raw),
            {
                "topic": "t",
                "decision": "D3",
                "choice": "B",
                "reasoning": "because",
                "notes": "a note",
                "ts": "1700000000",
            },
        )

    def test_drops_injection_shaped_and_unknown_keys(self):
        raw = {
            "decision": "D3",
            "choice": "B",
            "op": "append",
            "html": "<script>alert(1)</script>",
            "__import__": "os",
            "id": "d99",
            "extra": {"nested": 1},
        }
        self.assertEqual(sanitize_answer(raw), {"decision": "D3", "choice": "B"})

    def test_coerces_non_string_values_to_str(self):
        out = sanitize_answer({"decision": "D3", "ts": 42, "reasoning": ["a"]})
        self.assertEqual(out["ts"], "42")
        self.assertEqual(out["reasoning"], "['a']")

    def test_choice_may_be_null(self):
        out = sanitize_answer({"decision": "info-1", "choice": None, "notes": "n"})
        self.assertIsNone(out["choice"])
        self.assertEqual(out["notes"], "n")


class ServerConfigTest(unittest.TestCase):
    """Loopback bind, idle predicate, and session-file lifecycle."""

    def test_binds_to_loopback_only(self):
        server = GrillServer(topic="t", token=TOKEN, deck_path="/dev/null", buffer_path="/dev/null")
        self.addCleanup(server.server_close)
        self.assertEqual(server.server_address[0], "127.0.0.1")

    def test_idle_expired_predicate(self):
        server = GrillServer(
            topic="t", token=TOKEN, deck_path="/dev/null", buffer_path="/dev/null", idle_timeout_s=100
        )
        self.addCleanup(server.server_close)
        server.last_activity = 1000.0
        self.assertFalse(server.idle_expired(now=1099.0))
        self.assertTrue(server.idle_expired(now=1101.0))

    def test_touch_activity_resets_idle_clock(self):
        server = GrillServer(
            topic="t", token=TOKEN, deck_path="/dev/null", buffer_path="/dev/null", idle_timeout_s=100
        )
        self.addCleanup(server.server_close)
        server.last_activity = 0.0
        server.touch_activity()
        self.assertGreater(server.last_activity, 0.0)

    def test_teardown_unlinks_session_file(self):
        session = Path(tempfile.mktemp(prefix="grill-test-session-"))
        session.write_text("{}")
        server = GrillServer(
            topic="t",
            token=TOKEN,
            deck_path="/dev/null",
            buffer_path="/dev/null",
            session_file=str(session),
        )
        self.addCleanup(server.server_close)
        server.remove_session_file()
        self.assertFalse(session.exists())


class ServerHTTPTest(unittest.TestCase):
    """Token auth, answers -> poll, inject -> events, and ts ordering."""

    def setUp(self):
        self.deck = Path(tempfile.mktemp(prefix="grill-test-deck-", suffix=".html"))
        self.deck.write_text("<!doctype html>\n<html><head>\n</head><body>deck</body></html>")
        self.server = GrillServer(
            topic="mytopic", token=TOKEN, deck_path=str(self.deck), buffer_path="/dev/null"
        )
        self.port = self.server.server_address[1]
        _serve(self.server)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.addCleanup(self.deck.unlink)

    def _request(self, method, path, body=None, token=TOKEN, use_header=False):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        headers = {}
        target = path
        if token is not None:
            if use_header:
                headers["X-Grill-Token"] = token
            else:
                sep = "&" if "?" in path else "?"
                target = f"{path}{sep}token={token}"
        payload = None
        if body is not None:
            payload = json.dumps(body)
            headers["Content-Type"] = "application/json"
        conn.request(method, target, payload, headers)
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        return resp.status, data

    def _post_answer(self, decision, choice, ts):
        status, _ = self._request(
            "POST",
            "/answers",
            {"topic": "mytopic", "decision": decision, "choice": choice, "reasoning": "", "notes": "", "ts": ts},
        )
        self.assertEqual(status, 200)

    def test_health_is_unauthenticated_and_names_topic(self):
        status, data = self._request("GET", "/health", token=None)
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(data)["topic"], "mytopic")

    def test_root_serves_deck_with_injected_token_meta(self):
        status, data = self._request("GET", "/", token=None)
        self.assertEqual(status, 200)
        html = data.decode()
        self.assertIn(f'name="grill-token" content="{TOKEN}"', html)
        self.assertIn(f'name="grill-port" content="{self.port}"', html)
        self.assertIn('name="grill-topic" content="mytopic"', html)

    def test_poll_rejects_missing_token(self):
        status, _ = self._request("GET", "/poll?wait=0", token=None)
        self.assertEqual(status, 401)

    def test_poll_rejects_wrong_token(self):
        status, _ = self._request("GET", "/poll?wait=0", token="wrong")
        self.assertEqual(status, 401)

    def test_answers_rejects_missing_token(self):
        status, _ = self._request("POST", "/answers", {"decision": "D1"}, token=None)
        self.assertEqual(status, 401)

    def test_token_accepted_via_header(self):
        status, _ = self._request("GET", "/poll?wait=0", use_header=True)
        self.assertEqual(status, 200)

    def test_answer_roundtrips_sanitized_through_poll(self):
        status, _ = self._request(
            "POST",
            "/answers",
            {"topic": "mytopic", "decision": "D3", "choice": "B", "reasoning": "r", "notes": "n",
             "ts": 5, "op": "append", "html": "<script>"},
        )
        self.assertEqual(status, 200)
        status, data = self._request("GET", "/poll?wait=1")
        self.assertEqual(status, 200)
        items = json.loads(data)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0], {"topic": "mytopic", "decision": "D3", "choice": "B",
                                    "reasoning": "r", "notes": "n", "ts": "5"})

    def test_poll_buffers_submits_arriving_in_the_gap(self):
        """Submits landing with no poll waiting are not lost."""
        self._post_answer("D1", "A", 1)
        self._post_answer("D2", "B", 2)
        status, data = self._request("GET", "/poll?wait=1")
        self.assertEqual(status, 200)
        items = json.loads(data)
        self.assertEqual({i["decision"] for i in items}, {"D1", "D2"})

    def test_poll_orders_batch_by_ts_last_write_wins(self):
        """A later ts sorts last so the agent's last apply wins."""
        self._post_answer("D3", "A", 2)
        self._post_answer("D3", "B", 1)
        status, data = self._request("GET", "/poll?wait=1")
        items = json.loads(data)
        self.assertEqual([i["choice"] for i in items], ["B", "A"])

    def test_inject_fans_out_one_sse_frame(self):
        """POST /inject delivers a data: frame to a live /events stream."""
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", f"/events?token={TOKEN}")
        resp = conn.getresponse()
        self.addCleanup(conn.close)
        self.assertEqual(resp.status, 200)

        status, _ = self._request("POST", "/inject", {"op": "append", "id": "d99", "html": "<section></section>"})
        self.assertEqual(status, 200)

        deadline = time.time() + 5
        frame = ""
        while time.time() < deadline:
            line = resp.fp.readline().decode()
            if line.startswith("data:"):
                frame = line
                break
        self.assertIn("d99", frame)
        payload = json.loads(frame[len("data:"):].strip())
        self.assertEqual(payload["op"], "append")

    def test_events_rejects_missing_token(self):
        status, _ = self._request("GET", "/events", token=None)
        self.assertEqual(status, 401)


if __name__ == "__main__":
    unittest.main()
