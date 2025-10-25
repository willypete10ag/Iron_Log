import os
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Literal, Dict, Any

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import bcrypt
from fastapi.middleware.cors import CORSMiddleware

# ---------------------------
# DB helpers
# ---------------------------

DB_PATH = os.path.join(os.path.dirname(__file__), "db", "ironlog.sqlite")
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

def utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def get_conn() -> sqlite3.Connection:
    """
    Returns a SQLite connection that:
    - waits up to 5s if the DB is locked
    - uses WAL journaling for better concurrent read/write
    - returns rows as dict-like objects
    """
    conn = sqlite3.connect(DB_PATH, timeout=5.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    # improve concurrency
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")  # ms
    return conn

def init_db():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS tokens (
        token TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)
    # Lift data keyed by (user_id, name)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS lifts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        notes TEXT DEFAULT '',
        last_updated TEXT NOT NULL,
        strength_weight INTEGER DEFAULT 0,
        strength_reps INTEGER DEFAULT 0,
        endurance_weight INTEGER DEFAULT 0,
        endurance_reps INTEGER DEFAULT 0,
        UNIQUE(user_id, name),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)
    # PR records keyed by (user_id, lift_name, date)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS pr_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        lift_name TEXT NOT NULL,
        date TEXT NOT NULL,
        strength_weight INTEGER DEFAULT 0,
        strength_reps INTEGER DEFAULT 0,
        endurance_weight INTEGER DEFAULT 0,
        endurance_reps INTEGER DEFAULT 0,
        notes TEXT DEFAULT '',
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, lift_name, date),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    """)
    # Hard-delete log so other devices learn about deletes
    cur.execute("""
    CREATE TABLE IF NOT EXISTS deletion_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL, -- 'lifts' or 'pr_records'
        entity_key TEXT NOT NULL, -- for lifts: name ; for pr_records: lift_name|date
        user_id TEXT NOT NULL,
        deleted_at TEXT NOT NULL
    );
    """)
    conn.commit()
    conn.close()

# ---------------------------
# FastAPI init + CORS
# ---------------------------

init_db()
app = FastAPI(title=os.getenv("APP_NAME", "ironlog-backend"))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],           # ✅ you fixed this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# Models
# ---------------------------

class StrengthEnduranceSet(BaseModel):
    weight: int = 0
    reps: int = 0

class PRRecordIn(BaseModel):
    lift_name: str
    date: str  # ISO
    strengthPR: StrengthEnduranceSet = Field(default_factory=StrengthEnduranceSet)
    endurancePR: StrengthEnduranceSet = Field(default_factory=StrengthEnduranceSet)
    notes: str = ""
    # 'date' is identity; updated_at is last-write-wins timestamp
    updated_at: Optional[str] = None

class LiftIn(BaseModel):
    name: str
    notes: str = ""
    last_updated: Optional[str] = None
    strengthPR: StrengthEnduranceSet = Field(default_factory=StrengthEnduranceSet)
    endurancePR: StrengthEnduranceSet = Field(default_factory=StrengthEnduranceSet)
    pr_history: List[PRRecordIn] = Field(default_factory=list)

class DeletedItem(BaseModel):
    kind: Literal["lift", "pr"]
    lift_name: str
    date: Optional[str] = None  # required if kind == 'pr'
    deleted_at: Optional[str] = None

class SyncPush(BaseModel):
    lifts: List[LiftIn] = Field(default_factory=list)
    pr_records: List[PRRecordIn] = Field(default_factory=list)
    deleted: List[DeletedItem] = Field(default_factory=list)

class SyncPull(BaseModel):
    lifts: List[Dict[str, Any]]
    pr_records: List[Dict[str, Any]]
    deleted: List[Dict[str, Any]]
    server_time: str

class RegisterBody(BaseModel):
    username: str
    password: str

class LoginBody(BaseModel):
    username: str
    password: str

# ---------------------------
# Auth helpers
# ---------------------------

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode()

def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False

def make_token() -> str:
    return uuid.uuid4().hex + uuid.uuid4().hex  # 64 hex chars

def auth_user(authorization: Optional[str] = Header(None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split(" ", 1)[1].strip()

    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("SELECT user_id FROM tokens WHERE token = ?", (token,))
        row = cur.fetchone()
    finally:
        conn.close()

    if not row:
        raise HTTPException(status_code=401, detail="Invalid token")
    return row["user_id"]

# ---------------------------
# Routes
# ---------------------------

@app.get("/health")
def health():
    return {"status": "ok", "time": utcnow_iso()}

@app.post("/auth/register")
def register(body: RegisterBody):
    username = body.username.strip()
    password = body.password.strip()
    if not username or not password:
        raise HTTPException(status_code=400, detail="Username and password required")

    # stable per username (so same username on diff device → same account)
    user_id = uuid.uuid5(uuid.NAMESPACE_DNS, username.lower()).hex
    now = utcnow_iso()

    conn = get_conn()
    try:
        cur = conn.cursor()
        try:
            # Create user
            cur.execute(
                "INSERT INTO users (id, username, password_hash, created_at, updated_at) VALUES (?,?,?,?,?)",
                (user_id, username, hash_password(password), now, now),
            )
        except sqlite3.IntegrityError:
            # Username already exists
            return JSONResponse(
                status_code=409,
                content={"error": "Username already exists"},
            )

        # Issue token
        token = make_token()
        cur.execute(
            "INSERT INTO tokens (token, user_id, created_at) VALUES (?,?,?)",
            (token, user_id, now),
        )

        conn.commit()
        return {
            "access_token": token,
            "user_id": user_id,
            "username": username,
        }

    except sqlite3.OperationalError as e:
        # This is where we used to crash with "database is locked"
        # Return 503 to tell the client "server busy, try again"
        return JSONResponse(
            status_code=503,
            content={"error": "Database busy, please retry", "detail": str(e)},
        )
    finally:
        conn.close()

@app.post("/auth/login")
def login(body: LoginBody):
    username = body.username.strip()
    password = body.password.strip()

    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, password_hash FROM users WHERE username = ?",
            (username,),
        )
        row = cur.fetchone()

        if not row or not verify_password(password, row["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        user_id = row["id"]
        token = make_token()
        cur.execute(
            "INSERT INTO tokens (token, user_id, created_at) VALUES (?,?,?)",
            (token, user_id, utcnow_iso()),
        )
        conn.commit()

        return {
            "access_token": token,
            "user_id": user_id,
            "username": username,
        }
    finally:
        conn.close()

@app.get("/me")
def me(user_id: str = Depends(auth_user)):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, username, created_at, updated_at FROM users WHERE id = ?",
            (user_id,),
        )
        row = cur.fetchone()
        return dict(row) if row else {}
    finally:
        conn.close()

# ---------------------------
# Sync helpers
# ---------------------------

def upsert_pr(cur: sqlite3.Cursor, user_id: str, pr: PRRecordIn):
    # identity is (user_id, lift_name, date)
    updated_at = pr.updated_at or pr.date
    cur.execute(
        "SELECT id, updated_at FROM pr_records WHERE user_id=? AND lift_name=? AND date=?",
        (user_id, pr.lift_name, pr.date),
    )
    row = cur.fetchone()
    if row:
        if row["updated_at"] <= updated_at:
            cur.execute(
                """
                UPDATE pr_records
                SET strength_weight=?,
                    strength_reps=?,
                    endurance_weight=?,
                    endurance_reps=?,
                    notes=?,
                    updated_at=?
                WHERE id=?
                """,
                (
                    pr.strengthPR.weight,
                    pr.strengthPR.reps,
                    pr.endurancePR.weight,
                    pr.endurancePR.reps,
                    pr.notes,
                    updated_at,
                    row["id"],
                ),
            )
    else:
        cur.execute(
            """
            INSERT INTO pr_records (
                id,
                user_id,
                lift_name,
                date,
                strength_weight,
                strength_reps,
                endurance_weight,
                endurance_reps,
                notes,
                updated_at
            )
            VALUES (?,?,?,?,?,?,?,?,?,?)
            """,
            (
                uuid.uuid4().hex,
                user_id,
                pr.lift_name,
                pr.date,
                pr.strengthPR.weight,
                pr.strengthPR.reps,
                pr.endurancePR.weight,
                pr.endurancePR.reps,
                pr.notes,
                updated_at,
            ),
        )

# ---------------------------
# Sync routes
# ---------------------------

@app.get("/sync")
def sync_pull(since: Optional[str] = None, user_id: str = Depends(auth_user)):
    conn = get_conn()
    try:
        cur = conn.cursor()

        # lifts
        if since:
            cur.execute(
                """
                SELECT id, name, notes, last_updated,
                       strength_weight, strength_reps,
                       endurance_weight, endurance_reps
                FROM lifts
                WHERE user_id = ? AND last_updated >= ?
                """,
                (user_id, since),
            )
        else:
            cur.execute(
                """
                SELECT id, name, notes, last_updated,
                       strength_weight, strength_reps,
                       endurance_weight, endurance_reps
                FROM lifts
                WHERE user_id = ?
                """,
                (user_id,),
            )
        lifts = [dict(r) for r in cur.fetchall()]

        # pr_records
        if since:
            cur.execute(
                """
                SELECT id, lift_name, date,
                       strength_weight, strength_reps,
                       endurance_weight, endurance_reps,
                       notes, updated_at
                FROM pr_records
                WHERE user_id = ? AND updated_at >= ?
                """,
                (user_id, since),
            )
        else:
            cur.execute(
                """
                SELECT id, lift_name, date,
                       strength_weight, strength_reps,
                       endurance_weight, endurance_reps,
                       notes, updated_at
                FROM pr_records
                WHERE user_id = ?
                """,
                (user_id,),
            )
        prs = [dict(r) for r in cur.fetchall()]

        # deletion_log
        if since:
            cur.execute(
                """
                SELECT table_name, entity_key, deleted_at
                FROM deletion_log
                WHERE user_id = ? AND deleted_at >= ?
                """,
                (user_id, since),
            )
        else:
            cur.execute(
                """
                SELECT table_name, entity_key, deleted_at
                FROM deletion_log
                WHERE user_id = ?
                """,
                (user_id,),
            )
        deleted = [dict(r) for r in cur.fetchall()]

        return SyncPull(
            lifts=lifts,
            pr_records=prs,
            deleted=deleted,
            server_time=utcnow_iso(),
        )
    finally:
        conn.close()

@app.post("/sync")
def sync_push(payload: SyncPush, user_id: str = Depends(auth_user)):
    conn = get_conn()
    try:
        cur = conn.cursor()

        # Upsert lifts
        for l in payload.lifts:
            last_updated = l.last_updated or utcnow_iso()

            # check if exists
            cur.execute(
                "SELECT id, last_updated FROM lifts WHERE user_id = ? AND name = ?",
                (user_id, l.name),
            )
            row = cur.fetchone()
            if row:
                # LWW: if incoming newer, overwrite
                if row["last_updated"] <= last_updated:
                    cur.execute(
                        """
                        UPDATE lifts
                        SET notes=?,
                            last_updated=?,
                            strength_weight=?,
                            strength_reps=?,
                            endurance_weight=?,
                            endurance_reps=?
                        WHERE id=?
                        """,
                        (
                            l.notes,
                            last_updated,
                            l.strengthPR.weight,
                            l.strengthPR.reps,
                            l.endurancePR.weight,
                            l.endurancePR.reps,
                            row["id"],
                        ),
                    )
            else:
                cur.execute(
                    """
                    INSERT INTO lifts (
                        id, user_id, name, notes, last_updated,
                        strength_weight, strength_reps,
                        endurance_weight, endurance_reps
                    )
                    VALUES (?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        uuid.uuid4().hex,
                        user_id,
                        l.name,
                        l.notes,
                        last_updated,
                        l.strengthPR.weight,
                        l.strengthPR.reps,
                        l.endurancePR.weight,
                        l.endurancePR.reps,
                    ),
                )

            # Optional embedded pr_history
            for pr in (l.pr_history or []):
                upsert_pr(cur, user_id, pr)

        # Upsert standalone pr_records
        for pr in payload.pr_records:
            upsert_pr(cur, user_id, pr)

        # Process deletions
        for d in payload.deleted:
            deleted_at = d.deleted_at or utcnow_iso()
            if d.kind == "lift":
                # delete lift + its PRs
                cur.execute(
                    "DELETE FROM lifts WHERE user_id=? AND name=?",
                    (user_id, d.lift_name),
                )
                cur.execute(
                    "DELETE FROM pr_records WHERE user_id=? AND lift_name=?",
                    (user_id, d.lift_name),
                )
                # log lift delete
                cur.execute(
                    """
                    INSERT INTO deletion_log (table_name, entity_key, user_id, deleted_at)
                    VALUES (?,?,?,?)
                    """,
                    ("lifts", d.lift_name, user_id, deleted_at),
                )
            else:
                # delete specific PR
                if not d.date:
                    continue
                cur.execute(
                    "DELETE FROM pr_records WHERE user_id=? AND lift_name=? AND date=?",
                    (user_id, d.lift_name, d.date),
                )
                cur.execute(
                    """
                    INSERT INTO deletion_log (table_name, entity_key, user_id, deleted_at)
                    VALUES (?,?,?,?)
                    """,
                    ("pr_records", f"{d.lift_name}|{d.date}", user_id, deleted_at),
                )

        conn.commit()
        return {"status": "ok", "server_time": utcnow_iso()}
    finally:
        conn.close()
