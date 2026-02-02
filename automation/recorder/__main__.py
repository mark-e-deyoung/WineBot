import argparse
import sys
import os
import json
import time
import signal
import logging
import fcntl
import datetime
from pathlib import Path
from typing import Optional

from .models import SessionManifest, Event
from .ffmpeg import FFMpegRecorder
from .subtitles import SubtitleGenerator

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("winebot-recorder")
FFMPEG_PID_FILE = "ffmpeg.pid"
STATE_FILE = "recorder.state"

def get_iso_time():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def lock_file(f):
    fcntl.flock(f, fcntl.LOCK_EX)

def unlock_file(f):
    fcntl.flock(f, fcntl.LOCK_UN)

def append_event(session_dir: str, event: Event):
    events_path = os.path.join(session_dir, "events.jsonl")
    with open(events_path, "a") as f:
        lock_file(f)
        try:
            f.write(event.to_json() + "\n")
            f.flush()
        finally:
            unlock_file(f)

def load_events(session_dir: str):
    events = []
    events_path = os.path.join(session_dir, "events.jsonl")
    if not os.path.exists(events_path):
        return []
    
    with open(events_path, "r") as f:
        # No lock needed for reading usually, but to be safe vs partial writes?
        # Appends are atomic enough for jsonl usually.
        for line in f:
            if line.strip():
                try:
                    events.append(Event.from_json(line))
                except json.JSONDecodeError:
                    pass
    return events

def read_pid(path: str) -> Optional[int]:
    try:
        with open(path, "r") as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None

def write_state(session_dir: str, state: str):
    try:
        with open(os.path.join(session_dir, STATE_FILE), "w") as f:
            f.write(state)
    except Exception:
        pass

def signal_ffmpeg(session_dir: str, sig: int, action: str):
    pid_path = os.path.join(session_dir, FFMPEG_PID_FILE)
    pid = read_pid(pid_path)
    if not pid:
        logger.error(f"No ffmpeg PID file found at {pid_path}.")
        sys.exit(1)
    try:
        os.kill(pid, sig)
    except ProcessLookupError:
        logger.error(f"ffmpeg process {pid} not found.")
        sys.exit(1)

    session_json = os.path.join(session_dir, "session.json")
    if os.path.exists(session_json):
        try:
            with open(session_json, "r") as f:
                manifest = json.load(f)
            start_time_epoch = manifest["start_time_epoch"]
            now_epoch = time.time() * 1000
            t_rel = int(now_epoch - start_time_epoch)
            append_event(session_dir, Event(
                session_id=manifest["session_id"],
                t_rel_ms=t_rel,
                t_epoch_ms=int(now_epoch),
                level="INFO",
                kind=f"recorder_{action}",
                message=f"Recorder {action}"
            ))
        except Exception:
            pass

    write_state(session_dir, "paused" if action == "pause" else "recording")

def cmd_start(args):
    session_dir = args.session_dir
    os.makedirs(session_dir, exist_ok=True)
    
    # Write PID file
    pid_file = os.path.join(session_dir, "recorder.pid")
    with open(pid_file, "w") as f:
        f.write(str(os.getpid()))
        
    start_time_monotonic = time.monotonic() * 1000
    start_time_epoch = time.time() * 1000
    
    # Write Manifest
    manifest = SessionManifest(
        session_id=os.path.basename(session_dir),
        start_time_epoch=start_time_epoch,
        start_time_iso=get_iso_time(),
        hostname=os.uname().nodename,
        display=args.display,
        resolution=args.resolution,
        fps=args.fps,
        git_sha=os.environ.get("GIT_SHA") # Optional
    )
    
    with open(os.path.join(session_dir, "session.json"), "w") as f:
        f.write(manifest.to_json())
        
    # Start FFMpeg
    output_file = os.path.join(session_dir, "video.mkv")
    recorder = FFMpegRecorder(args.display, args.resolution, args.fps, output_file)
    recorder.start()
    if recorder.process and recorder.process.pid:
        with open(os.path.join(session_dir, FFMPEG_PID_FILE), "w") as f:
            f.write(str(recorder.process.pid))
    write_state(session_dir, "recording")
    
    # Log start event
    append_event(session_dir, Event(
        session_id=manifest.session_id,
        t_rel_ms=0,
        t_epoch_ms=int(start_time_epoch),
        level="INFO",
        kind="lifecycle",
        message="Session started"
    ))
    
    append_event(session_dir, Event(
        session_id=manifest.session_id,
        t_rel_ms=0,
        t_epoch_ms=int(start_time_epoch),
        level="INFO",
        kind="recorder_start",
        message="Recorder started"
    ))
    
    def cleanup(signum, frame):
        logger.info("Received stop signal. Cleaning up...")
        end_time_monotonic = time.monotonic() * 1000
        t_rel = int(end_time_monotonic - start_time_monotonic)
        t_epoch = int(time.time() * 1000)
        
        append_event(session_dir, Event(
            session_id=manifest.session_id,
            t_rel_ms=t_rel,
            t_epoch_ms=t_epoch,
            level="INFO",
            kind="recorder_stop",
            message="Recorder stopped"
        ))
        
        recorder.stop()
        
        # Generate Subtitles
        logger.info("Generating subtitles...")
        events = load_events(session_dir)
        gen = SubtitleGenerator(events)
        
        with open(os.path.join(session_dir, "events.vtt"), "w") as f:
            f.write(gen.generate_vtt())
            
        # Parse resolution for ASS
        w, h = map(int, args.resolution.split('x'))
        ass_path = os.path.join(session_dir, "events.ass")
        vtt_path = os.path.join(session_dir, "events.vtt")
        with open(ass_path, "w") as f:
            f.write(gen.generate_ass(w, h))
            
        # Mux into video with global metadata
        meta = {
            "title": manifest.session_id,
            "encoder": "WineBot Recorder",
            "creation_time": manifest.start_time_iso,
            "WINEBOT_SESSION_ID": manifest.session_id,
            "WINEBOT_GIT_SHA": manifest.git_sha,
            "WINEBOT_HOSTNAME": manifest.hostname,
            "WINEBOT_DISPLAY": manifest.display
        }
        recorder.mux_subtitles(ass_path, vtt_path, metadata=meta)

        # Remove PID file
        if os.path.exists(pid_file):
            os.remove(pid_file)
        ffmpeg_pid_path = os.path.join(session_dir, FFMPEG_PID_FILE)
        if os.path.exists(ffmpeg_pid_path):
            os.remove(ffmpeg_pid_path)
        state_path = os.path.join(session_dir, STATE_FILE)
        if os.path.exists(state_path):
            os.remove(state_path)
            
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    
    logger.info("Recording active. Waiting for signal...")
    while True:
        time.sleep(1)

def cmd_stop(args):
    session_dir = args.session_dir
    pid_file = os.path.join(session_dir, "recorder.pid")
    
    if not os.path.exists(pid_file):
        logger.error(f"No PID file found at {pid_file}. Is recorder running?")
        sys.exit(1)
        
    with open(pid_file, "r") as f:
        pid = int(f.read().strip())
        
    try:
        os.kill(pid, signal.SIGTERM)
        logger.info(f"Sent SIGTERM to recorder process {pid}")
    except ProcessLookupError:
        logger.warning(f"Process {pid} not found. Cleaning up artifacts anyway?")
        # Force generation if process died? 
        # For now, just exit. The recorder process logic handles generation on exit.
        # If it crashed hard, we might need a 'recover' command.
    
    # Wait for it to vanish
    for _ in range(10):
        if not os.path.exists(pid_file):
            logger.info("Recorder stopped successfully.")
            break
        time.sleep(0.5)
    else:
        logger.warning("Recorder PID file still exists after 5s.")

def cmd_annotate(args):
    session_dir = args.session_dir
    session_json = os.path.join(session_dir, "session.json")
    
    if not os.path.exists(session_json):
        # Fallback if session hasn't fully started or is broken?
        # We need start time to calculate t_rel_ms
        logger.error("Session manifest not found.")
        sys.exit(1)
        
    with open(session_json, "r") as f:
        manifest = json.load(f)
        
    start_time_epoch = manifest['start_time_epoch']
    now_epoch = time.time() * 1000
    t_rel = int(now_epoch - start_time_epoch)
    
    pos = None
    if args.pos:
        parts = list(map(int, args.pos.split(',')))
        if len(parts) == 4:
            pos = {'x': parts[0], 'y': parts[1], 'w': parts[2], 'h': parts[3]}
        elif len(parts) == 2:
             pos = {'x': parts[0], 'y': parts[1], 'w': 0, 'h': 0}
    
    style = None
    if args.style:
        try:
            style = json.loads(args.style)
        except:
            style = {"raw": args.style}
            
    event = Event(
        session_id=manifest['session_id'],
        t_rel_ms=t_rel,
        t_epoch_ms=int(now_epoch),
        level="INFO",
        kind=args.kind, # annotation, lifecycle, etc.
        message=args.text,
        pos=pos,
        style=style,
        source=args.source
    )
    
    append_event(session_dir, event)

def cmd_pause(args):
    signal_ffmpeg(args.session_dir, signal.SIGSTOP, "pause")

def cmd_resume(args):
    signal_ffmpeg(args.session_dir, signal.SIGCONT, "resume")

def main():
    parser = argparse.ArgumentParser(prog="winebot_recorder")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Start
    p_start = subparsers.add_parser("start")
    p_start.add_argument("--session-dir", required=True)
    p_start.add_argument("--display", default=":99")
    p_start.add_argument("--resolution", default="1920x1080")
    p_start.add_argument("--fps", type=int, default=30)
    
    # Stop
    p_stop = subparsers.add_parser("stop")
    p_stop.add_argument("--session-dir", required=True)
    
    # Annotate
    p_ann = subparsers.add_parser("annotate")
    p_ann.add_argument("--session-dir", required=True)
    p_ann.add_argument("--text", required=True)
    p_ann.add_argument("--kind", default="annotation")
    p_ann.add_argument("--pos", help="x,y,w,h or x,y")
    p_ann.add_argument("--style", help="JSON style string")
    p_ann.add_argument("--source", help="Source tool name")

    # Pause
    p_pause = subparsers.add_parser("pause")
    p_pause.add_argument("--session-dir", required=True)

    # Resume
    p_resume = subparsers.add_parser("resume")
    p_resume.add_argument("--session-dir", required=True)

    args = parser.parse_args()
    
    if args.command == "start":
        cmd_start(args)
    elif args.command == "stop":
        cmd_stop(args)
    elif args.command == "annotate":
        cmd_annotate(args)
    elif args.command == "pause":
        cmd_pause(args)
    elif args.command == "resume":
        cmd_resume(args)

if __name__ == "__main__":
    main()
