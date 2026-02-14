# WineBot Agent Map

This document is a navigation aid for autonomous agents working on the WineBot codebase.

## 1. System Architecture

WineBot is a containerized Windows application runtime (Wine 10.0) with an X11 display stack, controlled via a Python FastAPI.

### Core Layers
| Layer | Components | Description |
| :--- | :--- | :--- |
| **Control** | `api/` | FastAPI server, Input Broker, Policy enforcement. |
| **Orchestration** | `docker/entrypoint.sh` | Startup sequence, Xvfb/Openbox launch, Supervisor loop. |
| **Automation** | `automation/` | Python/AHK scripts for recording, tracing, and interacting with Wine. |
| **Tools** | `scripts/` | Shell helpers for local management (`winebotctl`) and diagnostics. |

## 2. Key File Map

| Path | Purpose | Key Symbols |
| :--- | :--- | :--- |
| `api/server.py` | Main API entrypoint. Mounts routers. | `app`, `lifespan` |
| `api/core/broker.py` | Input Control Policy state machine. | `InputBroker`, `ControlMode` |
| `api/routers/*.py` | API endpoints by category. | `/health`, `/input`, `/recording` |
| `docker/entrypoint.sh` | Container boot logic. Handles Xvfb, Openbox, Wine init. | `Xvfb`, `wineserver`, `tint2` |
| `docker/openbox/rc.xml` | Window Manager config. Controls input focus/decorations. | `<applications>`, `<mouse>` |
| `scripts/bin/` | Primary user-facing tools (`winebotctl`, `run-app.sh`). | |
| `scripts/diagnostics/` | System validation suite (`diagnose-master.sh`, `health-check.sh`). | `Environment Health` |
| `scripts/setup/` | Installation and fix logic (`install-theme.sh`, `fix-wine-input.sh`). | |
| `automation/bin/` | Standalone automation tools (`x11.sh`, `screenshot.sh`). | |
| `automation/examples/` | Demo and verification scripts (`notepad_create_and_verify.py`). | |
| `tests/` | Pytest suite. | `test_policy.py`, `test_api.py` |
| `archive/status/` | Archived project status reports. | |

## 3. Environment Variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `WINEBOT_RECORD` | `0` | Enable session recording (ffmpeg). |
| `WINEBOT_INPUT_TRACE` | `0` | Enable X11 input event logging. |
| `WINEBOT_INPUT_TRACE_WINDOWS` | `0` | Enable Windows-side (AHK) input logging. |
| `WINEBOT_INPUT_TRACE_NETWORK` | `0` | Enable VNC proxy logging. |
| `API_TOKEN` | (None) | Secure API access key. |
| `VNC_PASSWORD` | (None) | Password for x11vnc. |
| `SCREEN` | `1280x720x24` | Xvfb display resolution. |

## 4. Common Tasks

### How to run tests?
```bash
# Unit tests
docker compose -f compose/docker-compose.yml run --rm winebot bash -lc 'PYTHONPATH=/ pytest /tests'

# Full diagnostic suite (Smoke + CV + Trace)
docker compose -f compose/docker-compose.yml run --rm winebot /scripts/diagnostics/diagnose-master.sh
```

### How to apply config changes?
```bash
# 1. Edit config
scripts/winebotctl config set KEY VALUE

# 2. Apply (Restarts container)
scripts/winebotctl config apply
```

### How to debug input issues?
1. Enable traces: `WINEBOT_INPUT_TRACE=1` etc.
2. Check `logs/input_events_*.jsonl` in session dir.
3. Run `scripts/diagnose-input-suite.sh` inside container.
