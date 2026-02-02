from fastapi import FastAPI, HTTPException, BackgroundTasks, Security, Depends, Request
from fastapi.security import APIKeyHeader
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import subprocess
import os
import glob
import time
import shlex
import shutil
import platform
import uuid
import json

app = FastAPI(title="WineBot API", description="Internal API for controlling WineBot")
START_TIME = time.time()
UI_DIR = os.path.join(os.path.dirname(__file__), "ui")
UI_INDEX = os.path.join(UI_DIR, "index.html")
NOVNC_CORE_DIR = "/usr/share/novnc/core"

if os.path.isdir(NOVNC_CORE_DIR):
    app.mount("/ui/core", StaticFiles(directory=NOVNC_CORE_DIR), name="novnc-core")

# Security
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_token(request: Request, api_key: str = Security(api_key_header)):
    if request.url.path.startswith("/ui"):
        return api_key
    expected_token = os.getenv("API_TOKEN")
    if expected_token:
        if not api_key or api_key != expected_token:
            raise HTTPException(status_code=403, detail="Invalid or missing API Token")
    return api_key

# Apply security globally
app.router.dependencies.append(Depends(verify_token))

# Path Safety
ALLOWED_PREFIXES = ["/apps", "/wineprefix", "/tmp"]

def validate_path(path: str):
    """Ensure path is within allowed directories to prevent traversal."""
    resolved = os.path.abspath(path)
    if not any(resolved.startswith(p) for p in ALLOWED_PREFIXES):
         raise HTTPException(status_code=400, detail=f"Path not allowed. Must start with: {ALLOWED_PREFIXES}")
    return resolved

# Models
class ClickModel(BaseModel):
    x: int
    y: int

class AHKModel(BaseModel):
    script: str
    focus_title: Optional[str] = None

class AutoItModel(BaseModel):
    script: str
    focus_title: Optional[str] = None

class PythonScriptModel(BaseModel):
    script: str

class AppRunModel(BaseModel):
    path: str
    args: Optional[str] = ""
    detach: bool = False

class WinedbgRunModel(BaseModel):
    path: str
    args: Optional[str] = ""
    detach: bool = False
    mode: Optional[str] = "gdb"
    port: Optional[int] = None
    no_start: bool = False
    command: Optional[str] = None
    script: Optional[str] = None

class InspectWindowModel(BaseModel):
    title: Optional[str] = None
    text: Optional[str] = ""
    handle: Optional[str] = None
    include_controls: bool = True
    max_controls: int = 200
    list_only: bool = False
    include_empty: bool = False

class FocusModel(BaseModel):
    window_id: str

# Helpers
def run_command(cmd: List[str]):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Command failed: {e.stderr}")

def safe_command(cmd: List[str], timeout: int = 5) -> Dict[str, Any]:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        return {"ok": True, "stdout": result.stdout.strip(), "stderr": result.stderr.strip()}
    except FileNotFoundError:
        return {"ok": False, "error": "command not found"}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout"}
    except subprocess.CalledProcessError as e:
        return {"ok": False, "exit_code": e.returncode, "stdout": e.stdout.strip(), "stderr": e.stderr.strip()}

def check_binary(name: str) -> Dict[str, Any]:
    path = shutil.which(name)
    return {"present": path is not None, "path": path}

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

def meminfo_summary() -> Dict[str, Any]:
    data: Dict[str, Any] = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    data["mem_total_kb"] = int(line.split()[1])
                elif line.startswith("MemAvailable:"):
                    data["mem_available_kb"] = int(line.split()[1])
    except Exception:
        pass
    return data

@app.get("/health")
def health_check():
    """High-level health summary."""
    x11 = safe_command(["xdpyinfo"])
    wineprefix = os.getenv("WINEPREFIX", "/wineprefix")
    prefix_ok = os.path.isdir(wineprefix) and os.path.exists(os.path.join(wineprefix, "system.reg"))

    required_tools = ["winedbg", "gdb", "ffmpeg", "xdotool", "wmctrl", "xdpyinfo", "Xvfb"]
    missing = [t for t in required_tools if not check_binary(t)["present"]]

    storage_paths = ["/wineprefix", "/artifacts", "/tmp"]
    storage = [statvfs_info(p) for p in storage_paths]
    storage_ok = all(s.get("ok") and s.get("writable", False) for s in storage)

    status = "ok"
    if not x11.get("ok") or not prefix_ok or missing or not storage_ok:
        status = "degraded"

    return {
        "status": status,
        "x11": "connected" if x11.get("ok") else "unavailable",
        "wineprefix": "ready" if prefix_ok else "missing",
        "tools_ok": len(missing) == 0,
        "missing_tools": missing,
        "storage_ok": storage_ok,
        "uptime_seconds": int(time.time() - START_TIME),
    }

@app.get("/health/system")
def health_system():
    """System-level health details."""
    info = {
        "hostname": platform.node(),
        "pid": os.getpid(),
        "uptime_seconds": int(time.time() - START_TIME),
        "cpu_count": os.cpu_count(),
    }
    try:
        info["loadavg"] = os.getloadavg()
    except OSError:
        pass
    info.update(meminfo_summary())
    return info

@app.get("/health/x11")
def health_x11():
    """X11 health details."""
    x11 = safe_command(["xdpyinfo"])
    wm = safe_command(["pgrep", "-x", "openbox"])
    active = safe_command(["/automation/x11.sh", "active-window"])
    return {
        "display": os.getenv("DISPLAY"),
        "screen": os.getenv("SCREEN"),
        "connected": x11.get("ok", False),
        "xdpyinfo_error": x11.get("error") or x11.get("stderr"),
        "window_manager": {"name": "openbox", "running": wm.get("ok", False)},
        "active_window": active.get("stdout") if active.get("ok") else None,
        "active_window_error": None if active.get("ok") else (active.get("error") or active.get("stderr")),
    }

@app.get("/health/windows")
def health_windows():
    """Window list and active window details."""
    listing = safe_command(["/automation/x11.sh", "list-windows"])
    active = safe_command(["/automation/x11.sh", "active-window"])
    windows = []
    if listing.get("ok") and listing.get("stdout"):
        for line in listing["stdout"].splitlines():
            parts = line.strip().split(" ", 1)
            if len(parts) == 2:
                windows.append({"id": parts[0], "title": parts[1]})
    return {
        "count": len(windows),
        "windows": windows,
        "active_window": active.get("stdout") if active.get("ok") else None,
        "error": None if listing.get("ok") else (listing.get("error") or listing.get("stderr")),
    }

@app.get("/health/wine")
def health_wine():
    """Wine prefix and binary details."""
    wineprefix = os.getenv("WINEPREFIX", "/wineprefix")
    prefix_exists = os.path.isdir(wineprefix)
    system_reg = os.path.join(wineprefix, "system.reg")
    system_reg_exists = os.path.exists(system_reg)
    owner_uid = None
    try:
        owner_uid = os.stat(wineprefix).st_uid
    except Exception:
        pass
    wine_version = safe_command(["wine", "--version"])
    return {
        "wineprefix": wineprefix,
        "prefix_exists": prefix_exists,
        "system_reg_exists": system_reg_exists,
        "prefix_owner_uid": owner_uid,
        "current_uid": os.getuid(),
        "wine_version": wine_version.get("stdout") if wine_version.get("ok") else None,
        "wine_version_error": None if wine_version.get("ok") else (wine_version.get("error") or wine_version.get("stderr")),
        "winearch": os.getenv("WINEARCH"),
    }

@app.get("/health/tools")
def health_tools():
    """Presence and paths of key tooling."""
    tools = ["winedbg", "gdb", "ffmpeg", "xdotool", "wmctrl", "xdpyinfo", "Xvfb", "x11vnc", "websockify"]
    details = {name: check_binary(name) for name in tools}
    missing = [name for name, info in details.items() if not info["present"]]
    return {"ok": len(missing) == 0, "missing": missing, "tools": details}

@app.get("/health/storage")
def health_storage():
    """Disk space and writeability for key paths."""
    paths = ["/wineprefix", "/artifacts", "/tmp"]
    details = [statvfs_info(p) for p in paths]
    ok = all(d.get("ok") and d.get("writable", False) for d in details)
    return {"ok": ok, "paths": details}

@app.get("/health/recording")
def health_recording():
    """Recorder status and current session."""
    session_file = "/tmp/winebot_current_session"
    session_dir = None
    if os.path.exists(session_file):
        try:
            with open(session_file, "r") as f:
                session_dir = f.read().strip()
        except Exception:
            session_dir = None
    recorder = safe_command(["pgrep", "-f", "automation.recorder start"])
    return {
        "enabled": os.getenv("WINEBOT_RECORD", "0") == "1",
        "session_dir": session_dir,
        "session_dir_exists": os.path.isdir(session_dir) if session_dir else False,
        "recorder_running": recorder.get("ok", False),
        "recorder_pids": recorder.get("stdout").splitlines() if recorder.get("ok") and recorder.get("stdout") else [],
    }

@app.get("/ui")
@app.get("/ui/")
def dashboard():
    """Serve the dashboard UI."""
    if not os.path.exists(UI_INDEX):
        raise HTTPException(status_code=404, detail="Dashboard not available")
    return FileResponse(UI_INDEX, media_type="text/html")

@app.get("/windows")
def list_windows():
    """List visible windows."""
    try:
        output = run_command(["/automation/x11.sh", "list-windows"])
        windows = []
        if output:
            for line in output.split("\n"):
                parts = line.strip().split(" ", 1)
                if len(parts) == 2:
                    windows.append({"id": parts[0], "title": parts[1]})
        return {"windows": windows}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/windows/active")
def get_active_window():
    """Get the active window ID."""
    output = run_command(["/automation/x11.sh", "active-window"])
    return {"id": output}

@app.get("/windows/search")
def search_windows(name: str):
    """Search for windows by name pattern."""
    try:
        output = run_command(["/automation/x11.sh", "search", "--name", name])
        ids = output.splitlines() if output else []
        return {"matches": ids}
    except Exception:
        # Search might fail if no windows found? xdotool usually just returns empty
        return {"matches": []}

@app.post("/windows/focus")
def focus_window(data: FocusModel):
    """Focus a window by ID."""
    run_command(["/automation/x11.sh", "focus", data.window_id])
    return {"status": "focused", "id": data.window_id}

@app.get("/apps")
def list_apps(pattern: Optional[str] = None):
    """List installed applications in the Wine prefix."""
    cmd = ["/scripts/list-installed-apps.sh"]
    if pattern:
        cmd.extend(["--pattern", pattern])
    
    try:
        output = run_command(cmd)
        apps = output.splitlines() if output else []
        return {"apps": apps}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/apps/run")
def run_app(data: AppRunModel):
    """Run a Windows application."""
    safe_path = validate_path(data.path)
    
    cmd = ["/scripts/run-app.sh", safe_path]
    if data.detach:
        cmd.append("--detach")
    
    if data.args:
        cmd.extend(["--args", data.args])

    run_command(cmd)
    return {"status": "launched", "path": safe_path}

@app.post("/run/winedbg")
def run_winedbg(data: WinedbgRunModel):
    """Run a Windows application under winedbg."""
    safe_path = validate_path(data.path)

    mode = data.mode or "gdb"
    if mode not in ("gdb", "default"):
        raise HTTPException(status_code=400, detail="Invalid winedbg mode (expected 'gdb' or 'default').")
    if data.command and data.script:
        raise HTTPException(status_code=400, detail="Provide either 'command' or 'script', not both.")
    if (data.command or data.script) and mode != "default":
        raise HTTPException(status_code=400, detail="winedbg command/script requires mode 'default'.")
    if data.port is not None and data.port < 0:
        raise HTTPException(status_code=400, detail="winedbg port must be >= 0.")

    if shutil.which("winedbg"):
        cmd = ["winedbg"]
        if mode == "gdb":
            cmd.append("--gdb")
        if data.port is not None:
            cmd.extend(["--port", str(data.port)])
        if data.no_start:
            cmd.append("--no-start")
        if data.command:
            cmd.extend(["--command", data.command])
        if data.script:
            raise HTTPException(status_code=400, detail="winedbg script files are not supported in direct mode; use command instead.")
        cmd.append(safe_path)
        if data.args:
            cmd.extend(shlex.split(data.args))
        if data.detach:
            subprocess.Popen(cmd)
            return {"status": "launched", "path": safe_path, "mode": mode, "detached": True}
        run_command(cmd)
        return {"status": "launched", "path": safe_path, "mode": mode}

    cmd = ["/scripts/run-app.sh", safe_path, "--winedbg", "--winedbg-mode", mode]
    if data.detach:
        cmd.append("--detach")
    if data.args:
        cmd.extend(["--args", data.args])
    if data.port is not None:
        cmd.extend(["--winedbg-port", str(data.port)])
    if data.no_start:
        cmd.append("--winedbg-no-start")
    if data.command:
        cmd.extend(["--winedbg-command", data.command])
    if data.script:
        cmd.extend(["--winedbg-script", data.script])

    run_command(cmd)
    return {"status": "launched", "path": safe_path, "mode": mode}

@app.post("/run/python")
def run_python(data: PythonScriptModel):
    """Run a script using Windows Python (winpy)."""
    script_path = f"/tmp/api_script_{int(time.time())}.py"
    
    with open(script_path, "w") as f:
        f.write(data.script)
    
    # Run using winpy wrapper
    cmd = ["winpy", script_path]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {"status": "success", "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "exit_code": e.returncode, "stdout": e.stdout, "stderr": e.stderr}

@app.get("/screenshot")
def get_screenshot(window_id: str = "root", delay: int = 0, label: Optional[str] = None, tag: Optional[str] = None):
    """Take a screenshot and return the image."""
    request_id = uuid.uuid4().hex
    filename = f"screenshot_{int(time.time())}.png"
    filepath = os.path.join("/tmp", filename)
    
    cmd = ["/automation/screenshot.sh", "--window", window_id, "--delay", str(delay)]
    if label:
        cmd.extend(["--label", label])
    cmd.extend(["--request-id", request_id])
    if tag:
        cmd.extend(["--tag", tag])
    cmd.append(filepath)
    
    run_command(cmd)
    
    if not os.path.exists(filepath):
        raise HTTPException(status_code=500, detail="Screenshot failed to generate")

    return FileResponse(filepath, media_type="image/png", headers={"X-Request-Id": request_id})

@app.post("/input/mouse/click")
def click_at(data: ClickModel):
    """Click at coordinates (x, y)."""
    run_command(["/automation/x11.sh", "click-at", str(data.x), str(data.y)])
    return {"status": "clicked", "x": data.x, "y": data.y}

@app.post("/run/ahk")
def run_ahk(data: AHKModel):
    """Run an AutoHotkey script."""
    # Write script to temp file
    script_path = f"/tmp/api_script_{int(time.time())}.ahk"
    log_path = f"{script_path}.log"
    
    with open(script_path, "w") as f:
        f.write(data.script)
        
    cmd = ["/scripts/run-ahk.sh", script_path, "--log", log_path]
    if data.focus_title:
        cmd.extend(["--focus-title", data.focus_title])
        
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        # Read log
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                log_content = f.read()
        return {"status": "success", "log": log_content}
    except subprocess.CalledProcessError as e:
        # Read log even on failure
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                log_content = f.read()
        return {"status": "error", "exit_code": e.returncode, "stderr": e.stderr, "log": log_content}

@app.post("/run/autoit")
def run_autoit(data: AutoItModel):
    """Run an AutoIt script."""
    # Write script to temp file
    script_path = f"/tmp/api_script_{int(time.time())}.au3"
    log_path = f"{script_path}.log"
    
    with open(script_path, "w") as f:
        f.write(data.script)
        
    cmd = ["/scripts/run-autoit.sh", script_path, "--log", log_path]
    if data.focus_title:
        cmd.extend(["--focus-title", data.focus_title])
        
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        # Read log
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                log_content = f.read()
        return {"status": "success", "log": log_content}
    except subprocess.CalledProcessError as e:
        # Read log even on failure
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                log_content = f.read()
        return {"status": "error", "exit_code": e.returncode, "stderr": e.stderr, "log": log_content}

@app.post("/inspect/window")
def inspect_window(data: InspectWindowModel):
    """Inspect a Windows window and its controls (WinSpy-style)."""
    if not data.list_only and not data.title and not data.handle:
        raise HTTPException(status_code=400, detail="Provide 'title' or 'handle', or set list_only=true.")

    script_path = "/automation/inspect_window.au3"
    log_path = f"/tmp/api_inspect_{int(time.time())}.log"

    cmd = ["/scripts/run-autoit.sh", script_path, "--log", log_path]
    if data.list_only:
        cmd.append("--list")
    if data.include_empty:
        cmd.append("--include-empty")
    if data.title:
        cmd.extend(["--title", data.title])
    if data.text:
        cmd.extend(["--text", data.text])
    if data.handle:
        cmd.extend(["--handle", data.handle])
    if not data.include_controls:
        cmd.append("--no-controls")
    if data.max_controls is not None:
        cmd.extend(["--max-controls", str(data.max_controls)])

    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        log_content = ""
        if os.path.exists(log_path):
            with open(log_path, "r") as f:
                log_content = f.read()
        return {"status": "error", "exit_code": e.returncode, "stderr": e.stderr, "log": log_content}

    if not os.path.exists(log_path):
        raise HTTPException(status_code=500, detail="Inspect log not found.")

    with open(log_path, "r") as f:
        log_content = f.read().strip()
    if not log_content:
        return {"status": "error", "log": ""}

    try:
        payload = json.loads(log_content)
    except json.JSONDecodeError:
        return {"status": "error", "log": log_content}

    return {"status": "success", "result": payload}
