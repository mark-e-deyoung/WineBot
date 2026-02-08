import os
import fcntl
import json
import time
import datetime
from typing import Dict, Any, Optional

SESSION_FILE = "/tmp/winebot_current_session"
DEFAULT_SESSION_ROOT = "/artifacts/sessions"
ALLOWED_PREFIXES = ["/apps", "/wineprefix", "/tmp", "/artifacts"]

def validate_path(path: str):
    """Ensure path is within allowed directories to prevent traversal."""
    resolved = os.path.abspath(path)
    if not any(resolved.startswith(p) for p in ALLOWED_PREFIXES):
         raise Exception(f"Path not allowed. Must start with: {ALLOWED_PREFIXES}")
    return resolved

def statvfs_info(path: str) -> Dict[str, Any]:
    try:
        st = os.statvfs(path)
        return {
            "path": path,
            "ok": True,
            "total_bytes": st.f_frsize * st.f_blocks,
            "free_bytes": st.f_frsize * st.f_bfree,
            "avail_bytes": st.f_frsize * st.f_bavail,
            "writable": os.access(path, os.W_OK),
        }
    except FileNotFoundError:
        return {"path": path, "ok": False, "error": "not found"}

def read_pid(path: str) -> Optional[int]:
    try:
        with open(path, "r") as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None

def pid_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True

def read_session_dir() -> Optional[str]:
    if not os.path.exists(SESSION_FILE):
        return None
    try:
        with open(SESSION_FILE, "r") as f:
            value = f.read().strip()
        return value or None
    except Exception:
        return None

def session_id_from_dir(session_dir: Optional[str]) -> Optional[str]:
    if not session_dir:
        return None
    return os.path.basename(session_dir)

def lifecycle_log_path(session_dir: str) -> str:
    return os.path.join(session_dir, "logs", "lifecycle.jsonl")

def append_lifecycle_event(
    session_dir: Optional[str],
    kind: str,
    message: str,
    source: str = "api",
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    if not session_dir:
        return
    event = {
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "timestamp_epoch_ms": int(time.time() * 1000),
        "session_id": session_id_from_dir(session_dir),
        "kind": kind,
        "message": message,
        "source": source,
    }
    if extra:
        event["extra"] = extra
    try:
        os.makedirs(os.path.join(session_dir, "logs"), exist_ok=True)
        with open(lifecycle_log_path(session_dir), "a") as f:
            f.write(json.dumps(event) + "
")
    except Exception:
        pass

def input_trace_log_path(session_dir: str) -> str:
    return os.path.join(session_dir, "logs", "input_events.jsonl")

def append_trace_event(path: str, payload: Dict[str, Any]) -> None:
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as f:
            try:
                fcntl.flock(f, fcntl.LOCK_EX)
            except Exception:
                pass
            f.write(json.dumps(payload) + "
")
            f.flush()
            try:
                fcntl.flock(f, fcntl.LOCK_UN)
            except Exception:
                pass
    except Exception:
        pass

def append_input_event(session_dir: Optional[str], event: Dict[str, Any]) -> None:
    if not session_dir:
        return
    payload = dict(event)
    payload.setdefault("timestamp_utc", datetime.datetime.now(datetime.timezone.utc).isoformat())
    payload.setdefault("timestamp_epoch_ms", int(time.time() * 1000))
    payload.setdefault("session_id", session_id_from_dir(session_dir))
    append_trace_event(input_trace_log_path(session_dir), payload)

def read_file_tail(path: str, max_bytes: int = 4096) -> str:
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            if size <= max_bytes:
                f.seek(0)
            else:
                f.seek(size - max_bytes)
            data = f.read()
        try:
            return data.decode("utf-8", errors="replace")
        except Exception:
            return data.decode(errors="replace")
    except Exception:
        return ""

def truncate_text(value: Optional[str], limit: int = 4000) -> str:
    if not value:
        return ""
    if len(value) <= limit:
        return value
    suffix = f"
...[truncated {len(value) - limit} chars]"
    return value[:limit] + suffix
