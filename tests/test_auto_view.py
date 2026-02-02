import os
import socket
import subprocess
import tempfile

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "auto-view.sh")


def run_script(args, env=None):
    env_vars = os.environ.copy()
    if env:
        env_vars.update(env)
    return subprocess.run([SCRIPT] + args, env=env_vars, capture_output=True, text=True)


def _run_with_stub(args):
    with tempfile.TemporaryDirectory() as tmp:
        url_out = os.path.join(tmp, "url.txt")
        stub = os.path.join(tmp, "xdg-open")
        with open(stub, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write('echo "$1" > "$URL_OUT"\n')
            f.write("exit 0\n")
        os.chmod(stub, 0o755)

        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]

        env = {
            "PATH": tmp + os.pathsep + os.environ.get("PATH", ""),
            "URL_OUT": url_out,
        }
        result = run_script(
            args
            + [
                "--vnc-host",
                "127.0.0.1",
                "--vnc-port",
                str(port),
                "--timeout",
                "5",
            ],
            env=env,
        )
        server.close()

        url = ""
        if os.path.exists(url_out):
            with open(url_out, "r", encoding="utf-8") as f:
                url = f.read().strip()
        return result, url


def _run_with_vnc_stub(args):
    with tempfile.TemporaryDirectory() as tmp:
        args_out = os.path.join(tmp, "args.txt")
        stub_viewer = os.path.join(tmp, "vncviewer")
        stub_passwd = os.path.join(tmp, "vncpasswd")
        with open(stub_viewer, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write('echo "$@" > "$ARGS_OUT"\n')
            f.write("exit 0\n")
        with open(stub_passwd, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write("cat >/dev/null\n")
            f.write("echo fake\n")
            f.write("exit 0\n")
        os.chmod(stub_viewer, 0o755)
        os.chmod(stub_passwd, 0o755)

        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]

        env = {
            "PATH": tmp + os.pathsep + os.environ.get("PATH", ""),
            "ARGS_OUT": args_out,
        }
        result = run_script(
            args
            + [
                "--vnc-host",
                "127.0.0.1",
                "--vnc-port",
                str(port),
                "--timeout",
                "5",
            ],
            env=env,
        )
        server.close()

        argv = ""
        if os.path.exists(args_out):
            with open(args_out, "r", encoding="utf-8") as f:
                argv = f.read().strip()
        return result, argv


def test_auto_view_help():
    result = run_script(["--help"])
    assert result.returncode == 0
    assert "Usage:" in result.stdout


def test_auto_view_embeds_password():
    result, url = _run_with_stub(
        [
            "--mode",
            "novnc",
            "--novnc-url",
            "http://localhost:6080/vnc.html?autoconnect=1",
            "--novnc-password",
            "pa ss",
        ]
    )
    assert result.returncode == 0
    assert "password=pa%20ss" in url


def test_auto_view_no_password_url_flag():
    result, url = _run_with_stub(
        [
            "--mode",
            "novnc",
            "--novnc-url",
            "http://localhost:6080/vnc.html?autoconnect=1",
            "--novnc-password",
            "secret",
            "--no-password-url",
        ]
    )
    assert result.returncode == 0
    assert "password=" not in url


def test_auto_view_vnc_password_uses_passfile():
    result, argv = _run_with_vnc_stub(
        [
            "--mode",
            "vnc",
            "--vnc-password",
            "secret",
        ]
    )
    assert result.returncode == 0
    assert "-passwd" in argv
