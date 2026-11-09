"""10,000 synthetic authenticated sessions against a LOCAL ZORIX API only.

This does not create real player accounts and does not exercise the Godot ENet game server.
"""
import base64
import hashlib
import hmac
import json
import os
import time
import uuid
from urllib.parse import urlparse

from locust import HttpUser, between, events, task

SECRET = os.getenv("ZORIX_JWT_SECRET", "")
if len(SECRET) < 32:
    raise RuntimeError("ZORIX_JWT_SECRET must be at least 32 chars (CI-only test secret)")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _synthetic_token() -> str:
    """Mint an API-compatible test token without inserting accounts or hashing passwords."""
    now = int(time.time())
    user_id = uuid.uuid4().int >> 64
    username = "load_" + uuid.uuid4().hex[:12]
    header = _b64(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64(json.dumps(
        {"sub": user_id, "name": username, "iat": now, "exp": now + 3600},
        separators=(",", ":"),
    ).encode())
    signing_input = header + "." + payload
    signature = _b64(hmac.new(SECRET.encode(), signing_input.encode(), hashlib.sha256).digest())
    return signing_input + "." + signature


@events.test_start.add_listener
def local_target_only(environment, **kwargs):
    parsed = urlparse(environment.host or "")
    if parsed.scheme != "http" or (parsed.hostname or "").lower() not in {"127.0.0.1", "localhost", "::1"}:
        raise RuntimeError("10k synthetic test is restricted to local HTTP loopback; do not target public services")
    users = getattr(environment.parsed_options, "num_users", 0) or 0
    if users != 10000:
        raise RuntimeError(f"This profile is designed for exactly 10000 virtual users, got {users}")


class SyntheticZorixPlayer(HttpUser):
    # 10k concurrent virtual sessions, with a deliberately moderate request rate.
    wait_time = between(5, 10)

    def on_start(self):
        self.token = _synthetic_token()
        self.headers = {"Authorization": "Bearer " + self.token}

    @task(5)
    def profile(self):
        self.client.get("/api/me", headers=self.headers, name="GET /api/me (synthetic session)")

    @task(3)
    def lobby(self):
        self.client.get("/api/lobby", headers=self.headers, name="GET /api/lobby (synthetic session)")

    @task(1)
    def health(self):
        self.client.get("/api/health", name="GET /api/health")
