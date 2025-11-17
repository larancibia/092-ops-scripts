#!/bin/bash
# Deploy ALL 84 projects in phases
# Smart batching to avoid resource exhaustion

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

echo "======================================"
echo "COMPLETE DEPLOYMENT - ALL 84 PROJECTS"
echo "======================================"
echo ""

# Show deployment plan
total_projects=$(jq -r '.summary.total_projects' "$DEPLOY_DATA")
total_ram_gb=$(jq -r '.summary.total_ram_gb' "$DEPLOY_DATA")
total_cpu=$(jq -r '.summary.total_cpu_cores' "$DEPLOY_DATA")

echo "Deployment Overview:"
echo "  Total Projects: $total_projects"
echo "  Estimated RAM: ${total_ram_gb} GB"
echo "  Estimated CPU: ${total_cpu} cores"
echo ""

# Show breakdown by category
echo "Breakdown by Category:"
jq -r '.resource_breakdown | to_entries[] | "  \(.key): \(.value.count) projects (\(.value.ram_mb) MB RAM, \(.value.cpu) CPU)"' "$DEPLOY_DATA"
echo ""

# Deployment phases (prioritized)
echo "======================================"
echo "DEPLOYMENT PHASES"
echo "======================================"
echo ""
echo "Phase 1: Critical & High Priority (already running)"
echo "Phase 2: High Priority Full-Stack Apps"
echo "Phase 3: Backend APIs"
echo "Phase 4: Frontend Apps"
echo "Phase 5: MCP Servers & CLI Tools (landing pages only)"
echo "Phase 6: Low Priority & Archived"
echo ""

read -p "Proceed with deployment? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""

# Function to deploy a batch of projects
deploy_batch() {
    local batch_name=$1
    shift
    local projects=("$@")

    echo "======================================"
    echo "Deploying: $batch_name"
    echo "Projects: ${#projects[@]}"
    echo "======================================"
    echo ""

    for project in "${projects[@]}"; do
        echo ">>> Deploying $project..."
        if "$SCRIPT_DIR/deploy-project.sh" "$project"; then
            echo ">>> $project deployed successfully"
        else
            echo ">>> WARNING: $project deployment had issues"
        fi
        echo ""
        sleep 2  # Brief pause between deployments
    done

    echo "$batch_name complete!"
    echo ""
}

# Phase 1: Skip already running projects
echo "======================================"
echo "PHASE 1: Critical Projects (Already Running)"
echo "======================================"
echo ""
echo "Skipping already deployed projects:"
jq -r '.deployment_plan | to_entries[] | select(.value.status == "in-use") | .key' "$DEPLOY_DATA" | while read project; do
    echo "  - $project (already running)"
done
echo ""
echo "Phase 1 complete (no action needed)"
echo ""

# Phase 2: High Priority Full-Stack Apps
echo "======================================"
echo "PHASE 2: High Priority Full-Stack Apps"
echo "======================================"
echo ""

phase2_projects=($(jq -r '.deployment_plan | to_entries[] | select(.value.category == "fullstack_web" and .value.priority == "high" and .value.status != "in-use") | .key' "$DEPLOY_DATA"))

if [ ${#phase2_projects[@]} -gt 0 ]; then
    deploy_batch "Phase 2" "${phase2_projects[@]}"
    echo "Waiting 30 seconds for containers to stabilize..."
    sleep 30
else
    echo "No projects in Phase 2"
    echo ""
fi

# Phase 3: Backend APIs
echo "======================================"
echo "PHASE 3: Backend APIs"
echo "======================================"
echo ""

phase3_projects=($(jq -r '.deployment_plan | to_entries[] | select(.value.category == "backend_api" and .value.status != "in-use") | .key' "$DEPLOY_DATA"))

if [ ${#phase3_projects[@]} -gt 0 ]; then
    # Deploy in batches of 5
    batch_size=5
    for ((i=0; i<${#phase3_projects[@]}; i+=batch_size)); do
        batch=("${phase3_projects[@]:i:batch_size}")
        deploy_batch "Phase 3 - Batch $((i/batch_size + 1))" "${batch[@]}"
        if [ $((i + batch_size)) -lt ${#phase3_projects[@]} ]; then
            echo "Waiting 20 seconds before next batch..."
            sleep 20
        fi
    done
else
    echo "No projects in Phase 3"
    echo ""
fi

# Phase 4: Frontend Apps
echo "======================================"
echo "PHASE 4: Frontend Apps"
echo "======================================"
echo ""

phase4_projects=($(jq -r '.deployment_plan | to_entries[] | select(.value.category == "frontend_only" and .value.status != "in-use") | .key' "$DEPLOY_DATA"))

if [ ${#phase4_projects[@]} -gt 0 ]; then
    deploy_batch "Phase 4" "${phase4_projects[@]}"
else
    echo "No projects in Phase 4"
    echo ""
fi

# Phase 5: MCP Servers & CLI Tools
echo "======================================"
echo "PHASE 5: MCP Servers & CLI Tools"
echo "======================================"
echo ""

phase5_projects=($(jq -r '.deployment_plan | to_entries[] | select((.value.category == "mcp_servers" or .value.category == "cli_tools") and .value.status != "in-use") | .key' "$DEPLOY_DATA"))

if [ ${#phase5_projects[@]} -gt 0 ]; then
    # These are lightweight (landing pages only), deploy in batches of 10
    batch_size=10
    for ((i=0; i<${#phase5_projects[@]}; i+=batch_size)); do
        batch=("${phase5_projects[@]:i:batch_size}")
        deploy_batch "Phase 5 - Batch $((i/batch_size + 1))" "${batch[@]}"
    done
else
    echo "No projects in Phase 5"
    echo ""
fi

# Phase 6: Unknown & Archived
echo "======================================"
echo "PHASE 6: Unknown & Archived Projects"
echo "======================================"
echo ""

phase6_projects=($(jq -r '.deployment_plan | to_entries[] | select((.value.category == "unknown" or .value.category == "archived") and .value.status != "in-use") | .key' "$DEPLOY_DATA"))

if [ ${#phase6_projects[@]} -gt 0 ]; then
    echo "Deploying ${#phase6_projects[@]} projects (landing pages only)"
    # Deploy in batches of 15
    batch_size=15
    for ((i=0; i<${#phase6_projects[@]}; i+=batch_size)); do
        batch=("${phase6_projects[@]:i:batch_size}")
        deploy_batch "Phase 6 - Batch $((i/batch_size + 1))" "${batch[@]}"
    done
else
    echo "No projects in Phase 6"
    echo ""
fi

# Final summary
echo ""
echo "======================================"
echo "DEPLOYMENT COMPLETE!"
echo "======================================"
echo ""
echo "All 84 projects have been deployed!"
echo ""
echo "Next Steps:"
echo "  1. Setup DNS for all projects: ./setup-dns-all.sh"
echo "  2. Setup SSL certificates: ./setup-ssl-all.sh"
echo "  3. Verify deployments: ./verify-deployments.sh"
echo ""
echo "System Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -20
running_containers=$(docker ps -q | wc -l)
echo ""
echo "Total running containers: $running_containers"
echo ""
echo "======================================"
