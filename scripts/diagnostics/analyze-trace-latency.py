import argparse
import json
import os
from typing import List, Dict


def read_jsonl(path: str) -> List[Dict]:
    if not os.path.exists(path):
        return []
    items = []
    with open(path, "r") as f:
        for line in f:
            try:
                items.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return items


def analyze_latency(session_dir: str):
    net_path = os.path.join(session_dir, "logs", "input_events_network.jsonl")
    x11_path = os.path.join(session_dir, "logs", "input_events.jsonl")
    win_path = os.path.join(session_dir, "logs", "input_events_windows.jsonl")

    net_events = read_jsonl(net_path)
    x11_events = [e for e in read_jsonl(x11_path) if e.get("event") == "button_press"]
    win_events = [e for e in read_jsonl(win_path) if e.get("event") == "mousedown"]

    print(f"Analyzing session: {os.path.basename(session_dir)}")
    print(
        f"Events: Network={len(net_events)}, X11={len(x11_events)}, Windows={len(win_events)}"
    )
    print("-" * 40)

    latencies_net_x11 = []
    latencies_x11_win = []
    latencies_total = []

    x11_cursor = 0
    win_cursor = 0

    for net in net_events:
        if net.get("event") != "vnc_pointer":
            continue

        vnc_mask = net.get("button_mask", 0)
        if vnc_mask == 0:  # Filter motion
            continue

        net_ts = net["timestamp_epoch_ms"]
        match_x11 = None

        # 1. Match Network -> X11
        for i in range(x11_cursor, len(x11_events)):
            x11 = x11_events[i]
            x11_ts = x11["timestamp_epoch_ms"]

            # X11 event should be after Network event within a reasonable window
            delta = x11_ts - net_ts
            if 0 <= delta <= 500:
                # Basic button check (Net mask 1 = left, X11 btn 1 = left)
                x11_btn = x11.get("button", 0)
                matched_btn = False
                if (vnc_mask & 1) and x11_btn == 1:
                    matched_btn = True
                elif (vnc_mask & 2) and x11_btn == 2:
                    matched_btn = True
                elif (vnc_mask & 4) and x11_btn == 3:
                    matched_btn = True

                if matched_btn:
                    match_x11 = x11
                    x11_cursor = i + 1
                    break

        if match_x11:
            delta_nx = match_x11["timestamp_epoch_ms"] - net_ts
            latencies_net_x11.append(delta_nx)

            # 2. Match X11 -> Windows
            match_win = None
            x11_ts = match_x11["timestamp_epoch_ms"]
            for j in range(win_cursor, len(win_events)):
                win = win_events[j]
                win_ts = win["timestamp_epoch_ms"]
                delta_xw = win_ts - x11_ts

                if 0 <= delta_xw <= 500:
                    win_btn = win.get("button", "").lower()
                    x11_b = match_x11.get("button", 0)
                    matched_w = False
                    if x11_b == 1 and "left" in win_btn:
                        matched_w = True
                    elif x11_b == 2 and "middle" in win_btn:
                        matched_w = True
                    elif x11_b == 3 and "right" in win_btn:
                        matched_w = True

                    if matched_w:
                        match_win = win
                        win_cursor = j + 1
                        break

            if match_win:
                delta_xw = (
                    match_win["timestamp_epoch_ms"] - match_x11["timestamp_epoch_ms"]
                )
                latencies_x11_win.append(delta_xw)
                latencies_total.append(match_win["timestamp_epoch_ms"] - net_ts)
                print(
                    f"MATCH: Net({net_ts}) -> X11(+{delta_nx}ms) -> Win(+{delta_xw}ms) Total={match_win['timestamp_epoch_ms'] - net_ts}ms"
                )
            else:
                print(f"PARTIAL: Net({net_ts}) -> X11(+{delta_nx}ms) -> Win(MISSING)")
        else:
            print(f"MISSING: Net({net_ts}) -> X11(MISSING)")

    def stats(data):
        if not data:
            return "N/A"
        return f"Avg={sum(data) / len(data):.1f}ms, Min={min(data)}ms, Max={max(data)}ms, Count={len(data)}"

    print("-" * 40)
    print(f"Network -> X11 Latency: {stats(latencies_net_x11)}")
    print(f"X11 -> Windows Latency: {stats(latencies_x11_win)}")
    print(f"Total End-to-End Latency: {stats(latencies_total)}")


def main():
    parser = argparse.ArgumentParser(
        description="Analyze input latency from trace logs."
    )
    parser.add_argument(
        "--session-dir",
        help="Session directory to analyze. Defaults to current session.",
        default="",
    )
    args = parser.parse_args()

    session_dir = args.session_dir
    if not session_dir:
        path = "/tmp/winebot_current_session"
        if os.path.exists(path):
            with open(path, "r") as f:
                session_dir = f.read().strip()

    if not session_dir or not os.path.exists(session_dir):
        print("Error: Session directory not found.")
        return 1

    analyze_latency(session_dir)
    return 0


if __name__ == "__main__":
    main()
