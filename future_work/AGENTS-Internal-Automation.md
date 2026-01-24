# AGENTS-Internal-Automation.md — WineBot Windows Automation Tools (Codex Prompt)

Use this prompt with Codex to add **Windows automation tooling** inside the WineBot container (running under Wine),
including **download, install, and smoke-tests** to confirm each tool runs correctly in-container.

---

## Codex Prompt: Add Windows automation tools to WineBot (AutoIt + AutoHotkey + optional Windows Python/pywinauto)

You are working in the **WineBot** repository. Implement support for Windows automation tools that run well under Wine.

### Goal
Modify the WineBot container so it can run these tools inside the Wine environment:

1) **AutoIt v3 (portable)**  
2) **AutoHotkey (portable)** — prefer **v1.x** for compatibility  
3) **(Optional, but preferred)** Windows **Python (embedded/portable)** + `pywinauto`  

The container must include repeatable **download + install** steps and a **test workflow** that proves each tool runs and can interact with a Wine GUI app.

---

# Requirements

## A) Repository changes
Add the following:

### 1) New folder
Create:

```
windows-tools/
  download_tools.sh
  autoit/
  autohotkey/
  python/
tests/
  test_autoit.au3
  test_ahk.ahk
  test_pywinauto.py
  run_smoke_tests.sh
docs/
  windows-automation-tools.md
```

### 2) Dockerfile updates
Update `docker/Dockerfile` to:

- Install any needed Linux packages:
  - `curl`, `ca-certificates`
  - `unzip`
  - `p7zip-full` (optional, but helpful)
- Copy in `windows-tools/download_tools.sh`
- Download and install the Windows tools into a predictable location, e.g.:

```
/opt/winebot/windows-tools/AutoIt
/opt/winebot/windows-tools/AutoHotkey
/opt/winebot/windows-tools/Python
```

Add convenience symlinks to the PATH (Linux-side) so tools can be invoked as:

- `autoit` → runs AutoIt3.exe via Wine
- `ahk` → runs AutoHotkey.exe via Wine
- `winpy` → runs python.exe via Wine (if installed)

Example wrappers (create small shell scripts in `/usr/local/bin/`):
- `/usr/local/bin/autoit`
- `/usr/local/bin/ahk`
- `/usr/local/bin/winpy`

Each wrapper should run the correct exe under Wine:
- `wine "/opt/winebot/windows-tools/AutoIt/AutoIt3.exe" "$@"`
- `wine "/opt/winebot/windows-tools/AutoHotkey/AutoHotkey.exe" "$@"`
- `wine "/opt/winebot/windows-tools/Python/python.exe" "$@"`

### 3) Entrypoint updates (if needed)
Update `docker/entrypoint.sh` so that:
- Tools are discoverable (PATH includes `/usr/local/bin`)
- It prints tool versions if `DEBUG=1`

---

# Tool sourcing and installation

## B) AutoIt v3 (portable)
### Download strategy
Use a portable distribution (zip) rather than an installer whenever possible.

In `windows-tools/download_tools.sh`, implement:
- Download AutoIt portable / extracted files into `/opt/winebot/windows-tools/AutoIt/`
- Verify expected executables exist:
  - `AutoIt3.exe`
  - optional: `Au3Info.exe` (nice-to-have inspector)

If the official site doesn’t provide a clean zip, implement fallback:
- download installer EXE
- run under Wine in silent mode (if supported)
- copy out the installed folder into `/opt/winebot/windows-tools/AutoIt`

**Success condition**
At build-time or test-time, `autoit /?` must run under wine without crashing.

---

## C) AutoHotkey (portable)
### Version requirement
Prefer **AutoHotkey v1.x** as the default, because many existing automation scripts and syntax assume v1.

### Install
Download the portable zip for AHK v1 and extract into:

`/opt/winebot/windows-tools/AutoHotkey/`

Ensure `AutoHotkey.exe` exists.

**Success condition**
`ahk /?` runs under Wine without crashing.

---

## D) Windows Python (optional but preferred) + pywinauto
### Install approach
Use **Python Embedded** distribution (Windows) to avoid heavy MSI installers.

Install into:
`/opt/winebot/windows-tools/Python/`

Then:
- ensure `python.exe` runs under Wine
- bootstrap pip (embedded Python sometimes needs `get-pip.py`)
- install `pywinauto` inside that Python environment:
  - `winpy -m pip install --no-cache-dir pywinauto`

If pip bootstrap is tricky, document it and proceed, but try to get it working.

**Success condition**
`winpy -c "import pywinauto; print('ok')"` works.

---

# Smoke Testing (must implement)

## E) Add tests that validate each tool works inside the container
Create:

`tests/run_smoke_tests.sh`

This script should:
1) Start the WineBot display stack if needed (Xvfb + openbox) OR assume the container is already running with DISPLAY set.
2) Launch a known Wine GUI app as the target (pick one that exists reliably):
   - Prefer: `wine notepad`
   - Or: `wine explorer`
3) Run each tool against the GUI.

### AutoIt test (`tests/test_autoit.au3`)
Write an AutoIt script that:
- Runs `notepad.exe`
- Waits for it to appear
- Sends text like: `WineBot AutoIt smoke test`
- Exits cleanly

Run it as:
`autoit tests/test_autoit.au3`

### AutoHotkey test (`tests/test_ahk.ahk`)
Write an AHK v1 script that:
- Runs Notepad
- Activates the window
- Sends a line of text
- Exits

Run it as:
`ahk tests/test_ahk.ahk`

### pywinauto test (`tests/test_pywinauto.py`) (optional)
Write a script that:
- Starts Notepad
- Connects by title/class (best effort)
- Types text into the editor control
- Exits

Run it as:
`winpy tests/test_pywinauto.py`

### Evidence capture
At the end of the smoke tests:
- call the existing WineBot screenshot helper or add one if missing
- produce `/tmp/smoke_test.png`

Fail the test script if:
- any tool crashes
- expected output text isn’t typed (best-effort; at minimum confirm tool ran without error)
- screenshot is missing/empty

---

# Documentation updates

## F) Add docs: `docs/windows-automation-tools.md`
Include:
- What each tool is best for
- How to run them inside the container
- How to add your own scripts
- Notes about common failure modes under Wine:
  - control accessibility issues → fall back to keyboard/CV
  - 32-bit vs 64-bit prefix problems

Update `README.md` with a short section:
- “Windows automation tools available: AutoIt, AutoHotkey, Windows Python/pywinauto”
- How to run `tests/run_smoke_tests.sh`

---

# Acceptance Criteria (Definition of Done)

✅ Container builds successfully  
✅ `autoit` runs inside container and can automate Notepad under Wine  
✅ `ahk` runs inside container and can automate Notepad under Wine  
✅ Optional: `winpy` + `pywinauto` works and can at least import + attempt to drive Notepad  
✅ `tests/run_smoke_tests.sh` produces `/tmp/smoke_test.png` and exits 0  
✅ Docs updated with usage instructions

---

# Implementation notes / constraints

- Keep versions pinned in the download script (variables at top).
- Make the tools install non-interactive during Docker build.
- Prefer portable distributions over interactive installers.
- Keep everything under `/opt/winebot/windows-tools/` for clarity.
- Do not expose new network ports.
- If a download URL changes, implement a clear error message and make it easy to update the version/URL.
