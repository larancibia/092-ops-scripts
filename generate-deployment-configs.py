#!/usr/bin/env python3
"""
Generate deployment configurations for all 84 projects
Creates: Dockerfiles, docker-compose.yml, nginx configs, startup scripts
"""

import json
import os
from pathlib import Path

# Load deployment plan
with open('/home/luis/scripts/deployment-categorization.json', 'r') as f:
    deploy_data = json.load(f)

SERVER_IP = deploy_data["server_ip"]
ZONE = deploy_data["zone"]
PROJECTS_DIR = "/home/luis/projects"
DEPLOY_CONFIGS_DIR = "/home/luis/deployment-configs"

# Create base directories
Path(DEPLOY_CONFIGS_DIR).mkdir(exist_ok=True)

def generate_nginx_config(project_name, plan):
    """Generate nginx configuration for a project"""
    original_name = plan["original_name"]
    category = plan["category"]
    ports = plan["ports"]
    subdomains = plan["subdomains"]

    configs = []

    # Main domain config
    if category in ["fullstack_web", "frontend_only"]:
        config = f"""# Nginx config for {project_name}
server {{
    listen 80;
    server_name {subdomains['main']};

    location / {{
        proxy_pass http://127.0.0.1:{ports['frontend']};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""
        configs.append(("main", config))

    # API subdomain config
    if category in ["fullstack_web", "backend_api"]:
        config = f"""# Nginx API config for {project_name}
server {{
    listen 80;
    server_name {subdomains['api']};

    location / {{
        proxy_pass http://127.0.0.1:{ports['backend']};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""
        configs.append(("api", config))

    # Landing page (all projects get one)
    landing_config = f"""# Nginx landing page config for {project_name}
server {{
    listen 80;
    server_name {subdomains['landing']};

    root /var/www/landing-pages/{original_name};
    index index.html;

    location / {{
        try_files $uri $uri/ =404;
    }}
}}
"""
    configs.append(("landing", landing_config))

    return configs

def generate_docker_compose(project_name, plan):
    """Generate docker-compose.yml for a project"""
    original_name = plan["original_name"]
    category = plan["category"]
    ports = plan["ports"]
    tech = plan["tech_stack"]
    needs_pg = plan["needs_postgres"]
    needs_redis = plan["needs_redis"]

    # For MCP/CLI tools, we only deploy landing page
    if category in ["mcp_servers", "cli_tools", "archived"]:
        return None  # No docker-compose needed, only landing page

    services = {}

    # Frontend service
    if category in ["fullstack_web", "frontend_only"]:
        if tech == "next.js":
            services["frontend"] = {
                "build": f"{PROJECTS_DIR}/{project_name}",
                "ports": [f"{ports['frontend']}:3000"],
                "environment": [
                    "NODE_ENV=production",
                    f"NEXT_PUBLIC_API_URL=https://{plan['subdomains']['api']}",
                ],
                "restart": "unless-stopped",
            }
        elif tech in ["react", "vue"]:
            services["frontend"] = {
                "build": {
                    "context": f"{PROJECTS_DIR}/{project_name}",
                    "dockerfile": "Dockerfile",
                },
                "ports": [f"{ports['frontend']}:80"],
                "restart": "unless-stopped",
            }

    # Backend service
    if category in ["fullstack_web", "backend_api"]:
        env_vars = []

        if tech in ["python", "fastapi"]:
            services["backend"] = {
                "build": f"{PROJECTS_DIR}/{project_name}",
                "ports": [f"{ports['backend']}:8000"],
                "environment": env_vars,
                "restart": "unless-stopped",
            }
        elif tech in ["express", "node.js"]:
            services["backend"] = {
                "build": f"{PROJECTS_DIR}/{project_name}",
                "ports": [f"{ports['backend']}:8000"],
                "environment": env_vars,
                "restart": "unless-stopped",
            }
        elif tech == "java":
            services["backend"] = {
                "build": f"{PROJECTS_DIR}/{project_name}",
                "ports": [f"{ports['backend']}:8080"],
                "environment": env_vars,
                "restart": "unless-stopped",
            }

    # Note: We're using shared databases, so DB connection strings will point to shared instances
    # No need to create individual DB containers for each project

    if len(services) == 0:
        return None

    compose = {
        "version": "3.8",
        "services": services,
    }

    import yaml
    try:
        compose_yaml = yaml.dump(compose, default_flow_style=False, sort_keys=False)
    except:
        # Fallback to JSON if yaml not available
        compose_yaml = json.dumps(compose, indent=2)

    return compose_yaml

def generate_dockerfile(project_name, plan):
    """Generate Dockerfile if project doesn't have one"""
    original_name = plan["original_name"]
    tech = plan["tech_stack"]
    project_path = Path(PROJECTS_DIR) / project_name

    # Skip if dockerfile exists
    if (project_path / "Dockerfile").exists():
        return None

    # Skip for MCP/CLI
    if plan["category"] in ["mcp_servers", "cli_tools", "archived", "unknown"]:
        return None

    dockerfile = ""

    if tech == "next.js":
        dockerfile = """FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
"""
    elif tech in ["react", "vue"]:
        dockerfile = """FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
"""
    elif tech in ["python", "fastapi"]:
        dockerfile = """FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
"""
    elif tech in ["express", "node.js"]:
        dockerfile = """FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8000
CMD ["node", "index.js"]
"""
    elif tech == "java":
        dockerfile = """FROM maven:3.8-openjdk-17 as build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:17-slim
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
"""

    return dockerfile if dockerfile else None

# Generate all configs
print("Generating deployment configurations for all projects...\n")

configs_generated = {
    "nginx": 0,
    "docker_compose": 0,
    "dockerfile": 0,
}

for project_name, plan in deploy_data["deployment_plan"].items():
    project_dir = Path(DEPLOY_CONFIGS_DIR) / project_name
    project_dir.mkdir(exist_ok=True)

    # Generate nginx configs
    nginx_configs = generate_nginx_config(project_name, plan)
    for config_type, config_content in nginx_configs:
        nginx_file = project_dir / f"nginx-{config_type}.conf"
        nginx_file.write_text(config_content)
        configs_generated["nginx"] += 1

    # Generate docker-compose
    compose = generate_docker_compose(project_name, plan)
    if compose:
        compose_file = project_dir / "docker-compose.yml"
        compose_file.write_text(compose)
        configs_generated["docker_compose"] += 1

    # Generate Dockerfile
    dockerfile = generate_dockerfile(project_name, plan)
    if dockerfile:
        dockerfile_path = project_dir / "Dockerfile.generated"
        dockerfile_path.write_text(dockerfile)
        configs_generated["dockerfile"] += 1

print(f"Configuration generation complete!")
print(f"  Nginx configs: {configs_generated['nginx']}")
print(f"  Docker Compose files: {configs_generated['docker_compose']}")
print(f"  Dockerfiles: {configs_generated['dockerfile']}")
print(f"\nAll configs saved to: {DEPLOY_CONFIGS_DIR}")
