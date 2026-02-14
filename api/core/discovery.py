import os
import socket
import logging
import time
import threading
import signal
from typing import List, Optional, Dict
from zeroconf import IPVersion, ServiceInfo, Zeroconf, ServiceBrowser, ServiceStateChange

logger = logging.getLogger("winebot.discovery")

SERVICE_TYPE = "_winebot-session._tcp.local."

class DiscoveryManager:
    def __init__(self):
        self.zeroconf: Optional[Zeroconf] = None
        self.service_info: Optional[ServiceInfo] = None
        self.session_id = os.getenv("WINEBOT_SESSION_ID", socket.gethostname())
        self.allow_multiple = os.getenv("ALLOW_MULTIPLE_SESSIONS", "True").lower() == "true"
        self.api_port = int(os.getenv("API_PORT", "8000"))
        self.vnc_port = int(os.getenv("NOVNC_PORT", "6080"))
        self.version = self._load_version()
        self.stop_event = threading.Event()
        self.update_thread: Optional[threading.Thread] = None

    def _load_version(self) -> str:
        try:
            with open("/VERSION", "r") as f:
                return f.read().strip()
        except Exception:
            return "unknown"

    def _get_ip(self) -> str:
        try:
            # Standard way to get the primary IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.settimeout(0)
            try:
                # doesn't even have to be reachable
                s.connect(('10.254.254.254', 1))
                ip = s.getsockname()[0]
            except Exception:
                ip = socket.gethostbyname(socket.gethostname())
            finally:
                s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def _list_active_exes(self) -> List[str]:
        exes = set()
        try:
            for pid_str in os.listdir('/proc'):
                if not pid_str.isdigit():
                    continue
                try:
                    # In Wine, .exe processes often show up in /proc/PID/comm
                    with open(f'/proc/{pid_str}/comm', 'r') as f:
                        comm = f.read().strip()
                        if comm.endswith('.exe'):
                            exes.add(comm)
                except (FileNotFoundError, ProcessLookupError, PermissionError):
                    continue
        except Exception:
            pass
        return sorted(list(exes))

    def _get_txt_records(self) -> Dict[str, str]:
        ip = self._get_ip()
        active_apps = ",".join(self._list_active_exes())
        return {
            "vnc_url": f"http://{ip}:{self.vnc_port}/vnc.html",
            "api_port": str(self.api_port),
            "version": self.version,
            "active_apps": active_apps
        }

    def _check_singleton(self):
        if self.allow_multiple:
            return

        print("--> Singleton mode enabled. Scanning for existing sessions...", flush=True)
        zc = Zeroconf(ip_version=IPVersion.V4Only)
        found_other = False

        def on_service_state_change(zeroconf, service_type, name, state_change):
            nonlocal found_other
            if state_change is ServiceStateChange.Added:
                print(f"--> Detected existing session: {name}", flush=True)
                found_other = True

        browser = ServiceBrowser(zc, SERVICE_TYPE, handlers=[on_service_state_change])
        time.sleep(5) # Give it time to discover
        zc.close()

        if found_other:
            print("--> ERROR: Another WineBot session detected! Aborting startup.", flush=True)
            logger.critical("Another WineBot session detected! Singleton mode (ALLOW_MULTIPLE_SESSIONS=False) prevents startup.")
            # Exit the process immediately
            os._exit(1)
        else:
            print("--> No existing sessions found. Proceeding.", flush=True)

    def start(self):
        print(f"--> Starting DiscoveryManager (ALLOW_MULTIPLE={self.allow_multiple})...")
        # Run the actual startup in a thread to avoid blocking the event loop
        # and to avoid zeroconf's check for being in an event loop.
        threading.Thread(target=self._start_internal, daemon=True).start()

    def _start_internal(self):
        try:
            self._check_singleton()

            self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
            
            base_name = f"WineBot-Session-{self.session_id}"
            name = f"{base_name}.{SERVICE_TYPE}"
            
            # Collision handling
            suffix = 1
            while True:
                # ServiceInfo expects name to be unique on the network
                # We probe by checking if name already exists
                info = self.zeroconf.get_service_info(SERVICE_TYPE, name)
                if info is None:
                    break
                suffix += 1
                name = f"{base_name}-{suffix}.{SERVICE_TYPE}"

            print(f"--> Registering mDNS service: {name}")
            
            ip = self._get_ip()
            print(f"--> Discovery IP: {ip}")
            self.service_info = ServiceInfo(
                SERVICE_TYPE,
                name,
                addresses=[socket.inet_aton(ip)],
                port=self.api_port,
                properties=self._get_txt_records(),
                server=f"{socket.gethostname()}.local."
            )
            
            self.zeroconf.register_service(self.service_info)
            print(f"--> mDNS service registered successfully.")
            
            # Start dynamic update thread
            self.update_thread = threading.Thread(target=self._update_loop, daemon=True)
            self.update_thread.start()
        except Exception as e:
            print(f"--> Discovery background startup failed: {e}")
            logger.error(f"Discovery background startup failed: {e}")

    def _update_loop(self):
        while not self.stop_event.is_set():
            time.sleep(10) # Refresh every 10 seconds
            if self.zeroconf and self.service_info:
                new_properties = self._get_txt_records()
                if new_properties != self.service_info.properties:
                    # Update service
                    # Zeroconf update_service is often achieved by unregister/register or using update_record
                    # For ServiceInfo properties, we re-register or use update_record if supported by the version
                    # Standard way in python-zeroconf to update TXT is updating the info and calling update_service
                    self.service_info.properties = new_properties
                    try:
                        self.zeroconf.update_service(self.service_info)
                    except Exception as e:
                        logger.error(f"Failed to update mDNS service: {e}")

    def stop(self):
        self.stop_event.set()
        if self.zeroconf:
            if self.service_info:
                logger.info(f"Unregistering mDNS service: {self.service_info.name}")
                self.zeroconf.unregister_service(self.service_info)
            self.zeroconf.close()
            self.zeroconf = None

discovery_manager = DiscoveryManager()
