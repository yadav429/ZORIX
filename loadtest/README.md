# ZORIX controlled API load testing

This suite measures the **player account HTTP API** from PR #9: registration, login, authenticated profile, and lobby discovery. It does not simulate Godot/ENet game clients, movement, combat, or 50-player matches.

## Safety limits

- Use only a local instance or a staging server you own and have permission to test.
- Remote targets must use HTTPS and require `ZORIX_LOADTEST_ALLOW_REMOTE=YES`.
- Default maximum is 1,000 virtual users. Set `ZORIX_LOADTEST_MAX_USERS` to a value from 1 to 10,000 only after the previous stage is healthy. The hard cap is 10,000 per Locust process.
- Do not point this at production, public third-party APIs, or a server without operator approval. Load testing can exhaust CPU, RAM, database connections, bandwidth, or hosting quotas.
- The tool creates synthetic accounts with random usernames and a test-only password. Never supply real player credentials.
- A 10,000-user single-process run is not a 100,000-user test. A future 100k test requires a dedicated distributed load-generator fleet and explicit operator-approved staging capacity.

## Start the API locally

From the repository root, install the API dependencies and run the service with a test-only secret and a local database:

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r auth/requirements.txt
export ZORIX_JWT_SECRET="local-only-change-me-0123456789abcdef"
export ZORIX_AUTH_DB="./tmp/zorix-loadtest.sqlite3"
uvicorn auth.app:app --host 127.0.0.1 --port 8080
```

On a separate terminal:

```bash
python -m venv .venv-loadtest
. .venv-loadtest/bin/activate
pip install -r loadtest/requirements.txt
locust -f loadtest/locustfile.py --host http://127.0.0.1:8080 --users 10 --spawn-rate 2 --run-time 2m --headless --html loadtest-report.html
```

## Staged test plan

Run one stage at a time and inspect the report before increasing load:

| Stage | Virtual users | Suggested spawn rate | Minimum observation |
|---|---:|---:|---:|
| 1 | 10 | 2/sec | 2 minutes |
| 2 | 50 | 5/sec | 5 minutes |
| 3 | 100 | 5/sec | 5 minutes |
| 4 | 500 | 10/sec | 5 minutes |
| 5 | 1,000 | 10/sec | 10 minutes |

Example for a later stage (only after the previous stage is healthy):

```bash
ZORIX_LOADTEST_MAX_USERS=1000 locust -f loadtest/locustfile.py --host http://127.0.0.1:8080 --users 100 --spawn-rate 5 --run-time 5m --headless --html loadtest-report-100.html
```

For an authorized remote staging host:

```bash
ZORIX_LOADTEST_ALLOW_REMOTE=YES ZORIX_LOADTEST_MAX_USERS=1000 locust -f loadtest/locustfile.py --host https://staging.example.com --users 50 --spawn-rate 5 --run-time 5m --headless
```

Replace the example host with your own HTTPS staging API. Never place credentials or secrets in the command line or repository.

## What to review

- Requests/sec and response-time percentiles (p50, p95, p99).
- Failure rate by endpoint and HTTP status.
- API process CPU/RAM, SQLite file growth, disk I/O, and host memory.
- Whether response times or failures climb as concurrent users increase.

Stop the test immediately if the service becomes unhealthy, error rate rises sharply, or resource usage approaches the host limit. Save each HTML report with the tested commit, host type, user count, spawn rate, and date.

## Important interpretation

The current PR #9 auth service uses SQLite and PBKDF2 password hashing. Registration/login may become CPU- and database-write-bound under concurrency. This test is designed to expose that bottleneck, not to certify a production capacity. Do not claim support for 1 lakh simultaneous players from a successful 1,000-user API test. Game-server ENet capacity needs a separate multiplayer load test.
