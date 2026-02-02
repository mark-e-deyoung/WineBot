# Performance & Reliability

This guide focuses on reducing CPU/memory usage while keeping automation features intact and behavior understandable for agents and humans.

## Recommended Defaults
- **Disable heavy features unless needed:** `ENABLE_VNC=0`, `ENABLE_WINEDBG=0`, `WINEBOT_RECORD=0`.
- **Lower display cost:** use a smaller `SCREEN` when full HD isn’t required (e.g., `1280x720x24`).
- **Prefer summary health:** use `/health` for quick checks and `/health/*` for deeper inspection.
- **Limit control scans:** for `/inspect/window`, set `include_controls=false` or cap `max_controls` when possible.

## Low-Resource Compose Override
Use the provided override to reduce resource usage while keeping core features:

```bash
docker compose -f compose/docker-compose.yml -f compose/overrides.low-resource.yml --profile headless up --build
```

For interactive mode:
```bash
docker compose -f compose/docker-compose.yml -f compose/overrides.low-resource.yml --profile interactive up --build
```

## Automation Best Practices
- **Target windows deterministically:** prefer stable titles or handles to avoid expensive searches.
- **Batch actions:** avoid repeated wine initialization by running related steps in a single session.
- **Use focused calls:** keep `/inspect/window` and screenshots to the minimum required for the task.

## Recording & Debugging
- **Recording** is powerful but expensive; enable only for runs that require artifacts.
- **winedbg/gdb** adds overhead; use only for troubleshooting.

## Testing Strategy
- **Smoke tests stay minimal:** quick checks for boot, API, and metadata.
- **Deep checks run separately:** full Notepad automation, recording validation, and gdb‑proxy tests can be nightly/CI.

## Readability for Agents & Humans
- **Stable endpoints:** keep `/health` fast and high-level; use `/health/*` for detail.
- **Consistent IDs:** use request IDs in screenshots and logs to correlate events.
