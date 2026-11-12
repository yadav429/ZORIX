"""Read-only 1,000-session smoke/load test for the ZORIX hosted Player API.

No accounts are created. Protected endpoints are expected to reject anonymous
requests with HTTP 401. This does NOT test authenticated matchmaking or UDP gameplay.
"""
from urllib.parse import urlparse

from locust import HttpUser, between, events, task

TARGET = "https://zorix-player-api-dnz5.onrender.com"


@events.test_start.add_listener
def validate_target(environment, **kwargs):
    if environment.host != TARGET:
        raise RuntimeError(f"This controlled profile may only target {TARGET}")
    users = getattr(environment.parsed_options, "num_users", 0) or 0
    if users != 1000:
        raise RuntimeError(f"This profile requires exactly 1000 virtual users, got {users}")
    parsed = urlparse(environment.host)
    if parsed.scheme != "https" or parsed.hostname != "zorix-player-api-dnz5.onrender.com":
        raise RuntimeError("Refusing unexpected load-test target")


class ZorixReadOnlySession(HttpUser):
    # Gentle request rate: approximately 1 request per user every 8–12 seconds.
    wait_time = between(8, 12)

    @task(5)
    def health(self):
        with self.client.get("/api/health", name="GET /api/health", catch_response=True) as r:
            if r.status_code != 200:
                r.failure(f"health returned HTTP {r.status_code}")
            else:
                r.success()

    @task(2)
    def protected_profile_guard(self):
        with self.client.get("/api/me", name="GET /api/me (anonymous guard)", catch_response=True) as r:
            if r.status_code != 401:
                r.failure(f"expected HTTP 401, got {r.status_code}")
            else:
                r.success()

    @task(1)
    def protected_lobby_guard(self):
        with self.client.get("/api/lobby", name="GET /api/lobby (anonymous guard)", catch_response=True) as r:
            if r.status_code != 401:
                r.failure(f"expected HTTP 401, got {r.status_code}")
            else:
                r.success()
