"""End-to-end tests for server registration, allocation and one-time join tickets."""
import os
import tempfile
import unittest

DB_FILE = tempfile.mktemp(prefix="zorix-fleet-", suffix=".sqlite3")
os.environ["ZORIX_AUTH_DB"] = DB_FILE
os.environ["ZORIX_JWT_SECRET"] = "ci-jwt-secret-that-is-at-least-32-bytes"
os.environ["ZORIX_SERVER_SECRET"] = "ci-server-secret-that-is-at-least-32-bytes"
os.environ["ZORIX_JOIN_TICKET_SECRET"] = "ci-join-ticket-secret-that-is-32-bytes"

from fastapi.testclient import TestClient
from auth.app import app, db, issue_token


class ServerFleetTests(unittest.TestCase):
    def test_allocate_and_consume_ticket_once(self):
        client = TestClient(app)
        secret = os.environ["ZORIX_SERVER_SECRET"]
        headers = {"X-Zorix-Server-Secret": secret}

        registered = client.post("/api/internal/servers/register", headers=headers, json={
            "name": "ci-server", "host": "127.0.0.1", "port": 24560,
            "mode": "battle_royale", "region": "test", "max_players": 50
        })
        self.assertEqual(registered.status_code, 200, registered.text)
        server_id = registered.json()["server_id"]

        heartbeat = client.post(
            f"/api/internal/servers/{server_id}/heartbeat",
            headers=headers, json={"active_players": 0, "reserved_players": 0}
        )
        self.assertEqual(heartbeat.status_code, 200, heartbeat.text)

        con = db()
        try:
            con.executescript("""
                CREATE TABLE IF NOT EXISTS match_queue (
                    player_id INTEGER PRIMARY KEY, mode TEXT NOT NULL,
                    team_id INTEGER, queued_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS game_matches (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    mode TEXT NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS match_players (
                    match_id INTEGER NOT NULL, player_id INTEGER NOT NULL,
                    team_number INTEGER NOT NULL, PRIMARY KEY(match_id, player_id)
                );
                CREATE TABLE IF NOT EXISTS team_members (
                    team_id INTEGER NOT NULL, player_id INTEGER NOT NULL,
                    joined_at INTEGER NOT NULL, PRIMARY KEY(team_id, player_id)
                );
            """)
            for pid in range(1, 51):
                con.execute(
                    "INSERT INTO players(id,username,salt,password_hash,created_at) VALUES(?,?,?,?,?)",
                    (pid, f"player{pid}", "00", "unused", 1)
                )
                con.execute(
                    "INSERT INTO match_queue(player_id,mode,team_id,queued_at) VALUES(?,?,NULL,?)",
                    (pid, "solo", pid)
                )
            con.commit()
        finally:
            con.close()

        allocated = client.post(
            "/api/internal/matches/allocate", headers=headers, json={"mode": "solo", "limit": 50}
        )
        self.assertEqual(allocated.status_code, 200, allocated.text)
        self.assertEqual(allocated.json()["status"], "allocated")
        self.assertEqual(allocated.json()["players"], 50)

        token = issue_token(1, "player1")
        status = client.get("/api/matchmaking/status", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(status.status_code, 200, status.text)
        ticket = status.json()["join_ticket"]

        consumed = client.post("/api/internal/join-ticket/consume", headers=headers, json={"ticket": ticket})
        self.assertEqual(consumed.status_code, 200, consumed.text)
        replay = client.post("/api/internal/join-ticket/consume", headers=headers, json={"ticket": ticket})
        self.assertEqual(replay.status_code, 401)


if __name__ == "__main__":
    unittest.main()
