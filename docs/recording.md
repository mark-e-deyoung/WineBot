# Recording and Annotations

WineBot supports recording session video with automatically generated subtitles and positional annotations.

## Enabling Recording

Recording is opt-in and controlled via environment variables or the `--record` flag in `scripts/run-app.sh`.

### Using the CLI
```bash
./scripts/run-app.sh notepad.exe --record
```

### Using Environment Variables
Set `WINEBOT_RECORD=1` when starting the container.

| Variable | Description | Default |
|----------|-------------|---------|
| `WINEBOT_RECORD` | Enable recording (1 to enable) | 0 |
| `WINEBOT_SESSION_ROOT` | Root directory for session artifacts | `/artifacts/sessions` |
| `WINEBOT_SESSION_LABEL` | Optional label appended to the session ID | (empty) |
| `WINEBOT_RECORD_FORMAT` | Video format (currently MKV is canonical) | `mkv` |

## Artifacts

Each run generates a unique session directory in `/artifacts/sessions/session-<timestamp>-<rand>/`.

Artifacts produced:
- `video.mkv`: The recorded video (H.264/AAC).
- `session.json`: Metadata about the session (resolution, fps, start time, etc).
- `events.jsonl`: Canonical machine-readable event log.
- `events.vtt`: WebVTT subtitles for use in web players.
- `events.ass`: Advanced Substation Alpha subtitles for positional overlays.

## Adding Annotations

You can add annotations to the recording from any script running inside the container using `scripts/annotate.sh`.

### Text Subtitles
```bash
scripts/annotate.sh --text "Step 1: Opening file" --type subtitle
```

### Positional Overlays
Positional overlays appear at specific coordinates on the screen.
```bash
scripts/annotate.sh --text "Click here" --pos "100,200" --type overlay
```
Format for `--pos` is `x,y` or `x,y,w,h`.

## Viewing Overlays

The canonical output is an MKV file. You can toggle the annotations ON/OFF in most video players (VLC, mpv, etc.) by selecting the subtitle track.
- The `Default` track contains basic lifecycle events and text subtitles.
- The `Overlay` track (in ASS format) contains positioned text.

## How it Works

1. **Recorder**: A Python module (`automation.recorder`) wraps `ffmpeg` with `x11grab` to capture the X11 display.
2. **Lifecycle Hooks**: `docker/entrypoint.sh` starts the recorder after Xvfb is ready and stops it on exit.
3. **Event Log**: All annotations and lifecycle events are written to `events.jsonl` with monotonic timestamps.
4. **Post-processing**: When the session stops, the recorder generates `.vtt` and `.ass` files from the event log.
