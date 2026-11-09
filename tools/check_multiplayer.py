"""Run a real ENet host and two clients; fail on errors, nonzero exits or timeout."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="hearth-lan-") as directory:
    work = Path(directory)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    processes = []
    try:
        for role in ("host", "client1", "client2"):
            env = os.environ.copy()
            for kind in ("DATA", "CONFIG", "CACHE"):
                folder = work / role / kind.lower()
                folder.mkdir(parents=True)
                env[f"XDG_{kind}_HOME"] = str(folder)
            log = (work / f"{role}.log").open("w+")
            args = ["godot", "--headless", "--path", str(root), "--script",
                    "res://tests/multiplayer.gd", "--", f"--role={role}",
                    f"--port={port}", "--host" if role == "host" else "--join=127.0.0.1"]
            processes.append((role, subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT), log))
            if role == "host":
                time.sleep(0.5)
        deadline = time.monotonic() + 35
        failed = False
        for role, process, log in processes:
            try:
                process.wait(timeout=max(1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                failed = True
            log.seek(0)
            output = log.read()
            print(output, end="")
            failed |= process.returncode != 0 or "ERROR:" in output or f"MULTIPLAYER RESULT {role}: 0 failures" not in output
        raise SystemExit(1 if failed else 0)
    finally:
        for _, process, log in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
            log.close()
