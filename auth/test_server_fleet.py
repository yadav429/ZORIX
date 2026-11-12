"""End-to-end tests for server registration, allocation and one-time join tickets."""
import os
import tempfile
import time
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

        server_headers = {**headers, "X-Zorix-Server-Id": server_id}
        heartbeat = client.post(
            f"/api/internal/servers/{server_id}/heartbeat",
            headers=server_headers, json={"active_players": 0, "reserved_players": 0}
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

        consumed = client.post("/api/internal/join-ticket/consume", headers=server_headers, json={"ticket": ticket})
        self.assertEqual(consumed.status_code, 200, consumed.text)
        replay = client.post("/api/internal/join-ticket/consume", headers=server_headers, json={"ticket": ticket})
        self.assertEqual(replay.status_code, 401)
        joined_status = client.get("/api/matchmaking/status", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(joined_status.status_code, 200, joined_status.text)
        self.assertEqual(joined_status.json()["status"], "joined")
        self.assertNotIn("join_ticket", joined_status.json())



    def test_player_polling_auto_allocates_and_returns_signed_ticket(self):
        client = TestClient(app)
        secret = os.environ["ZORIX_SERVER_SECRET"]
        headers = {"X-Zorix-Server-Secret": secret}
        registered = client.post("/api/internal/servers/register", headers=headers, json={
            "name": "auto-queue-server", "host": "127.0.0.2", "port": 24561,
            "mode": "battle_royale", "region": "test", "max_players": 50
        })
        self.assertEqual(registered.status_code, 200, registered.text)
        server_id = registered.json()["server_id"]
        server_headers = {**headers, "X-Zorix-Server-Id": server_id}
        heartbeat = client.post(
            f"/api/internal/servers/{server_id}/heartbeat",
            headers=server_headers, json={"active_players": 0, "reserved_players": 0}
        )
        self.assertEqual(heartbeat.status_code, 200, heartbeat.text)

        con = db()
        try:
            ids = []
            for suffix in ("autoa", "autob"):
                cur = con.execute(
                    "INSERT INTO players(username,salt,password_hash,created_at) VALUES(?,?,?,?)",
                    (suffix, "00", "unused", 1)
                )
                ids.append(cur.lastrowid)
                con.execute(
                    "INSERT INTO match_queue(player_id,mode,team_id,queued_at) VALUES(?,?,NULL,?)",
                    (cur.lastrowid, "solo", int(time.time()))
                )
            con.commit()
        finally:
            con.close()

        token = issue_token(ids[0], "autoa")
        status = client.get("/api/matchmaking/status", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(status.status_code, 200, status.text)
        payload = status.json()
        self.assertEqual(payload["status"], "allocated")
        self.assertEqual(payload["server"]["port"], 24561)
        self.assertTrue(payload["join_ticket"])
        self.assertEqual(payload["mode"], "solo")

        consumed = client.post(
            "/api/internal/join-ticket/consume",
            headers=server_headers,
            json={"ticket": payload["join_ticket"]}
        )
        self.assertEqual(consumed.status_code, 200, consumed.text)
        self.assertEqual(consumed.json()["team_number"], 0)
        self.assertEqual(consumed.json()["mode"], "solo")

if __name__ == "__main__":
    unittest.main()
