"""Verified ZORIX Diamond top-ups: Razorpay payment links and Google Play receipts."""
import hashlib
import hmac
import json
import os
import secrets
import time
from typing import Optional

import requests
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from pydantic import BaseModel, Field

DIAMOND_PACKAGES = {"diamonds_100": {"diamonds": 100, "amount_paise": 3000, "amount_inr": 30}}
PLAY_PRODUCT_IDS = {"diamonds_100": "zorix_diamonds_100"}


class RazorpayOrderRequest(BaseModel):
    package_id: str = Field(pattern="^diamonds_100$")


class PlayPurchaseRequest(BaseModel):
    package_id: str = Field(pattern="^diamonds_100$")
    purchase_token: str = Field(min_length=20, max_length=8192)


def install_payment_routes(app: FastAPI, db_factory, current_player):
    def ensure_wallet(con, player_id: int):
        con.execute("INSERT OR IGNORE INTO player_progression(player_id) VALUES(?)", (player_id,))
        columns = {row[1] for row in con.execute("PRAGMA table_info(player_progression)").fetchall()}
        if "diamonds" not in columns:
            con.execute("ALTER TABLE player_progression ADD COLUMN diamonds INTEGER NOT NULL DEFAULT 0")
        con.execute("""CREATE TABLE IF NOT EXISTS diamond_transactions (
            transaction_id TEXT PRIMARY KEY, player_id INTEGER NOT NULL,
            package_id TEXT NOT NULL, diamonds INTEGER NOT NULL,
            provider TEXT NOT NULL, created_at INTEGER NOT NULL
        )""")
        con.commit()

    @app.get("/api/diamonds/wallet")
    def diamond_wallet(player=Depends(current_player)):
        con = db_factory()
        try:
            ensure_wallet(con, int(player["id"]))
            row = con.execute("SELECT diamonds FROM player_progression WHERE player_id=?", (player["id"],)).fetchone()
            return {"diamonds": int(row["diamonds"]), "packages": [
                {"package_id": "diamonds_100", "diamonds": 100, "price_inr": 30}
            ]}
        finally:
            con.close()

    @app.post("/api/diamonds/razorpay/link")
    def create_razorpay_payment_link(body: RazorpayOrderRequest, player=Depends(current_player)):
        key_id = os.getenv("RAZORPAY_KEY_ID", "").strip()
        key_secret = os.getenv("RAZORPAY_KEY_SECRET", "").strip()
        if not key_id or not key_secret:
            raise HTTPException(503, "Razorpay is not configured on the server yet")
        package = DIAMOND_PACKAGES[body.package_id]
        reference_id = "zx_" + secrets.token_hex(12)
        payload = {
            "amount": package["amount_paise"], "currency": "INR",
            "accept_partial": False, "description": "ZORIX 100 Diamonds",
            "reference_id": reference_id, "expire_by": int(time.time()) + 1800,
            "notes": {"player_id": str(player["id"]), "package_id": body.package_id,
                      "diamonds": str(package["diamonds"])}
        }
        try:
            response = requests.post(
                "https://api.razorpay.com/v1/payment_links",
                auth=(key_id, key_secret), json=payload, timeout=15
            )
            response.raise_for_status()
            link = response.json()
        except requests.RequestException:
            raise HTTPException(502, "Could not create Razorpay payment link")
        return {"provider": "razorpay", "payment_link_id": link["id"],
                "short_url": link["short_url"], "amount_inr": 30,
                "diamonds": 100, "expires_in_seconds": 1800,
                "message": "Diamonds are credited only after the signed Razorpay webhook confirms payment."}

    @app.post("/api/diamonds/razorpay/webhook")
    async def razorpay_webhook(request: Request, x_razorpay_signature: Optional[str] = Header(default=None),
                               x_razorpay_event_id: Optional[str] = Header(default=None)):
        secret = os.getenv("RAZORPAY_WEBHOOK_SECRET", "").strip()
        if not secret or not x_razorpay_signature:
            raise HTTPException(401, "Webhook signature is required")
        raw = await request.body()
        expected = hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, x_razorpay_signature):
            raise HTTPException(401, "Invalid Razorpay webhook signature")
        try:
            event = json.loads(raw)
            if event.get("event") != "payment_link.paid":
                return {"ok": True, "ignored": True}
            entity = event["payload"]["payment_link"]["entity"]
            payment = event["payload"]["payment"]["entity"]
            notes = entity.get("notes") or {}
            player_id = int(notes["player_id"])
            package_id = str(notes["package_id"])
            package = DIAMOND_PACKAGES[package_id]
            if entity.get("status") != "paid" or int(entity.get("amount", 0)) != package["amount_paise"]:
                raise ValueError("amount/status mismatch")
            if int(entity.get("amount_paid", 0)) < package["amount_paise"]:
                raise ValueError("payment incomplete")
            transaction_id = str(payment.get("id") or x_razorpay_event_id or entity["id"])
        except (KeyError, TypeError, ValueError):
            raise HTTPException(400, "Invalid or incomplete payment event")

        con = db_factory()
        try:
            ensure_wallet(con, player_id)
            con.execute("BEGIN IMMEDIATE")
            inserted = con.execute(
                "INSERT OR IGNORE INTO diamond_transactions VALUES(?,?,?,?,?,?)",
                (transaction_id, player_id, package_id, package["diamonds"], "razorpay", int(time.time()))
            )
            if inserted.rowcount:
                con.execute("UPDATE player_progression SET diamonds=diamonds+? WHERE player_id=?",
                            (package["diamonds"], player_id))
            con.commit()
            return {"ok": True, "credited": bool(inserted.rowcount)}
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()

    @app.post("/api/diamonds/google-play/verify")
    def verify_google_play_purchase(body: PlayPurchaseRequest, player=Depends(current_player)):
        package = DIAMOND_PACKAGES[body.package_id]
        product_id = PLAY_PRODUCT_IDS[body.package_id]
        package_name = os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "").strip()
        service_account_json = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
        if not package_name or not service_account_json:
            raise HTTPException(503, "Google Play receipt verification is not configured")
        try:
            from google.oauth2 import service_account
            from google.auth.transport.requests import AuthorizedSession
            credentials = service_account.Credentials.from_service_account_info(
                json.loads(service_account_json),
                scopes=["https://www.googleapis.com/auth/androidpublisher"]
            )
            session = AuthorizedSession(credentials)
            url = ("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                   + package_name + "/purchases/products/" + product_id
                   + "/tokens/" + body.purchase_token)
            response = session.get(url, timeout=15)
            response.raise_for_status()
            purchase = response.json()
            if int(purchase.get("purchaseState", -1)) != 0:
                raise HTTPException(402, "Google Play purchase is not completed")
            if purchase.get("productId") not in (None, product_id):
                raise HTTPException(400, "Google Play product does not match")
            transaction_id = str(purchase.get("orderId") or hashlib.sha256(body.purchase_token.encode()).hexdigest())
            ack_url = ("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                       + package_name + "/purchases/products/" + product_id
                       + "/tokens/" + body.purchase_token + ":acknowledge")
            ack_response = session.post(ack_url, json={}, timeout=15)
            if ack_response.status_code not in (200, 204):
                ack_response.raise_for_status()
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(502, "Google Play purchase could not be verified")
        con = db_factory()
        try:
            ensure_wallet(con, int(player["id"]))
            con.execute("BEGIN IMMEDIATE")
            inserted = con.execute(
                "INSERT OR IGNORE INTO diamond_transactions VALUES(?,?,?,?,?,?)",
                (transaction_id, int(player["id"]), body.package_id, package["diamonds"], "google_play", int(time.time()))
            )
            if inserted.rowcount:
                con.execute("UPDATE player_progression SET diamonds=diamonds+? WHERE player_id=?",
                            (package["diamonds"], player["id"]))
            con.commit()
            row = con.execute("SELECT diamonds FROM player_progression WHERE player_id=?", (player["id"],)).fetchone()
            return {"ok": True, "credited": bool(inserted.rowcount), "diamonds_added": package["diamonds"],
                    "diamond_balance": int(row["diamonds"])}
        except Exception:
            con.rollback()
            raise
        finally:
            con.close()
