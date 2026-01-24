# Architecture

WineBot runs Windows GUI applications inside a Linux container using Wine, Xvfb, and a lightweight window manager.

## Display stack

- `Xvfb` provides a virtual X11 display on `:99`
- `openbox` is the window manager for consistent geometry
- `x11vnc` and noVNC expose the same display in interactive mode

## Startup flow

1. Initialize the Wine prefix if missing
2. Start Xvfb and openbox
3. Optionally start VNC/noVNC
4. Launch the target Windows executable (optionally under winedbg)
5. Optionally run an automation command

## Persistence

The Wine prefix is stored at `/wineprefix`, backed by a named Docker volume to persist across restarts.
