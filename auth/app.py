import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
from http.server import BaseHTTPRequestHandler
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

DB_PATH = os.getenv("ZORIX_AUTH_DB", "/data/zorix_auth.sqlite3")
JWT_SECRET = os.getenv("ZORIX_JWT_SECRET", "")
TOKEN_TTL = int(os.getenv("ZORIX_TOKEN_TTL", "604800"))
GAME_HOST = os.getenv("ZORIX_GAME_HOST", "")
GAME_PORT = int(os.getenv("ZORIX_GAME_PORT", "24560"))
GAME_MODE = os.getenv("ZORIX_GAME_MODE", "battle_royale")
MAX_PLAYERS = min(50, max(2, int(os.getenv("ZORIX_MAX_PLAYERS", "50"))))

app = FastAPI(title="ZORIX Player API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET", "POST"], allow_headers=["Authorization", "Content-Type"])

class Credentials(BaseModel):
    username: str = Field(min_length=3, max_length=20)
    password: str = Field(min_length=8, max_length=128)

def db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("""CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at INTEGER NOT NULL
    )""")
    con.commit()
    return con

def hash_password(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 310000).hex()

def b64(data: bytes) -> str:
    import base64
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def issue_token(player_id: int, username: str) -> str:
    if len(JWT_SECRET) < 32:
        raise HTTPException(503, "Server auth secret is not configured")
    now = int(time.time())
    header = b64(b'{"alg":"HS256","typ":"JWT"}')
    payload = b64(json.dumps({"sub": player_id, "name": username, "iat": now, "exp": now + TOKEN_TTL}, separators=(",", ":")).encode())
    body = header + "." + payload
    signature = b64(hmac.new(JWT_SECRET.encode(), body.encode(), hashlib.sha256).digest())
    return body + "." + signature

def current_player(authorization: Optional[str] = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Login required")
    token = authorization[7:]
    try:
        header, payload, signature = token.split(".")
        body = header + "." + payload
        expected = b64(hmac.new(JWT_SECRET.encode(), body.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            raise ValueError("signature")
        import base64
        claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        if int(claims["exp"]) < int(time.time()):
            raise ValueError("expired")
        return {"id": int(claims["sub"]), "username": str(claims["name"])}
    except Exception:
        raise HTTPException(401, "Session expired; please log in again")

@app.get("/api/health")
def health():
    return {"ok": True, "service": "zorix-player-api"}

@app.post("/api/register")
def register(body: Credentials):
    username = body.username.strip()
    if not re.fullmatch(r"[A-Za-z0-9_]{3,20}", username):
        raise HTTPException(400, "Username: 3-20 letters, numbers or underscore")
    salt = secrets.token_bytes(16)
    con = db()
    try:
        cur = con.execute("INSERT INTO players(username,salt,password_hash,created_at) VALUES(?,?,?,?)",
            (username.lower(), salt.hex(), hash_password(body.password, salt), int(time.time())))
        con.commit()
        player_id = cur.lastrowid
    except sqlite3.IntegrityError:
        raise HTTPException(409, "Username already exists")
    finally:
        con.close()
    return {"token": issue_token(player_id, username), "player": {"id": player_id, "username": username}}

@app.post("/api/login")
def login(body: Credentials):
    con = db()
    try:
        row = con.execute("SELECT * FROM players WHERE username=?", (body.username.strip().lower(),)).fetchone()
    finally:
        con.close()
    if row is None or not hmac.compare_digest(hash_password(body.password, bytes.fromhex(row["salt"])), row["password_hash"]):
        raise HTTPException(401, "Wrong username or password")
    return {"token": issue_token(row["id"], row["username"]), "player": {"id": row["id"], "username": row["username"]}}

@app.get("/api/me")
def me(player=Depends(current_player)):
    return {"player": player}

@app.get("/api/lobby")
def lobby(player=Depends(current_player)):
    servers = []
    if GAME_HOST:
        servers.append({"name": "ZORIX Public Match", "host": GAME_HOST, "port": GAME_PORT,
                        "mode": GAME_MODE, "max_players": MAX_PLAYERS, "status": "configured"})
    return {"player": player, "servers": servers, "message": "No public game server configured" if not servers else "Select a server"}


# Bundled player social, matchmaking and progression API.
# Support both CI/package import (auth.app) and the Docker image's app module.
try:
    from .game_features import install_game_feature_routes
except ImportError:
    from game_features import install_game_feature_routes
install_game_feature_routes(app, db, current_player)
