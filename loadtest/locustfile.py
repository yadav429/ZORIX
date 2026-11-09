"""Controlled ZORIX auth API load test. Never point this at production."""
import os
import uuid
from urllib.parse import urlparse

from locust import HttpUser, between, events, task
from locust.exception import StopUser

PASSWORD = os.getenv("ZORIX_LOADTEST_PASSWORD", "ZorixLoadTestOnly!2026")
RUN_TAG = os.getenv("ZORIX_LOADTEST_RUN_TAG", uuid.uuid4().hex[:8])
ALLOW_REMOTE = os.getenv("ZORIX_LOADTEST_ALLOW_REMOTE") == "YES"


@events.test_start.add_listener
def validate_test_target(environment, **kwargs):
    host = environment.host or ""
    parsed = urlparse(host)
    hostname = (parsed.hostname or "").lower()
    local = hostname in {"localhost", "127.0.0.1", "::1"}
    if not host or parsed.scheme not in {"http", "https"}:
        raise RuntimeError("Set --host to an explicit http(s) ZORIX API URL")
    if not local and (not ALLOW_REMOTE or parsed.scheme != "https"):
        raise RuntimeError(
            "Remote targets require HTTPS and ZORIX_LOADTEST_ALLOW_REMOTE=YES. "
            "Use a staging server you own; production is not supported."
        )
    options = environment.parsed_options
    users = getattr(options, "num_users", 1) or 1
    configured_cap = int(os.getenv("ZORIX_LOADTEST_MAX_USERS", "1000"))
    cap = min(max(configured_cap, 1), 10000)
    if users > cap:
        raise RuntimeError(f"Requested {users} users exceeds configured safety cap {cap}")


class ZorixPlayer(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        # One fresh synthetic account per virtual user; never use real credentials.
        self.username = f"lt{RUN_TAG}{uuid.uuid4().hex[:8]}"[:20]
        self.token = None
        with self.client.post(
            "/api/register",
            json={"username": self.username, "password": PASSWORD},
            name="POST /api/register (synthetic user)",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"register returned {response.status_code}")
                raise StopUser()
            try:
                self.token = response.json()["token"]
            except (ValueError, KeyError, TypeError):
                response.failure("register response missing token")
                raise StopUser()
        self._login()

    def _login(self):
        with self.client.post(
            "/api/login",
            json={"username": self.username, "password": PASSWORD},
            name="POST /api/login",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"login returned {response.status_code}")
                self.token = None
                return
            try:
                self.token = response.json()["token"]
                response.success()
            except (ValueError, KeyError, TypeError):
                response.failure("login response missing token")
                self.token = None

    @task(5)
    def login(self):
        self._login()

    @task(3)
    def profile(self):
        if not self.token:
            return self._login()
        self.client.get("/api/me", headers={"Authorization": f"Bearer {self.token}"}, name="GET /api/me")

    @task(2)
    def public_lobby(self):
        if not self.token:
            return self._login()
        self.client.get("/api/lobby", headers={"Authorization": f"Bearer {self.token}"}, name="GET /api/lobby")
