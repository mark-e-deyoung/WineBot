# Status

## Current state
- Headless and interactive services are running (`compose_winebot_1`, `compose_winebot-interactive_1`).
- Default app launch is `cmd.exe` when `APP_EXE` is unset (via `wineconsole /k echo WineBot ready`).
- Xvfb stale lock cleanup and `HOME`/cache setup are in `docker/entrypoint.sh`.
- Automation commands should be run as `winebot` to avoid Wine prefix ownership issues.

## Validation so far
- `automation/screenshot.sh` produced `/tmp/screenshot.png` inside the container.
- `automation/notepad_create_and_verify.py` succeeded when run as `winebot`.
- `wmctrl -l` shows a running `cmd.exe` window in the interactive container.

## Known quirks
- `docker-compose` v1 is installed here (not the `docker compose` plugin).
- `automation/find_and_click.py` will return exit code `2` until a real template matches visible UI.

## Next steps (pick up here)
1. In noVNC (`http://localhost:6080`), confirm the `cmd.exe` window is visible.
2. If not visible, list windows and switch to desktop 0:
   - `docker-compose -f compose/docker-compose.yml --profile interactive exec -T --user winebot winebot-interactive bash -lc 'DISPLAY=:99 wmctrl -l'`
   - `docker-compose -f compose/docker-compose.yml --profile interactive exec -T --user winebot winebot-interactive bash -lc 'DISPLAY=:99 wmctrl -s 0'`
3. Launch your app by setting `APP_EXE=/apps/YourApp.exe` and restarting the interactive service.
4. Re-capture a real UI element and re-run `automation/find_and_click.py` with that template.

