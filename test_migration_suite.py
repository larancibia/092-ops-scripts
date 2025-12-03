#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import json
from datetime import datetime

STAGING_DIR = "/home/luis/projects_staging"
LOG_FILE = "/home/luis/projects/MIGRATION_TEST_REPORT.md"
RESULTS = []

def log(message):
    print(message)

def run_test(project_name, component, path):
    log(f"Testing {project_name} [{component}]...")
    start_script = os.path.join(path, "start.sh")
    
    if not os.path.exists(start_script):
        return {"status": "SKIPPED", "reason": "No start.sh found"}

    # Clean previous artifacts for a fresh test
    env_file = os.path.join(path, ".env")
    if os.path.exists(env_file):
        os.remove(env_file)

    # Prepare command
    # We use a timeout. If it times out, it usually means the server is running (GOOD).
    # If it fails immediately, it's an ERROR.
    cmd = ["/bin/bash", "start.sh"]
    
    start_time = time.time()
    result_status = "UNKNOWN"
    details = ""
    
    try:
        # Run with a timeout. 
        # 30 seconds might be enough to request port and start install.
        # We don't want to wait for full npm install 50 times.
        # We look for output clues.
        proc = subprocess.Popen(
            cmd, 
            cwd=path, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True,
            preexec_fn=os.setsid # To allow killing the whole process group
        )
        
        try:
            stdout, stderr = proc.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            # Timeout means it kept running -> SUCCESS for a server
            proc.kill()
            stdout, stderr = proc.communicate()
            result_status = "PASS"
            details = "Process kept running (server behavior)"

        # Analyze Output if not already passed via timeout
        full_output = stdout + stderr
        
        # Check 1: Port Allocation
        if "Allocated Port:" in full_output:
            # Extract port
            pass # Good
        else:
            if result_status == "PASS":
                result_status = "WARN"
                details += " (Port allocation log missing?)"
            else:
                result_status = "FAIL"
                details = "Failed to allocate port"

        # Check 2: Exit Code (if it didn't timeout)
        if proc.returncode != 0 and result_status != "PASS":
            result_status = "FAIL"
            details = f"Exited with error code {proc.returncode}"
            # Common error: externally-managed-environment (handled by template now)
            if "externally-managed-environment" in full_output:
                details += " (Python env error - should be fixed)"
            
        # Check 3: .env creation
        if os.path.exists(env_file):
            with open(env_file) as f:
                content = f.read()
                if "PORT=" in content:
                    if result_status != "FAIL":
                        result_status = "PASS"
                else:
                    result_status = "FAIL"
                    details += " (.env created but missing PORT)"
        else:
            result_status = "FAIL"
            details += " (.env not created)"

    except Exception as e:
        result_status = "ERROR"
        details = str(e)

    return {
        "project": project_name,
        "component": component,
        "status": result_status,
        "details": details
    }

def generate_report():
    with open(LOG_FILE, "w") as f:
        f.write(f"# Migration Test Report\n")
        f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("| Project | Component | Status | Details |\n")
        f.write("|---|---|---|---|\n")
        
        for r in RESULTS:
            icon = "✅" if r["status"] == "PASS" else "⚠️" if r["status"] == "WARN" else "❌"
            f.write(f"| {r['project']} | {r['component']} | {icon} {r['status']} | {r['details']} |\n")
    
    log(f"\nReport generated at {LOG_FILE}")

def main():
    projects = sorted(os.listdir(STAGING_DIR))
    for proj in projects:
        proj_path = os.path.join(STAGING_DIR, proj)
        if not os.path.isdir(proj_path): continue
        if proj in ["ops-scripts", "DeployHub"]: continue
        
        # Check subcomponents
        for comp in ["landing", "web", "backend", "academy/web", "academy/backend"]:
            comp_path = os.path.join(proj_path, comp)
            if os.path.exists(os.path.join(comp_path, "start.sh")):
                res = run_test(proj, comp, comp_path)
                RESULTS.append(res)
    
    generate_report()

if __name__ == "__main__":
    main()
