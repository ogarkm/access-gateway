from fastapi import FastAPI, Query, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone
from pathlib import Path
import os
import secrets
import threading
import json

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
INDEX_FILE = STATIC_DIR / "index.html"
SITES_FILE = STATIC_DIR / "sites.json"

ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]

active_code: str | None = None
expires_at: datetime | None = None
lock = threading.Lock()


class ValidateBody(BaseModel):
    code: str


app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/")
def serve_index():
    return FileResponse(INDEX_FILE)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/sites")
def sites():
    """Return the current launchpad registry."""
    with SITES_FILE.open("r", encoding="utf-8") as f:
        return json.load(f)


@app.get("/retrieve/authToken")
def retrieve_auth_token(_ : str = Query(...)):
    global active_code, expires_at

    if _ != ADMIN_PASSWORD:
        raise HTTPException(status_code=403, detail="Unauthorized")

    with lock:
        active_code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=2)

    return {
        "code": active_code,
        "expires_in_seconds": 120,
    }


@app.get("/auth/status")
def auth_status():
    global active_code, expires_at

    with lock:
        if not active_code or not expires_at:
            active_code = None
            expires_at = None
            return {"active": False}

        if datetime.now(timezone.utc) >= expires_at:
            active_code = None
            expires_at = None
            return {"active": False}

        return {"active": True, "expires_at": expires_at.isoformat()}


@app.post("/auth/validate")
def validate(body: ValidateBody):
    global active_code, expires_at

    with lock:
        if not active_code or not expires_at:
            active_code = None
            expires_at = None
            raise HTTPException(status_code=401, detail="No active code")

        if datetime.now(timezone.utc) >= expires_at:
            active_code = None
            expires_at = None
            raise HTTPException(status_code=401, detail="Code expired")

        if body.code.strip() != active_code:
            raise HTTPException(status_code=401, detail="Invalid code")

        active_code = None
        expires_at = None

    return JSONResponse({
        "success": True,
        "authorized": True,
    })
