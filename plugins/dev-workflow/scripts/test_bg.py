#!/usr/bin/env python3
"""Checks bg.sh: a finished command, a still-running one, and one that dies without an exit code."""
import os, shutil, subprocess, sys, time

B = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bg.sh")
R = "/tmp/dwc-bgtest"
shutil.rmtree(R, ignore_errors=True)
fails = []
def expect(name, cond, out=""):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        print(out); fails.append(name)

subprocess.Popen(["bash", B, "run", R + "/a", "--", "bash", "-c", "echo building; sleep 2; echo green; exit 3"])
out = subprocess.run(["bash", B, "wait", R + "/a", "30"], capture_output=True, text=True).stdout
expect("wait: reports the exit code and the output tail", "exit code 3" in out and "green" in out, out)

subprocess.Popen(["bash", B, "run", R + "/b", "--", "sleep", "20"])
time.sleep(0.5)
out = subprocess.run(["bash", B, "wait", R + "/b", "5"], capture_output=True, text=True).stdout
expect("wait: returns within its limit when still running", "still running" in out, out)

p = subprocess.Popen(["bash", B, "run", R + "/c", "--", "sleep", "30"])
time.sleep(0.5)
p.kill()
p.wait()  # reap it, as the harness would; an unreaped zombie still answers kill -0
out = subprocess.run(["bash", B, "wait", R + "/c", "30"], capture_output=True, text=True).stdout
expect("wait: notices a command that died without an exit code", "died" in out, out)
print("all passed" if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
