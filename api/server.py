from fastapi import FastAPI, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.security import APIKeyHeader
from contextlib import asynccontextmanager
import os
import asyncio
from api.routers import health, lifecycle, input, recording, control
from api.utils.files import read_session_dir, append_lifecycle_event
from api.utils.process import process_store

NOVNC_CORE_DIR = "/usr/share/novnc/core"
NOVNC_VENDOR_DIR = "/usr/share/novnc/vendor"
SESSION_FILE = "/tmp/winebot_current_session"

def _load_version():
    try:
        with open("/VERSION", "r") as f:
            return f.read().strip()
    except Exception:
        return "v0.9.0-dev"

VERSION = _load_version()

async def resource_monitor_task():
    """Background task to reap zombies and monitor disk usage."""
    # (Simplified for now, full logic was in server.py)
    while True:
        # Reap zombie processes
        for proc in list(process_store):
            if proc.poll() is not None:
                process_store.discard(proc)
        await asyncio.sleep(5)

@asynccontextmanager
async def lifespan(app: FastAPI):
    session_dir = read_session_dir()
    append_lifecycle_event(session_dir, "api_started", "API server started", source="api")

    # Start background monitor
    monitor = asyncio.create_task(resource_monitor_task())

    try:
        yield
    finally:
        monitor.cancel()
        session_dir = read_session_dir()
        append_lifecycle_event(session_dir, "api_stopped", "API server stopping", source="api")

app = FastAPI(title="WineBot API", description="Internal API for controlling WineBot", lifespan=lifespan)

if os.path.isdir(NOVNC_CORE_DIR):
    app.mount("/ui/core", StaticFiles(directory=NOVNC_CORE_DIR), name="novnc-core")
if os.path.isdir(NOVNC_VENDOR_DIR):
    app.mount("/ui/vendor", StaticFiles(directory=NOVNC_VENDOR_DIR), name="novnc-vendor")

# Security
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_token(api_key: str = Depends(api_key_header)):
    # Simple check, real logic needs Request object to allow UI bypass
    # Ideally move verify_token to a util and use it here
    pass 

# To replicate original logic we need Request
from fastapi import Request, HTTPException

async def verify_token_logic(request: Request, api_key: str = Security(api_key_header)):
    if request.url.path.startswith("/ui"):
        return api_key
    expected_token = os.getenv("API_TOKEN")
    if expected_token:
        if not api_key or api_key != expected_token:
            raise HTTPException(status_code=403, detail="Invalid or missing API Token")
    return api_key

app.router.dependencies.append(Depends(verify_token_logic))

# Include Routers
app.include_router(health.router)
app.include_router(lifecycle.router)
app.include_router(input.router)
app.include_router(recording.router)
app.include_router(control.router)

@app.get("/version")
def get_version():
    return {"version": VERSION}

@app.get("/ui")
@app.get("/ui/")
def dashboard():
    from fastapi.responses import FileResponse
    UI_DIR = os.path.join(os.path.dirname(__file__), "ui")
    UI_INDEX = os.path.join(UI_DIR, "index.html")
    if not os.path.exists(UI_INDEX):
        raise HTTPException(status_code=404, detail="Dashboard not available")
    return FileResponse(UI_INDEX, media_type="text/html")