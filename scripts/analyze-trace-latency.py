#!/usr/bin/env python3
import argparse
import json
import os
import sys
from typing import Dict, List, Optional

def load_events(path: str) -> List[Dict]:
    events = []
    if not os.path.exists(path):
        return events
    try:
        with open(path, 'r') as f:
            for line in f:
                if line.strip():
                    try:
                        events.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    except Exception as e:
        print(f"Error loading {path}: {e}", file=sys.stderr)
    return events

def analyze_latency(session_dir: str):
    log_dir = os.path.join(session_dir, "logs")
    net_log = os.path.join(log_dir, "input_events_network.jsonl")
    x11_log = os.path.join(log_dir, "input_events.jsonl")
    win_log = os.path.join(log_dir, "input_events_windows.jsonl")

    net_events = load_events(net_log)
    x11_events = load_events(x11_log)
    win_events = load_events(win_log)

    print(f"Loaded {len(net_events)} network events, {len(x11_events)} X11 events, {len(win_events)} Windows events.")

    # Simple heuristic matching based on event type and timestamp
    # We look for:
    # Network (vnc_pointer click) -> X11 (ButtonPress) -> Windows (mouse_down)
    
    matches = []
    
    # Filter for clicks (button down)
    net_clicks = [e for e in net_events if e.get("event") == "vnc_pointer" and e.get("button_mask", 0) > 0]
    # Simplify: just take the first button mask bit as left click for now
    
    x11_clicks = [e for e in x11_events if e.get("event") == "button_press"]
    win_clicks = [e for e in win_events if e.get("event") == "mouse_down"]

    # Match Network -> X11
    # For each network click, find the first X11 click that happened AFTER it, within a small window (e.g., 500ms)
    
    x11_cursor = 0
    win_cursor = 0
    
    latencies_net_x11 = []
    latencies_x11_win = []
    latencies_total = []

    for net in net_clicks:
        net_ts = net.get("timestamp_epoch_ms", 0)
        
        # Find matching X11
        match_x11 = None
        for i in range(x11_cursor, len(x11_clicks)):
            x11 = x11_clicks[i]
            x11_ts = x11.get("timestamp_epoch_ms", 0)
            
            if x11_ts < net_ts:
                continue # Skip old X11 events
            
            if x11_ts - net_ts > 1000:
                break # Too far ahead, stop searching for this net event
            
            # Found a match?
            # Basic check: button numbers match? (VNC mask 1 = Left = X11 button 1)
            # VNC mask 1 -> Button 1
            # VNC mask 2 -> Button 2
            # VNC mask 4 -> Button 3
            vnc_mask = net.get("button_mask", 0)
            x11_btn = x11.get("button", 0)
            
            # Mapping simplified
            matched_btn = False
            if (vnc_mask & 1) and x11_btn == 1: matched_btn = True
            elif (vnc_mask & 2) and x11_btn == 2: matched_btn = True
            elif (vnc_mask & 4) and x11_btn == 3: matched_btn = True
            
            if matched_btn:
                match_x11 = x11
                x11_cursor = i + 1
                break
        
        if match_x11:
            delta_nx = match_x11.get("timestamp_epoch_ms", 0) - net_ts
            latencies_net_x11.append(delta_nx)
            
            # Find matching Windows
            match_win = None
            for j in range(win_cursor, len(win_clicks)):
                win = win_clicks[j]
                win_ts = win.get("timestamp_epoch_ms", 0)
                
                if win_ts < match_x11.get("timestamp_epoch_ms", 0):
                    continue
                
                if win_ts - match_x11.get("timestamp_epoch_ms", 0) > 1000:
                    break
                
                # Check button
                win_btn = win.get("button", "").lower()
                x11_b = match_x11.get("button", 0)
                
                matched_w = False
                if x11_b == 1 and "left" in win_btn: matched_w = True
                elif x11_b == 2 and "middle" in win_btn: matched_w = True
                elif x11_b == 3 and "right" in win_btn: matched_w = True
                
                if matched_w:
                    match_win = win
                    win_cursor = j + 1
                    break
            
            if match_win:
                delta_xw = match_win.get("timestamp_epoch_ms", 0) - match_x11.get("timestamp_epoch_ms", 0)
                latencies_x11_win.append(delta_xw)
                latencies_total.append(match_win.get("timestamp_epoch_ms", 0) - net_ts)
                
                print(f"MATCH: Net({net_ts}) -> X11(+{delta_nx}ms) -> Win(+{delta_xw}ms) = Total {match_win.get('timestamp_epoch_ms', 0) - net_ts}ms")
            else:
                print(f"PARTIAL: Net({net_ts}) -> X11(+{delta_nx}ms) -> Win(MISSING)")
        else:
            print(f"MISSING: Net({net_ts}) -> X11(MISSING)")

    def stats(data):
        if not data: return "N/A"
        return f"Avg={sum(data)/len(data):.1f}ms, Min={min(data)}ms, Max={max(data)}ms, Count={len(data)}"

    print("-" * 40)
    print(f"Network -> X11 Latency: {stats(latencies_net_x11)}")
    print(f"X11 -> Windows Latency: {stats(latencies_x11_win)}")
    print(f"Total End-to-End Latency: {stats(latencies_total)}")

def main():
    parser = argparse.ArgumentParser(description="Analyze input latency from trace logs.")
    parser.add_argument("--session-dir", help="Session directory to analyze. Defaults to current session.", default="")
    args = parser.parse_args()

    session_dir = args.session_dir
    if not session_dir and os.path.exists("/tmp/winebot_current_session"):
        with open("/tmp/winebot_current_session", "r") as f:
            session_dir = f.read().strip()
    
    if not session_dir or not os.path.isdir(session_dir):
        print("Session directory not found. Specify --session-dir or ensure winebot is running.", file=sys.stderr)
        return 1

    analyze_latency(session_dir)
    return 0

if __name__ == "__main__":
    sys.exit(main())
