# Debugging

This guide covers winedbg support in WineBot and other useful tooling for troubleshooting.

## winedbg (internal)

Launch an app under winedbg in gdb proxy mode (default):

`ENABLE_WINEDBG=1 WINEDBG_MODE=gdb WINEDBG_PORT=2345 WINEDBG_NO_START=1 APP_EXE=/apps/MyApp.exe docker compose -f compose/docker-compose.yml --profile interactive up --build`

Connect from the host:

`gdb -ex "target remote localhost:2345"`

Run a scripted winedbg command (default mode):

`ENABLE_WINEDBG=1 WINEDBG_MODE=default WINEDBG_COMMAND="info proc" APP_EXE=/apps/MyApp.exe docker compose -f compose/docker-compose.yml --profile headless up --build`

Notes:

- `WINEDBG_PORT=0` skips `--port` (winedbg chooses a random port).
- The interactive compose profile publishes `WINEDBG_PORT`; for headless runs, add a port mapping in an override file if you need remote gdb access.
- `WINEDBG_NO_START=0` auto-starts gdb inside the container.
- `WINEDBG_COMMAND` and `WINEDBG_SCRIPT` only apply to `WINEDBG_MODE=default`.
- `scripts/smoke-test.sh --include-debug` runs a minimal winedbg check.
- `scripts/smoke-test.sh --include-debug-proxy` runs a gdb proxy attach check and verifies the target exe is running.
- `gdb` may exit with code `137` in some container environments; treat it as valid if threads are printed.

## Other Windows-side tools (run under Wine)

These can be installed into the prefix or placed under `apps/`:

- Sysinternals tools: ProcDump, Process Explorer, Process Monitor, DebugView
- Dependency Walker/Dependencies to inspect missing DLLs
- App-specific crash reporters or logging tools

## Host/container perspective

Useful Linux-side tools for observing the Wine environment:

- `WINEDEBUG` channels for verbose logging (example: `WINEDEBUG=+seh,+tid,+timestamp`)
- `xwininfo`, `xprop`, `wmctrl`, `xdotool` for window inspection and focus issues
- `ps`, `top`, and `/proc` (via `procps`) for process state
- Optional: `strace`, `ltrace`, `lsof`, `tcpdump` if you add them to the image
