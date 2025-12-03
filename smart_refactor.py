#!/usr/bin/env python3
import os
import shutil
import sys

STAGING_DIR = "/home/luis/projects_staging"
LOG_FILE = "/home/luis/projects/MIGRATION_LOG.txt"

def log(msg):
    print(msg)
    with open(LOG_FILE, "a") as f:
        f.write(f"[REFACTOR] {msg}\n")

def move_file(src, dest_folder):
    if not os.path.exists(src):
        return
    dest = os.path.join(dest_folder, os.path.basename(src))
    # Ensure dest folder exists
    os.makedirs(dest_folder, exist_ok=True)
    try:
        shutil.move(src, dest)
        # log(f"Moved {os.path.basename(src)} -> {os.path.basename(dest_folder)}")
    except Exception as e:
        log(f"Error moving {src}: {e}")

def identify_and_move(project_path):
    project_name = os.path.basename(project_path)
    log(f"Refactoring {project_name}...")

    # Define paths
    landing_path = os.path.join(project_path, "landing")
    web_path = os.path.join(project_path, "web")
    backend_path = os.path.join(project_path, "backend")
    infra_path = os.path.join(project_path, "infra")
    
    # Ensure structures exist
    for p in [landing_path, web_path, backend_path, infra_path]:
        os.makedirs(p, exist_ok=True)

    # 1. Move Infra Files
    infra_files = ["Dockerfile", "docker-compose.yml", "docker-compose.dev.yml", "docker-compose.prod.yml", "Makefile", ".dockerignore"]
    for f in infra_files:
        move_file(os.path.join(project_path, f), infra_path)
    
    # 2. Analyze for Code
    # Get list of files in root (excluding the folders we just made/kept)
    root_items = [i for i in os.listdir(project_path) if i not in ["landing", "web", "backend", "infra", "academy", ".git", "node_modules", "venv"]]
    
    is_node = "package.json" in root_items
    is_python = "requirements.txt" in root_items or "main.py" in root_items or "app.py" in root_items
    
    # Heuristic: If it looks like a create-react-app or nextjs, it goes to web.
    # If it looks like express/python, it goes to backend.
    
    target_dir = None
    
    if is_node:
        # Read package.json to guess
        try:
            with open(os.path.join(project_path, "package.json")) as f:
                content = f.read().lower()
                if "react" in content or "next" in content or "vue" in content:
                    target_dir = web_path
                    log(f"  -> Detected Frontend (React/Next/Vue)")
                else:
                    target_dir = backend_path
                    log(f"  -> Detected Backend (Node Generic)")
        except:
            target_dir = backend_path
    elif is_python:
        target_dir = backend_path
        log(f"  -> Detected Backend (Python)")
    
    # If we found a target, move the source files there
    if target_dir:
        code_files = [
            "src", "public", "app", "components", "pages", "lib", "utils", # Folders
            "package.json", "package-lock.json", "tsconfig.json", "next.config.js", "vite.config.js", "webpack.config.js", # Configs
            "requirements.txt", "main.py", "app.py", "manage.py", "Pipfile", "pyproject.toml", # Python
            ".env", ".env.example" # Env files often stay in root or go to infra? User said "projects consume .env". Let's put copy in backend/web or keep in root?
            # Usually .env is per service in this structure. I will move it to the service.
        ]
        
        # Move everything that isn't our main structure folders
        for item in root_items:
            # Move almost everything remaining in root to the target
            # BUT be careful not to move 'docs' or 'scripts' if they are general project level.
            # For now, let's move known code assets.
            src = os.path.join(project_path, item)
            if item in code_files or item.endswith(".js") or item.endswith(".ts") or item.endswith(".py") or item.endswith(".json") or item.endswith(".html") or item == "src":
                if os.path.isdir(src) or os.path.isfile(src):
                    move_file(src, target_dir)

    # 3. Clean up empty folders if we created them unnecessarily? 
    # User wanted the structure enforced, so we keep them even if empty.
    
    # 4. Setup standard start scripts (using the logic from before, but now pointing to the real files)
    # (We can reuse the migrate_project logic or just call it here)

def run():
    # List all dirs in staging
    projects = [d for d in os.listdir(STAGING_DIR) if os.path.isdir(os.path.join(STAGING_DIR, d))]
    for proj in projects:
        if proj in ["ops-scripts", "DeployHub"]: continue # Skip infra tools
        identify_and_move(os.path.join(STAGING_DIR, proj))

if __name__ == "__main__":
    run()
