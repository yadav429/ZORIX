"""Dedicated-server registry, matchmaking allocator and signed one-time join tickets."""
import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api", tags=["server-fleet"])
SERVER_SECRET = os.getenv("ZORIX_SERVER_SECRET", "")
TICKET_SECRET = os.getenv("ZORIX_JOIN_TICKET_SECRET", "") or SERVER_SECRET
HEARTBEAT_TTL = max(15, int(os.getenv("ZORIX_SERVER_HEARTBEAT_TTL", "45")))
MATCH_SIZE = min(50, max(2, int(os.getenv("ZORIX_MATCH_SIZE", "50"))))


class ServerRegister(BaseModel):
    name: str = Field(min_length=2, max_length=48)
    host: str = Field(min_length=3, max_length=255)
    port: int = Field(ge=1, le=65535)
    mode: str = Field(default="battle_royale", min_length=2, max_length=32)
    region: str = Field(default="global", min_length=2, max_length=24)
    max_players: int = Field(default=50, ge=2, le=50)


class ServerHeartbeat(BaseModel):
    active_players: int = Field(ge=0, le=50)
    reserved_players: int = Field(default=0, ge=0, le=50)


class AllocateRequest(BaseModel):
    mode: str = Field(pattern="^(solo|duo|squad)$")
    limit: int = Field(default=50, ge=2, le=50)


class TicketConsume(BaseModel):
    ticket: str = Field(min_length=20, max_length=2048)


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _unb64(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def _ticket(player_id: int, match_id: int, server_id: str, expires: int) -> str:
    if len(TICKET_SECRET) < 32:
        raise HTTPException(503, "ZORIX_JOIN_TICKET_SECRET (or ZORIX_SERVER_SECRET) must be at least 32 characters")
    payload = _b64(json.dumps({
        "sub": player_id, "match": match_id, "server": server_id,
        "exp": expires, "nonce": secrets.token_urlsafe(12)
    }, separators=(",", ":")).encode())
    signature = _b64(hmac.new(TICKET_SECRET.encode(), payload.encode(), hashlib.sha256).digest())
    return payload + "." + signature


def _server_auth(value: Optional[str]):
    if len(SERVER_SECRET) < 32 or not value or not hmac.compare_digest(SERVER_SECRET, value):
        raise HTTPException(403, "Dedicated server authentication failed")


def install_server_fleet_routes(app, db_factory, current_player):
    def init(con):
        con.executescript("""
        CREATE TABLE IF NOT EXISTS game_servers (
            server_id TEXT PRIMARY KEY, name TEXT NOT NULL, host TEXT NOT NULL,
            port INTEGER NOT NULL, mode TEXT NOT NULL, region TEXT NOT NULL,
            max_players INTEGER NOT NULL CHECK(max_players BETWEEN 2 AND 50),
            active_players INTEGER NOT NULL DEFAULT 0,
            reserved_players INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'online', last_heartbeat INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS match_server_assignments (
            match_id INTEGER PRIMARY KEY, server_id TEXT NOT NULL,
            assigned_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS player_join_tickets (
            player_id INTEGER NOT NULL, match_id INTEGER NOT NULL,
            token_hash TEXT NOT NULL, expires_at INTEGER NOT NULL,
            consumed_at INTEGER, PRIMARY KEY(player_id, match_id)
        );
        CREATE INDEX IF NOT EXISTS idx_game_servers_capacity
            ON game_servers(status, mode, last_heartbeat);
        CREATE INDEX IF NOT EXISTS idx_match_queue_mode_time
            ON match_queue(mode, queued_at);
        """)
        con.commit()

    def connection():
        con = db_factory()
        init(con)
        return con

    @router.post("/internal/servers/register")
    def register_server(body: ServerRegister, x_zorix_server_secret: Optional[str] = Header(default=None)):
        _server_auth(x_zorix_server_secret)
        con = connection()
        try:
            server_id = "zs_" + secrets.token_hex(10)
            now = int(time.time())
            con.execute("""INSERT INTO game_servers
                (server_id,name,host,port,mode,region,max_players,last_heartbeat)
                VALUES(?,?,?,?,?,?,?,?)""",
                (server_id, body.name, body.host, body.port, body.mode,
                 body.region, body.max_players, now))
            con.commit()
            return {"ok": True, "server_id": server_id, "heartbeat_ttl_seconds": HEARTBEAT_TTL}
        finally:
            con.close()

    @router.post("/internal/servers/{server_id}/heartbeat")
    def heartbeat(server_id: str, body: ServerHeartbeat,
                  x_zorix_server_secret: Optional[str] = Header(default=None)):
        _server_auth(x_zorix_server_secret)
        con = connection()
        try:
            cur = con.execute("""UPDATE game_servers SET active_players=?,
                reserved_players=?, status='online', last_heartbeat=? WHERE server_id=?""",
                (body.active_players, body.reserved_players, int(time.time()), server_id))
            con.commit()
            if cur.rowcount == 0:
                raise HTTPException(404, "Server not registered")
            return {"ok": True, "server_id": server_id}
        finally:
            con.close()

    @router.post("/internal/matches/allocate")
    def allocate(body: AllocateRequest, x_zorix_server_secret: Optional[str] = Header(default=None)):
        _server_auth(x_zorix_server_secret)
        con = connection()
        try:
            # Serialize allocation decisions so concurrent workers cannot reserve the same queue rows.
            con.execute("BEGIN IMMEDIATE")
            now = int(time.time())
            server = con.execute("""SELECT * FROM game_servers
                WHERE status='online' AND last_heartbeat>=? AND mode IN (?, 'battle_royale')
                AND max_players-active_players-reserved_players>=?
                ORDER BY (max_players-active_players-reserved_players) DESC LIMIT 1""",
                (now - HEARTBEAT_TTL, body.mode, body.limit)).fetchone()
            if server is None:
                con.rollback()
                return {"status": "waiting", "reason": "No healthy server has enough free slots"}
            queued = con.execute("""SELECT q.player_id,q.team_id,q.queued_at
                FROM match_queue q WHERE q.mode=? ORDER BY q.queued_at,q.player_id""",
                (body.mode,)).fetchall()
            # Keep Duo/Squad together; only complete teams are eligible.
            units = []
            seen_teams = set()
            for row in queued:
                tid = row["team_id"]
                if tid is None:
                    units.append([int(row["player_id"])])
                elif tid not in seen_teams:
                    seen_teams.add(tid)
                    members = con.execute("""SELECT tm.player_id FROM team_members tm
                        JOIN match_queue q ON q.player_id=tm.player_id
                        WHERE tm.team_id=? AND q.mode=? ORDER BY tm.joined_at""",
                        (tid, body.mode)).fetchall()
                    all_members = con.execute("SELECT COUNT(*) n FROM team_members WHERE team_id=?", (tid,)).fetchone()["n"]
                    if len(members) == all_members:
                        units.append([int(m["player_id"]) for m in members])
            selected = []
            for unit in units:
                if len(selected) + len(unit) > min(body.limit, int(server["max_players"])):
                    continue
                selected.extend(unit)
                if len(selected) == min(body.limit, int(server["max_players"])):
                    break
            if len(selected) < min(body.limit, int(server["max_players"])):
                con.rollback()
                return {"status": "waiting", "players_ready": len(selected),
                        "players_required": min(body.limit, int(server["max_players"]))}
            cur = con.execute("INSERT INTO game_matches(mode,status,created_at) VALUES(?,?,?)",
                              (body.mode, "allocated", now))
            match_id = int(cur.lastrowid)
            con.execute("INSERT INTO match_server_assignments(match_id,server_id,assigned_at) VALUES(?,?,?)",
                        (match_id, server["server_id"], now))
            for index, pid in enumerate(selected):
                con.execute("INSERT INTO match_players(match_id,player_id,team_number) VALUES(?,?,?)",
                            (match_id, pid, index // (4 if body.mode == "squad" else 2 if body.mode == "duo" else 1)))
                con.execute("DELETE FROM match_queue WHERE player_id=?", (pid,))
            con.execute("UPDATE game_servers SET reserved_players=reserved_players+?,last_heartbeat=? WHERE server_id=?",
                        (len(selected), now, server["server_id"]))
            con.commit()
            return {"status": "allocated", "match_id": match_id, "server_id": server["server_id"],
                    "mode": body.mode, "players": len(selected), "max_players": int(server["max_players"])}
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()

    @router.get("/matchmaking/status")
    def matchmaking_status(player=Depends(current_player)):
        con = connection()
        try:
            row = con.execute("""SELECT mp.match_id,gm.mode,gm.status,gs.server_id,gs.host,gs.port
                FROM match_players mp JOIN game_matches gm ON gm.id=mp.match_id
                JOIN match_server_assignments msa ON msa.match_id=gm.id
                JOIN game_servers gs ON gs.server_id=msa.server_id
                WHERE mp.player_id=? AND gm.status='allocated'
                ORDER BY gm.created_at DESC LIMIT 1""", (player["id"],)).fetchone()
            if row is None:
                queued = con.execute("SELECT mode,queued_at FROM match_queue WHERE player_id=?", (player["id"],)).fetchone()
                return {"status": "queued" if queued else "not_queued",
                        "mode": queued["mode"] if queued else None}
            expires = int(time.time()) + 120
            token = _ticket(int(player["id"]), int(row["match_id"]), row["server_id"], expires)
            digest = hashlib.sha256(token.encode()).hexdigest()
            con.execute("""INSERT INTO player_join_tickets(player_id,match_id,token_hash,expires_at,consumed_at)
                VALUES(?,?,?,?,NULL) ON CONFLICT(player_id,match_id) DO UPDATE SET
                token_hash=excluded.token_hash,expires_at=excluded.expires_at,consumed_at=NULL""",
                (player["id"], row["match_id"], digest, expires))
            con.commit()
            return {"status": "allocated", "match_id": row["match_id"], "mode": row["mode"],
                    "server": {"host": row["host"], "port": row["port"]},
                    "join_ticket": token, "ticket_expires_at": expires}
        finally:
            con.close()

    @router.post("/internal/join-ticket/consume")
    def consume_ticket(body: TicketConsume, x_zorix_server_secret: Optional[str] = Header(default=None)):
        _server_auth(x_zorix_server_secret)
        try:
            payload_part, signature = body.ticket.split(".", 1)
            expected = _b64(hmac.new(TICKET_SECRET.encode(), payload_part.encode(), hashlib.sha256).digest())
            if len(TICKET_SECRET) < 32 or not hmac.compare_digest(signature, expected):
                raise ValueError("signature")
            claims = json.loads(_unb64(payload_part))
            if int(claims["exp"]) < int(time.time()):
                raise ValueError("expired")
        except Exception:
            raise HTTPException(401, "Invalid or expired join ticket")
        digest = hashlib.sha256(body.ticket.encode()).hexdigest()
        con = connection()
        try:
            con.execute("BEGIN IMMEDIATE")
            cur = con.execute("""UPDATE player_join_tickets SET consumed_at=?
                WHERE player_id=? AND match_id=? AND token_hash=? AND consumed_at IS NULL AND expires_at>=?""",
                (int(time.time()), int(claims["sub"]), int(claims["match"]), digest, int(time.time())))
            if cur.rowcount != 1:
                con.rollback()
                raise HTTPException(401, "Join ticket already used or revoked")
            assignment = con.execute("SELECT server_id FROM match_server_assignments WHERE match_id=?",
                                     (int(claims["match"]),)).fetchone()
            if assignment is None or assignment["server_id"] != claims["server"]:
                con.rollback()
                raise HTTPException(401, "Ticket is not for this game server")
            con.commit()
            return {"ok": True, "player_id": int(claims["sub"]), "match_id": int(claims["match"])}
        finally:
            con.close()

    app.include_router(router)
