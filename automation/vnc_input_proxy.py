#!/usr/bin/env python3
import argparse
import datetime
import json
import os
import select
import signal
import socket
import sys
import threading
import time
import traceback
from typing import Dict, Optional, Tuple

PID_FILE = "input_trace_network.pid"
STATE_FILE = "input_trace_network.state"
LOG_FILE = "input_events_network.jsonl"
PROXY_LOG = "vnc_proxy.log"

DEBUG = os.environ.get("WINEBOT_VNC_PROXY_DEBUG", "0") == "1"

def dlog(msg: str):
    if DEBUG:
        timestamp = datetime.datetime.now().isoformat()
        print(f"[{timestamp}] [PROXY] {msg}", file=sys.stderr)

class StateFlag:
    def __init__(self, state_path: str, default_enabled: bool = True) -> None:
        self.state_path = state_path
        self.enabled = default_enabled
        self.last_check = 0.0

    def read_enabled(self) -> bool:
        now = time.time()
        if now - self.last_check < 1.0:
            return self.enabled
        self.last_check = now
        try:
            with open(self.state_path, "r") as f:
                value = f.read().strip()
            self.enabled = value == "enabled"
        except Exception:
            pass
        return self.enabled

def write_state(path: str, enabled: bool) -> None:
    try:
        with open(path, "w") as f:
            f.write("enabled" if enabled else "disabled")
    except Exception:
        pass

def write_pid(path: str, pid: int) -> None:
    try:
        with open(path, "w") as f:
            f.write(str(pid))
    except Exception:
        pass

def log_event(log_path: str, payload: Dict[str, object]) -> None:
    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a") as f:
            f.write(json.dumps(payload) + "\n")
    except Exception:
        pass

class RfbClientParser:
    def __init__(self, session_id: Optional[str], log_path: str, state_flag: StateFlag, sample_motion_ms: int) -> None:
        self.session_id = session_id
        self.log_path = log_path
        self.state_flag = state_flag
        self.sample_motion_ms = sample_motion_ms
        self.buffer = b""
        self.handshake_stage = "version"
        self.security_type = None
        self.auth_response_remaining = 0
        self.last_motion_ms = 0

    def feed(self, data: bytes, client_addr: Tuple[str, int]) -> None:
        self.buffer += data
        try:
            while True:
                if self.handshake_stage == "version":
                    if len(self.buffer) < 12:
                        return
                    v = self.buffer[:12]
                    dlog(f"Handshake: Client version {v.strip()}")
                    self.buffer = self.buffer[12:]
                    self.handshake_stage = "security_select"
                    continue
                
                if self.handshake_stage == "security_select":
                    if len(self.buffer) < 1:
                        return
                    self.security_type = self.buffer[0]
                    self.buffer = self.buffer[1:]
                    dlog(f"Handshake: Client selected security type {self.security_type}")
                    if self.security_type == 2: # VNC Auth
                        self.auth_response_remaining = 16
                        self.handshake_stage = "auth_response"
                    else:
                        # For None (1) or others we don't support specifically, skip to client_init
                        self.auth_response_remaining = 0
                        self.handshake_stage = "client_init"
                    continue
                
                if self.handshake_stage == "auth_response":
                    if len(self.buffer) < self.auth_response_remaining:
                        return
                    dlog(f"Handshake: Auth response ({self.auth_response_remaining} bytes) received")
                    self.buffer = self.buffer[self.auth_response_remaining:]
                    self.auth_response_remaining = 0
                    self.handshake_stage = "client_init"
                    continue
                
                if self.handshake_stage == "client_init":
                    if len(self.buffer) < 1:
                        return
                    dlog("Handshake: ClientInit received")
                    self.buffer = self.buffer[1:]
                    self.handshake_stage = "messages"
                    continue

                if self.handshake_stage != "messages":
                    return

                if len(self.buffer) < 1:
                    return
                
                msg_type = self.buffer[0]
                if msg_type == 0: # SetPixelFormat
                    if len(self.buffer) < 20: return
                    self.buffer = self.buffer[20:]
                    continue
                if msg_type == 2: # SetEncodings
                    if len(self.buffer) < 4: return
                    count = int.from_bytes(self.buffer[2:4], "big")
                    total = 4 + (count * 4)
                    if len(self.buffer) < total: return
                    self.buffer = self.buffer[total:]
                    continue
                if msg_type == 3: # FramebufferUpdateRequest
                    if len(self.buffer) < 10: return
                    self.buffer = self.buffer[10:]
                    continue
                if msg_type == 4: # KeyEvent
                    if len(self.buffer) < 8: return
                    down = self.buffer[1] == 1
                    key = int.from_bytes(self.buffer[4:8], "big")
                    self.buffer = self.buffer[8:]
                    self.emit_key_event(down, key, client_addr)
                    continue
                if msg_type == 5: # PointerEvent
                    if len(self.buffer) < 6: return
                    button_mask = self.buffer[1]
                    x = int.from_bytes(self.buffer[2:4], "big")
                    y = int.from_bytes(self.buffer[4:6], "big")
                    self.buffer = self.buffer[6:]
                    self.emit_pointer_event(button_mask, x, y, client_addr)
                    continue
                if msg_type == 6: # ClientCutText
                    if len(self.buffer) < 8: return
                    length = int.from_bytes(self.buffer[4:8], "big")
                    total = 8 + length
                    if len(self.buffer) < total: return
                    self.buffer = self.buffer[total:]
                    continue

                # Unknown message type; discard one byte to avoid infinite loop
                dlog(f"Warning: Unknown client msg type {msg_type}, discarding 1 byte")
                self.buffer = self.buffer[1:]
        except Exception as e:
            dlog(f"Parser error: {e}\n{traceback.format_exc()}")

    def emit_key_event(self, down: bool, key: int, client_addr: Tuple[str, int]) -> None:
        if not self.state_flag.read_enabled():
            return
        payload = {
            "timestamp_epoch_ms": int(time.time() * 1000),
            "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "session_id": self.session_id,
            "source": "network",
            "layer": "network",
            "event": "vnc_key",
            "origin": "user",
            "tool": "vnc_network_proxy",
            "down": down,
            "key": key,
            "client_addr": f"{client_addr[0]}:{client_addr[1]}",
        }
        log_event(self.log_path, payload)

    def emit_pointer_event(self, button_mask: int, x: int, y: int, client_addr: Tuple[str, int]) -> None:
        if not self.state_flag.read_enabled():
            return
        now_ms = int(time.time() * 1000)
        if button_mask == 0 and self.sample_motion_ms > 0:
            if now_ms - self.last_motion_ms < self.sample_motion_ms:
                return
            self.last_motion_ms = now_ms
        payload = {
            "timestamp_epoch_ms": now_ms,
            "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "session_id": self.session_id,
            "source": "network",
            "layer": "network",
            "event": "vnc_pointer",
            "origin": "user",
            "tool": "vnc_network_proxy",
            "button_mask": button_mask,
            "x": x,
            "y": y,
            "client_addr": f"{client_addr[0]}:{client_addr[1]}",
        }
        log_event(self.log_path, payload)

def proxy_connection(
    client_sock: socket.socket,
    client_addr: Tuple[str, int],
    target_host: str,
    target_port: int,
    parser: RfbClientParser,
) -> None:
    dlog(f"New connection from {client_addr}")
    try:
        server_sock = socket.create_connection((target_host, target_port), timeout=5)
    except Exception as e:
        dlog(f"Failed to connect to target {target_host}:{target_port}: {e}")
        client_sock.close()
        return

    client_sock.setblocking(False)
    server_sock.setblocking(False)

    to_client = b""
    to_server = b""
    sockets = [client_sock, server_sock]

    try:
        while True:
            outputs = []
            if to_client: outputs.append(client_sock)
            if to_server: outputs.append(server_sock)

            readable, writable, exceptional = select.select(sockets, outputs, sockets, 1.0)

            if exceptional:
                dlog("Socket exception occurred")
                break

            for sock in readable:
                try:
                    data = sock.recv(16384)
                except BlockingIOError:
                    continue
                except Exception as e:
                    dlog(f"Recv error: {e}")
                    data = None
                
                if not data:
                    dlog("Connection closed by peer")
                    return

                if sock is client_sock:
                    try:
                        parser.feed(data, client_addr)
                    except Exception:
                        pass
                    to_server += data
                else:
                    to_client += data

            for sock in writable:
                try:
                    if sock is client_sock and to_client:
                        sent = sock.send(to_client)
                        to_client = to_client[sent:]
                    elif sock is server_sock and to_server:
                        sent = sock.send(to_server)
                        to_server = to_server[sent:]
                except BlockingIOError:
                    continue
                except Exception as e:
                    dlog(f"Send error: {e}")
                    return
    finally:
        dlog(f"Closing connection for {client_addr}")
        try: client_sock.close()
        except Exception: pass
        try: server_sock.close()
        except Exception: pass

def run_proxy(
    listen_host: str,
    listen_port: int,
    target_host: str,
    target_port: int,
    session_dir: str,
    sample_motion_ms: int,
) -> int:
    log_path = os.path.join(session_dir, "logs", LOG_FILE)
    state_path = os.path.join(session_dir, STATE_FILE)
    pid_path = os.path.join(session_dir, PID_FILE)
    
    os.makedirs(os.path.join(session_dir, "logs"), exist_ok=True)
    
    # Redirect stderr to log file if not in terminal
    if not sys.stderr.isatty():
        proxy_log_path = os.path.join(session_dir, "logs", PROXY_LOG)
        try:
            sys.stderr = open(proxy_log_path, "a")
        except Exception:
            pass

    write_state(state_path, True)
    write_pid(pid_path, os.getpid())
    state_flag = StateFlag(state_path, default_enabled=True)
    session_id = os.path.basename(session_dir)

    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server_sock.bind((listen_host, listen_port))
    except Exception as e:
        print(f"Failed to bind to {listen_host}:{listen_port}: {e}", file=sys.stderr)
        return 1
        
    server_sock.listen(128)
    server_sock.settimeout(1.0)

    dlog(f"Proxy listening on {listen_host}:{listen_port}, targeting {target_host}:{target_port}")

    stop_flag = {"stop": False}
    def handle_signal(_sig, _frame):
        stop_flag["stop"] = True
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    threads = []
    try:
        while not stop_flag["stop"]:
            try:
                client_sock, client_addr = server_sock.accept()
            except socket.timeout:
                continue
            except Exception:
                if stop_flag["stop"]: break
                continue
            
            parser = RfbClientParser(session_id, log_path, state_flag, sample_motion_ms)
            thread = threading.Thread(
                target=proxy_connection,
                args=(client_sock, client_addr, target_host, target_port, parser),
                daemon=True,
            )
            thread.start()
            threads.append(thread)
            
            # Clean up finished threads
            threads = [t for t in threads if t.is_alive()]
    finally:
        try: server_sock.close()
        except Exception: pass
        for thread in threads:
            thread.join(timeout=0.5)
    return 0

def main() -> int:
    parser = argparse.ArgumentParser(description="VNC TCP proxy with input tracing.")
    parser.add_argument("--listen-host", default="0.0.0.0")
    parser.add_argument("--listen-port", type=int, default=5900)
    parser.add_argument("--target-host", default="127.0.0.1")
    parser.add_argument("--target-port", type=int, default=5901)
    parser.add_argument("--session-dir", required=True)
    parser.add_argument("--sample-motion-ms", type=int, default=10)
    args = parser.parse_args()
    return run_proxy(
        args.listen_host,
        args.listen_port,
        args.target_host,
        args.target_port,
        args.session_dir,
        args.sample_motion_ms,
    )

if __name__ == "__main__":
    sys.exit(main())