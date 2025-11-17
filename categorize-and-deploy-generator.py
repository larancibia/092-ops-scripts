#!/usr/bin/env python3
"""
Complete Deployment System Generator
Categorizes all 84 projects and generates deployment infrastructure
"""

import json
import os
from pathlib import Path
from collections import defaultdict

# Load data
with open('/home/luis/port-registry.json', 'r') as f:
    port_registry = json.load(f)

with open('/home/luis/scripts/project-analysis.json', 'r') as f:
    project_analysis = json.load(f)

SERVER_IP = "217.216.64.237"
ZONE = "guanacolabs.com"
PROJECTS_DIR = "/home/luis/projects"

# Categorization
categories = {
    "fullstack_web": [],  # Frontend + Backend + DB
    "backend_api": [],     # Backend API with DB
    "frontend_only": [],   # Frontend apps only
    "mcp_servers": [],     # MCP servers (landing page only)
    "cli_tools": [],       # CLI/Libraries (landing page only)
    "archived": [],        # Archived projects
    "unknown": []          # Needs manual review
}

resource_estimates = {
    "fullstack_web": {"ram_mb": 512, "cpu": 0.5},
    "backend_api": {"ram_mb": 256, "cpu": 0.25},
    "frontend_only": {"ram_mb": 128, "cpu": 0.1},
    "mcp_servers": {"ram_mb": 64, "cpu": 0.05},
    "cli_tools": {"ram_mb": 64, "cpu": 0.05},
    "archived": {"ram_mb": 64, "cpu": 0.05},
}

# Database sharing strategy (to reduce resource usage)
shared_databases = {
    "postgres_main": {"port": 5432, "projects": []},
    "postgres_ai": {"port": 5433, "projects": []},
    "postgres_finance": {"port": 5434, "projects": []},
    "redis_main": {"port": 6379, "projects": []},
    "redis_ai": {"port": 6380, "projects": []},
}

def categorize_project(name, analysis, port_info):
    """Categorize a single project based on its characteristics"""

    # Check if archived
    if port_info.get("status") == "archived":
        return "archived"

    tech = analysis.get("tech_stack", "unknown")
    proj_type = analysis.get("project_type", "unknown")
    needs_db = analysis.get("needs_postgres", False)
    needs_redis = analysis.get("needs_redis", False)

    # MCP Servers (from port registry categories)
    mcp_keywords = ["mcp-", "VaultConnect", "VaultPro", "MailBridge", "ScribeBridge", "ArchiveBridge", "WhatsGuard"]
    if any(kw in name or kw in port_info.get("original_name", "") for kw in mcp_keywords):
        return "mcp_servers"

    # CLI/Tools/Libraries
    if proj_type == "cli" or tech == "rust" and proj_type == "cli":
        return "cli_tools"

    # Full-stack (has both frontend and backend characteristics or needs DB)
    if (tech in ["next.js", "react", "vue"] and needs_db) or \
       (proj_type == "frontend" and needs_db):
        return "fullstack_web"

    # Backend API
    if proj_type == "backend" or tech in ["express", "fastapi", "java", "go"]:
        return "backend_api"

    # Frontend only
    if proj_type == "frontend" or tech in ["next.js", "react", "vue"]:
        return "frontend_only"

    # Unknown
    if tech == "unknown" or proj_type == "unknown":
        # Check if has docker-compose (likely deployable)
        if analysis.get("has_docker_compose", False):
            return "fullstack_web"  # Assume fullstack if has docker-compose
        return "unknown"

    return "unknown"

# Categorize all projects
deployment_plan = {}

for project_name, port_info in port_registry["allocated"].items():
    original_name = port_info["original_name"]
    analysis = project_analysis["projects"].get(project_name, {})

    category = categorize_project(project_name, analysis, port_info)
    categories[category].append(project_name)

    deployment_plan[project_name] = {
        "original_name": original_name,
        "category": category,
        "priority": port_info.get("priority", "low"),
        "status": port_info.get("status", "reserved"),
        "ports": {
            "frontend": port_info.get("frontend"),
            "backend": port_info.get("backend"),
            "database": port_info.get("database"),
            "redis": port_info.get("redis"),
        },
        "tech_stack": analysis.get("tech_stack", "unknown"),
        "project_type": analysis.get("project_type", "unknown"),
        "needs_postgres": analysis.get("needs_postgres", False),
        "needs_redis": analysis.get("needs_redis", False),
        "has_dockerfile": analysis.get("has_dockerfile", False),
        "has_docker_compose": analysis.get("has_docker_compose", False),
        "subdomains": {
            "main": f"{original_name}.{ZONE}",
            "api": f"api.{original_name}.{ZONE}",
            "landing": f"landing.{original_name}.{ZONE}",
        },
        "resource_estimate": resource_estimates.get(category, resource_estimates["cli_tools"]),
    }

    # Assign to shared database if needed
    if analysis.get("needs_postgres", False):
        if port_info.get("category") == "AI & Machine Learning":
            shared_databases["postgres_ai"]["projects"].append(project_name)
        elif port_info.get("category") == "Finance & Trading":
            shared_databases["postgres_finance"]["projects"].append(project_name)
        else:
            shared_databases["postgres_main"]["projects"].append(project_name)

    if analysis.get("needs_redis", False):
        if port_info.get("category") == "AI & Machine Learning":
            shared_databases["redis_ai"]["projects"].append(project_name)
        else:
            shared_databases["redis_main"]["projects"].append(project_name)

# Calculate totals
total_resources = defaultdict(lambda: {"ram_mb": 0, "cpu": 0.0, "count": 0})
for name, plan in deployment_plan.items():
    cat = plan["category"]
    res = plan["resource_estimate"]
    total_resources[cat]["ram_mb"] += res["ram_mb"]
    total_resources[cat]["cpu"] += res["cpu"]
    total_resources[cat]["count"] += 1

# Save categorization
output = {
    "generated_at": "2025-11-17",
    "server_ip": SERVER_IP,
    "zone": ZONE,
    "summary": {
        "total_projects": len(deployment_plan),
        "by_category": {cat: len(projs) for cat, projs in categories.items()},
        "total_ram_mb": sum(r["ram_mb"] for r in total_resources.values()),
        "total_ram_gb": round(sum(r["ram_mb"] for r in total_resources.values()) / 1024, 2),
        "total_cpu_cores": round(sum(r["cpu"] for r in total_resources.values()), 2),
    },
    "categories": categories,
    "deployment_plan": deployment_plan,
    "resource_breakdown": dict(total_resources),
    "shared_databases": shared_databases,
}

with open('/home/luis/scripts/deployment-categorization.json', 'w') as f:
    json.dump(output, f, indent=2)

print("=" * 80)
print("PROJECT CATEGORIZATION COMPLETE")
print("=" * 80)
print(f"\nTotal Projects: {len(deployment_plan)}")
print("\nBreakdown by Category:")
for cat, projs in categories.items():
    count = len(projs)
    if count > 0:
        ram = total_resources[cat]["ram_mb"]
        cpu = total_resources[cat]["cpu"]
        print(f"  {cat:20s}: {count:2d} projects | {ram:6.0f} MB RAM | {cpu:5.2f} CPU cores")

print(f"\nTotal Resource Requirements:")
print(f"  RAM: {output['summary']['total_ram_gb']} GB")
print(f"  CPU: {output['summary']['total_cpu_cores']} cores")

print(f"\nShared Database Strategy:")
for db_name, db_info in shared_databases.items():
    proj_count = len(db_info["projects"])
    if proj_count > 0:
        print(f"  {db_name:20s}: {proj_count} projects sharing port {db_info['port']}")

print(f"\nOutput saved to: /home/luis/scripts/deployment-categorization.json")
print("=" * 80)
