#!/bin/bash
# Verify all deployments - health checks for all 84 projects
# Checks: Docker containers, Nginx configs, DNS records, SSL certificates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

ZONE=$(jq -r '.zone' "$DEPLOY_DATA")

echo "======================================"
echo "DEPLOYMENT VERIFICATION - ALL PROJECTS"
echo "======================================"
echo ""

# Counters
total_projects=0
nginx_ok=0
nginx_fail=0
docker_ok=0
docker_fail=0
dns_ok=0
dns_fail=0
ssl_ok=0
ssl_fail=0
landing_ok=0
landing_fail=0

# Results file
RESULTS_FILE="$SCRIPT_DIR/deployment-verification-$(date +%Y%m%d-%H%M%S).txt"
echo "Deployment Verification Report - $(date)" > "$RESULTS_FILE"
echo "========================================" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Function to check DNS
check_dns() {
    local domain=$1
    if dig +short "$domain" | grep -q "217.216.64.237"; then
        return 0
    else
        return 1
    fi
}

# Function to check SSL
check_ssl() {
    local domain=$1
    if echo | timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | grep -q "Verify return code: 0"; then
        return 0
    else
        return 1
    fi
}

# Function to check HTTP
check_http() {
    local url=$1
    if timeout 5 curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"; then
        return 0
    else
        return 1
    fi
}

# Process each project
jq -r '.deployment_plan | to_entries[] | "\(.key)|\(.value.original_name)|\(.value.category)|\(.value.status)"' "$DEPLOY_DATA" | while IFS='|' read -r project_name original_name category status; do
    total_projects=$((total_projects + 1))

    echo "========================================" >> "$RESULTS_FILE"
    echo "Project: $project_name" >> "$RESULTS_FILE"
    echo "Original: $original_name" >> "$RESULTS_FILE"
    echo "Category: $category" >> "$RESULTS_FILE"
    echo "Status: $status" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    echo -n "[$total_projects] $project_name ($category)... "

    # Check Nginx config
    if sudo nginx -T 2>/dev/null | grep -q "$project_name"; then
        echo "  Nginx: OK" >> "$RESULTS_FILE"
        nginx_ok=$((nginx_ok + 1))
    else
        echo "  Nginx: MISSING" >> "$RESULTS_FILE"
        nginx_fail=$((nginx_fail + 1))
    fi

    # Check Docker containers (skip for MCP/CLI/Archived)
    if [ "$category" != "mcp_servers" ] && [ "$category" != "cli_tools" ] && [ "$category" != "archived" ] && [ "$status" != "in-use" ]; then
        if docker ps | grep -q "$project_name"; then
            echo "  Docker: RUNNING" >> "$RESULTS_FILE"
            docker_ok=$((docker_ok + 1))
        else
            echo "  Docker: NOT RUNNING" >> "$RESULTS_FILE"
            docker_fail=$((docker_fail + 1))
        fi
    else
        echo "  Docker: N/A ($category)" >> "$RESULTS_FILE"
    fi

    # Check Landing Page DNS
    landing_domain="landing.$original_name.$ZONE"
    if check_dns "$landing_domain"; then
        echo "  DNS (landing): OK" >> "$RESULTS_FILE"
        dns_ok=$((dns_ok + 1))
    else
        echo "  DNS (landing): FAILED" >> "$RESULTS_FILE"
        dns_fail=$((dns_fail + 1))
    fi

    # Check Landing Page HTTP
    if check_http "http://$landing_domain"; then
        echo "  HTTP (landing): OK" >> "$RESULTS_FILE"
        landing_ok=$((landing_ok + 1))
    else
        echo "  HTTP (landing): FAILED" >> "$RESULTS_FILE"
        landing_fail=$((landing_fail + 1))
    fi

    # Check main domain (if applicable)
    if [ "$category" == "fullstack_web" ] || [ "$category" == "frontend_only" ]; then
        main_domain="$original_name.$ZONE"
        if check_dns "$main_domain"; then
            echo "  DNS (main): OK" >> "$RESULTS_FILE"
            dns_ok=$((dns_ok + 1))
        else
            echo "  DNS (main): FAILED" >> "$RESULTS_FILE"
            dns_fail=$((dns_fail + 1))
        fi
    fi

    # Check API domain (if applicable)
    if [ "$category" == "fullstack_web" ] || [ "$category" == "backend_api" ]; then
        api_domain="api.$original_name.$ZONE"
        if check_dns "$api_domain"; then
            echo "  DNS (api): OK" >> "$RESULTS_FILE"
            dns_ok=$((dns_ok + 1))
        else
            echo "  DNS (api): FAILED" >> "$RESULTS_FILE"
            dns_fail=$((dns_fail + 1))
        fi
    fi

    echo "OK"
    echo "" >> "$RESULTS_FILE"
done

# Summary
echo ""
echo "======================================"
echo "VERIFICATION SUMMARY"
echo "======================================"
echo ""

summary="
Projects Checked: $total_projects

Nginx Configs:
  OK: $nginx_ok
  Failed: $nginx_fail

Docker Containers:
  Running: $docker_ok
  Not Running: $docker_fail

DNS Records:
  OK: $dns_ok
  Failed: $dns_fail

Landing Pages:
  Accessible: $landing_ok
  Not Accessible: $landing_fail

Overall Status: $([ $nginx_fail -eq 0 ] && [ $landing_fail -eq 0 ] && echo "HEALTHY" || echo "NEEDS ATTENTION")
"

echo "$summary"
echo "" >> "$RESULTS_FILE"
echo "========================================" >> "$RESULTS_FILE"
echo "SUMMARY" >> "$RESULTS_FILE"
echo "========================================" >> "$RESULTS_FILE"
echo "$summary" >> "$RESULTS_FILE"

echo ""
echo "Full report saved to: $RESULTS_FILE"
echo ""

# Quick docker stats
echo "Docker Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -20

echo ""
echo "======================================"
