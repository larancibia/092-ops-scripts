#!/usr/bin/env python3
import os
import shutil
import sys
import json

TEMPLATES_DIR = "/home/luis/projects/ops-scripts/templates"
START_SH_TEMPLATE = os.path.join(TEMPLATES_DIR, "start.sh")

LOG_FILE = "/home/luis/projects/MIGRATION_LOG.txt"

def log(message):
    formatted = f"[MIGRATION] {message}"
    print(formatted)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(formatted + "\n")
    except Exception:
        pass

def ensure_executable(path):
    mode = os.stat(path).st_mode
    mode |= (mode & 0o444) >> 2    # copy R bits to X
    os.chmod(path, mode)

def setup_start_script(directory):
    target_path = os.path.join(directory, "start.sh")
    if not os.path.exists(target_path):
        log(f"Creating start.sh in {directory}")
        shutil.copy(START_SH_TEMPLATE, target_path)
        ensure_executable(target_path)
    else:
        log(f"start.sh already exists in {directory}, skipping overwrite.")

def process_project(project_path):
    project_name = os.path.basename(project_path)
    log(f"Processing {project_name}...")

    # 1. Define Standard Structure
    structure = [
        "landing",
        "web",
        "backend",
        "academy/web",
        "academy/backend",
        "infra"
    ]

    # 2. Create missing directories (just the top level ones if we have content to move, 
    # or if we are strictly enforcing structure. For now, we create them if they might be needed 
    # or ensure they exist if we see evidence).
    # Actually, user said "todos deben tener la siguiente estructura". 
    # So we should force create them? Maybe empty folders are clutter. 
    # Let's only create if we have something to put in or if it's critical.
    # User said: "todos deben tener la siguiente estructura". I will create them.
    
    for folder in structure:
        full_path = os.path.join(project_path, folder)
        os.makedirs(full_path, exist_ok=True)

    # 3. Check sub-components and add start.sh
    # We look into the folders we just ensured exist.
    # If they are empty, maybe we add a README placeholder?
    
    components = ["landing", "web", "backend", "academy/web", "academy/backend"]
    for component in components:
        comp_path = os.path.join(project_path, component)
        
        # Only add start.sh if there is code there, OR if it's a required empty shell.
        # But user wants start.sh to lift it. An empty start.sh might fail.
        # Let's check if there are files in it.
        if os.listdir(comp_path):
            setup_start_script(comp_path)
        else:
            # Create a placeholder so it's not just an empty void
            with open(os.path.join(comp_path, ".keep"), "w") as f:
                f.write("")

    # 4. Infra Setup
    infra_path = os.path.join(project_path, "infra")
    docker_compose_path = os.path.join(infra_path, "docker-compose.yml")
    if not os.path.exists(docker_compose_path):
        # Create a basic dummy compose
        with open(docker_compose_path, "w") as f:
            f.write("version: '3.8'\nservices:\n  # Defined in subfolders\n")

    # 5. .env Setup
    env_path = os.path.join(project_path, ".env")
    if not os.path.exists(env_path):
        with open(env_path, "w") as f:
            f.write(f"PROJECT_NAME={project_name}\nENV=development\n")

    # 6. README Check
    readme_path = os.path.join(project_path, "README.md")
    if not os.path.exists(readme_path):
        with open(readme_path, "w") as f:
            f.write(f"# {project_name}\n\nManaged by Guanaco Deployment System.\n\n## API Keys\nRequired keys (encrypted via SOPS):\n- ...\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python migrate_project.py <project_path>")
        sys.exit(1)
    
    target_project = sys.argv[1]
    if os.path.exists(target_project):
        process_project(target_project)
    else:
        print(f"Path not found: {target_project}")
