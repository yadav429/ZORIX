"""ZORIX social, matchmaking and progression API routes."""
import os, secrets, sqlite3, time
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api", tags=["game-features"])
SERVER_SECRET = os.getenv("ZORIX_SERVER_SECRET", "")

class ProfileUpdate(BaseModel):
    display_name: Optional[str] = Field(default=None, min_length=3, max_length=24)
    bio: Optional[str] = Field(default=None, max_length=160)
class FriendRequest(BaseModel):
    public_id: Optional[str] = Field(default=None, min_length=6, max_length=16)
    username: Optional[str] = Field(default=None, min_length=3, max_length=20)
class TeamCreate(BaseModel):
    name: str = Field(min_length=3, max_length=24)
    mode: str = Field(pattern="^(solo|duo|squad)$")
class TeamJoin(BaseModel):
    invite_code: str = Field(min_length=6, max_length=12)
class QueueRequest(BaseModel):
    mode: str = Field(pattern="^(solo|duo|squad)$")
class EquipSkin(BaseModel):
    skin_id: str = Field(min_length=2, max_length=48)
class MatchResult(BaseModel):
    player_id: int = Field(gt=0)
    placement: int = Field(ge=1, le=50)
    kills: int = Field(ge=0, le=50)

def install_game_feature_routes(app, db_factory, current_player):
    def init_features(con):
        con.executescript("""
        CREATE TABLE IF NOT EXISTS player_profiles (player_id INTEGER PRIMARY KEY, public_id TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL, bio TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS friendships (requester_id INTEGER NOT NULL, addressee_id INTEGER NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(requester_id, addressee_id));
        CREATE TABLE IF NOT EXISTS game_teams (id INTEGER PRIMARY KEY AUTOINCREMENT, invite_code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, mode TEXT NOT NULL, leader_id INTEGER NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS team_members (team_id INTEGER NOT NULL, player_id INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(team_id, player_id), UNIQUE(player_id));
        CREATE TABLE IF NOT EXISTS match_queue (player_id INTEGER PRIMARY KEY, mode TEXT NOT NULL, team_id INTEGER, queued_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS game_matches (id INTEGER PRIMARY KEY AUTOINCREMENT, mode TEXT NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS match_players (match_id INTEGER NOT NULL, player_id INTEGER NOT NULL, team_number INTEGER NOT NULL, PRIMARY KEY(match_id, player_id));
        CREATE TABLE IF NOT EXISTS player_stats (player_id INTEGER PRIMARY KEY, rating INTEGER NOT NULL DEFAULT 1000, wins INTEGER NOT NULL DEFAULT 0, kills INTEGER NOT NULL DEFAULT 0, matches INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS skin_catalog (skin_id TEXT PRIMARY KEY, name TEXT NOT NULL, weapon TEXT NOT NULL, rarity TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS player_inventory (player_id INTEGER NOT NULL, skin_id TEXT NOT NULL, acquired_at INTEGER NOT NULL, PRIMARY KEY(player_id, skin_id));
        CREATE TABLE IF NOT EXISTS equipped_skins (player_id INTEGER NOT NULL, weapon TEXT NOT NULL, skin_id TEXT NOT NULL, PRIMARY KEY(player_id, weapon));
        """)
        con.executemany("INSERT OR IGNORE INTO skin_catalog VALUES(?,?,?,?)", [
            ("starter_rifle","Frontier","Rifle","Common"),("starter_smg","Pulse","SMG","Common"),
            ("ember_rifle","Emberstrike","Rifle","Rare"),("frost_smg","Frostbite","SMG","Epic"),
            ("shadow_sniper","Nightfall","Sniper","Legendary")])
        con.commit()
    def connection():
        con=db_factory(); init_features(con); return con
    def ensure_player(con, player):
        pid=int(player["id"]); username=str(player["username"])
        con.execute("INSERT OR IGNORE INTO player_profiles(player_id,public_id,display_name,created_at) VALUES(?,?,?,?)",(pid,"ZX-"+secrets.token_hex(4).upper(),username,int(time.time())))
        con.execute("INSERT OR IGNORE INTO player_stats(player_id) VALUES(?)",(pid,))
        con.execute("INSERT OR IGNORE INTO player_inventory(player_id,skin_id,acquired_at) VALUES(?,?,?)",(pid,"starter_rifle",int(time.time())))
        con.commit()

    @router.get("/profile")
    def get_profile(player=Depends(current_player)):
        con=connection()
        try:
            ensure_player(con,player)
            row=con.execute("SELECT p.public_id,p.display_name,p.bio,s.rating,s.wins,s.kills,s.matches FROM player_profiles p JOIN player_stats s ON s.player_id=p.player_id WHERE p.player_id=?",(player["id"],)).fetchone()
            return {"profile":dict(row)}
        finally: con.close()

    @router.patch("/profile")
    def update_profile(body:ProfileUpdate,player=Depends(current_player)):
        con=connection()
        try:
            ensure_player(con,player)
            if body.display_name is not None: con.execute("UPDATE player_profiles SET display_name=? WHERE player_id=?",(body.display_name.strip(),player["id"]))
            if body.bio is not None: con.execute("UPDATE player_profiles SET bio=? WHERE player_id=?",(body.bio.strip(),player["id"]))
            con.commit(); return {"ok":True}
        finally: con.close()

    @router.get("/friends")
    def list_friends(player=Depends(current_player)):
        con=connection()
        try:
            rows=con.execute("SELECT p.public_id,p.display_name,f.status,f.requester_id FROM friendships f JOIN player_profiles p ON p.player_id=CASE WHEN f.requester_id=? THEN f.addressee_id ELSE f.requester_id END WHERE f.requester_id=? OR f.addressee_id=?",(player["id"],player["id"],player["id"])).fetchall()
            return {"friends":[dict(x) for x in rows]}
        finally: con.close()

    @router.post("/friends/request")
    def send_friend_request(body:FriendRequest,player=Depends(current_player)):
        con=connection()
        try:
            if body.public_id:
                target=con.execute("SELECT p.player_id AS id,pl.username FROM player_profiles p JOIN players pl ON pl.id=p.player_id WHERE p.public_id=?",(body.public_id.strip().upper(),)).fetchone()
            elif body.username:
                target=con.execute("SELECT id,username FROM players WHERE username=?",(body.username.strip().lower(),)).fetchone()
            else:
                raise HTTPException(400,"Provide a Player ID or username")
            if target is None: raise HTTPException(404,"Player not found")
            if int(target["id"])==int(player["id"]): raise HTTPException(400,"You cannot add yourself")
            con.execute("INSERT OR IGNORE INTO player_profiles(player_id,public_id,display_name,created_at) VALUES(?,?,?,?)",(target["id"],"ZX-"+secrets.token_hex(4).upper(),target["username"],int(time.time())))
            con.execute("INSERT OR IGNORE INTO player_stats(player_id) VALUES(?)",(target["id"],))
            con.execute("INSERT INTO friendships(requester_id,addressee_id,status,created_at) VALUES(?,?,'pending',?) ON CONFLICT(requester_id,addressee_id) DO UPDATE SET status='pending'",(player["id"],target["id"],int(time.time())))
            con.commit(); return {"ok":True,"status":"pending"}
        finally: con.close()

    @router.post("/friends/{requester_id}/accept")
    def accept_friend_request(requester_id:int,player=Depends(current_player)):
        con=connection()
        try:
            cur=con.execute("UPDATE friendships SET status='accepted' WHERE requester_id=? AND addressee_id=? AND status='pending'",(requester_id,player["id"]))
            con.commit()
            if cur.rowcount==0: raise HTTPException(404,"Pending friend request not found")
            return {"ok":True}
        finally: con.close()

    @router.delete("/friends/{other_player_id}")
    def remove_friend(other_player_id:int,player=Depends(current_player)):
        con=connection()
        try:
            con.execute("DELETE FROM friendships WHERE (requester_id=? AND addressee_id=?) OR (requester_id=? AND addressee_id=?)",(player["id"],other_player_id,other_player_id,player["id"]))
            con.commit(); return {"ok":True}
        finally: con.close()

    @router.post("/teams")
    def create_team(body:TeamCreate,player=Depends(current_player)):
        con=connection()
        try:
            existing=con.execute("SELECT team_id FROM team_members WHERE player_id=?",(player["id"],)).fetchone()
            if existing: raise HTTPException(409,"Leave your current team before creating another")
            invite=secrets.token_urlsafe(6)[:8].upper()
            cur=con.execute("INSERT INTO game_teams(invite_code,name,mode,leader_id,created_at) VALUES(?,?,?,?,?)",(invite,body.name.strip(),body.mode,player["id"],int(time.time())))
            tid=cur.lastrowid
            con.execute("INSERT INTO team_members(team_id,player_id,joined_at) VALUES(?,?,?)",(tid,player["id"],int(time.time())))
            con.commit(); return {"team_id":tid,"invite_code":invite,"name":body.name,"mode":body.mode}
        finally: con.close()

    @router.post("/teams/join")
    def join_team(body:TeamJoin,player=Depends(current_player)):
        con=connection()
        try:
            team=con.execute("SELECT * FROM game_teams WHERE invite_code=?",(body.invite_code.upper(),)).fetchone()
            if team is None: raise HTTPException(404,"Team invite not found")
            cap={"solo":1,"duo":2,"squad":4}[team["mode"]]
            count=con.execute("SELECT COUNT(*) n FROM team_members WHERE team_id=?",(team["id"],)).fetchone()["n"]
            if count>=cap: raise HTTPException(409,"Team is full")
            con.execute("INSERT INTO team_members(team_id,player_id,joined_at) VALUES(?,?,?)",(team["id"],player["id"],int(time.time())))
            con.commit(); return {"ok":True,"team_id":team["id"],"mode":team["mode"]}
        except sqlite3.IntegrityError: raise HTTPException(409,"Player is already in a team")
        finally: con.close()

    @router.get("/teams/me")
    def my_team(player=Depends(current_player)):
        con=connection()
        try:
            row=con.execute("SELECT t.id,t.name,t.mode,t.invite_code,t.leader_id,GROUP_CONCAT(p.username) AS members FROM game_teams t JOIN team_members tm ON tm.team_id=t.id JOIN players p ON p.id=tm.player_id WHERE t.id=(SELECT team_id FROM team_members WHERE player_id=?) GROUP BY t.id",(player["id"],)).fetchone()
            return {"team":dict(row) if row else None}
        finally: con.close()

    @router.delete("/teams/me")
    def leave_team(player=Depends(current_player)):
        con=connection()
        try:
            row=con.execute("SELECT team_id FROM team_members WHERE player_id=?",(player["id"],)).fetchone()
            if row is None: return {"ok":True}
            tid=row["team_id"]
            con.execute("DELETE FROM team_members WHERE team_id=? AND player_id=?",(tid,player["id"]))
            next_member=con.execute("SELECT player_id FROM team_members WHERE team_id=? ORDER BY joined_at LIMIT 1",(tid,)).fetchone()
            if next_member: con.execute("UPDATE game_teams SET leader_id=? WHERE id=?",(next_member["player_id"],tid))
            else: con.execute("DELETE FROM game_teams WHERE id=?",(tid,))
            con.commit(); return {"ok":True}
        finally: con.close()

    @router.post("/matchmaking/queue")
    def join_queue(body:QueueRequest,player=Depends(current_player)):
        con=connection()
        try:
            ensure_player(con,player)
            team=con.execute("SELECT t.id,t.mode FROM game_teams t JOIN team_members tm ON tm.team_id=t.id WHERE tm.player_id=?",(player["id"],)).fetchone()
            if body.mode=="solo" and team: raise HTTPException(400,"Leave your team before Solo queue")
            if body.mode!="solo" and (team is None or team["mode"]!=body.mode): raise HTTPException(400,"Create or join a matching Duo/Squad team first")
            tid=int(team["id"]) if team else None
            con.execute("INSERT INTO match_queue(player_id,mode,team_id,queued_at) VALUES(?,?,?,?) ON CONFLICT(player_id) DO UPDATE SET mode=excluded.mode,team_id=excluded.team_id,queued_at=excluded.queued_at",(player["id"],body.mode,tid,int(time.time())))
            con.commit()
            waiting=con.execute("SELECT COUNT(*) n FROM match_queue WHERE mode=?",(body.mode,)).fetchone()["n"]
            return {"status":"queued","mode":body.mode,"players_waiting":waiting,"max_players":50,"note":"Queue is persisted; public game-server allocation is not yet connected."}
        finally: con.close()

    @router.delete("/matchmaking/queue")
    def leave_queue(player=Depends(current_player)):
        con=connection()
        try:
            con.execute("DELETE FROM match_queue WHERE player_id=?",(player["id"],)); con.commit(); return {"ok":True}
        finally: con.close()

    @router.get("/leaderboard")
    def leaderboard(limit:int=50):
        con=connection()
        try:
            rows=con.execute("SELECT p.public_id,p.display_name,s.rating,s.wins,s.kills,s.matches FROM player_stats s JOIN player_profiles p ON p.player_id=s.player_id ORDER BY s.rating DESC,s.wins DESC,s.kills DESC LIMIT ?",(max(1,min(limit,100)),)).fetchall()
            return {"leaderboard":[dict(x) for x in rows]}
        finally: con.close()

    @router.get("/inventory")
    def inventory(player=Depends(current_player)):
        con=connection()
        try:
            ensure_player(con,player)
            rows=con.execute("SELECT c.skin_id,c.name,c.weapon,c.rarity,CASE WHEN e.skin_id IS NULL THEN 0 ELSE 1 END AS equipped FROM player_inventory i JOIN skin_catalog c ON c.skin_id=i.skin_id LEFT JOIN equipped_skins e ON e.player_id=i.player_id AND e.skin_id=i.skin_id WHERE i.player_id=? ORDER BY c.weapon,c.name",(player["id"],)).fetchall()
            return {"inventory":[dict(x) for x in rows]}
        finally: con.close()

    @router.post("/inventory/equip")
    def equip_skin(body:EquipSkin,player=Depends(current_player)):
        con=connection()
        try:
            row=con.execute("SELECT c.weapon FROM player_inventory i JOIN skin_catalog c ON c.skin_id=i.skin_id WHERE i.player_id=? AND i.skin_id=?",(player["id"],body.skin_id)).fetchone()
            if row is None: raise HTTPException(404,"Skin is not in your inventory")
            con.execute("INSERT INTO equipped_skins(player_id,weapon,skin_id) VALUES(?,?,?) ON CONFLICT(player_id,weapon) DO UPDATE SET skin_id=excluded.skin_id",(player["id"],row["weapon"],body.skin_id))
            con.commit(); return {"ok":True,"equipped":body.skin_id,"weapon":row["weapon"]}
        finally: con.close()

    @router.post("/internal/match-result")
    def record_match_result(body:MatchResult,x_zorix_server_secret:Optional[str]=Header(default=None)):
        if not SERVER_SECRET or not x_zorix_server_secret or not secrets.compare_digest(SERVER_SECRET,x_zorix_server_secret):
            raise HTTPException(403,"Authoritative game server only")
        con=connection()
        try:
            con.execute("INSERT OR IGNORE INTO player_stats(player_id) VALUES(?)",(body.player_id,))
            delta=max(0,100-body.placement*2)+body.kills*5-25
            con.execute("UPDATE player_stats SET rating=MAX(0,rating+?),wins=wins+?,kills=kills+?,matches=matches+1 WHERE player_id=?",(delta,1 if body.placement==1 else 0,body.kills,body.player_id))
            con.commit(); return {"ok":True,"rating_delta":delta}
        finally: con.close()

    app.include_router(router)
