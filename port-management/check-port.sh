#!/bin/bash

###############################################################################
# check-port.sh - Port Status Checker
#
# Description: Checks if a port is free or in use
# Usage: ./check-port.sh <port-number>
#
# Examples:
#   ./check-port.sh 3000
#   ./check-port.sh 8080
###############################################################################

set -euo pipefail

REGISTRY_FILE="/home/luis/port-registry.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
PORT_NUMBER="${1:-}"

if [ -z "$PORT_NUMBER" ]; then
    echo "Usage: $0 <port-number>"
    echo ""
    echo "Examples:"
    echo "  $0 3000"
    echo "  $0 8080"
    exit 1
fi

# Validate port number
if ! [[ "$PORT_NUMBER" =~ ^[0-9]+$ ]] || [ "$PORT_NUMBER" -lt 1 ] || [ "$PORT_NUMBER" -gt 65535 ]; then
    log_error "Invalid port number. Must be between 1 and 65535"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PORT STATUS CHECK: $PORT_NUMBER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 1: System listening check
log_info "Checking if port is listening on system..."
if ss -tlnp 2>/dev/null | grep -q ":$PORT_NUMBER "; then
    log_error "Port $PORT_NUMBER is IN USE on the system"

    # Get process details
    echo ""
    echo "Process details:"
    ss -tlnp 2>/dev/null | grep ":$PORT_NUMBER " | head -5

    PORT_LISTENING=true
else
    log_success "Port $PORT_NUMBER is FREE on the system"
    PORT_LISTENING=false
fi

echo ""

# Check 2: Docker container check
log_info "Checking Docker containers..."
DOCKER_CHECK=$(docker ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null | grep ":$PORT_NUMBER->" || echo "")

if [ -n "$DOCKER_CHECK" ]; then
    log_warning "Port $PORT_NUMBER is mapped by Docker container(s):"
    echo "$DOCKER_CHECK"
    PORT_IN_DOCKER=true
else
    log_success "Port $PORT_NUMBER is not used by any Docker container"
    PORT_IN_DOCKER=false
fi

echo ""

# Check 3: Registry check
if [ -f "$REGISTRY_FILE" ]; then
    log_info "Checking port registry..."

    if command -v jq &> /dev/null; then
        # Search for port in registry
        REGISTRY_ENTRY=$(jq -r --arg port "$PORT_NUMBER" '
            .allocations |
            to_entries[] |
            .key as $category |
            .value |
            to_entries[] |
            .key as $project_key |
            .value |
            select(.ports | to_entries[] | .value == ($port | tonumber)) |
            {
                category: $category,
                project_key: $project_key,
                project_name: .projectName,
                type: .type,
                status: .status,
                priority: .priority,
                port_type: (.ports | to_entries[] | select(.value == ($port | tonumber)) | .key),
                assigned_date: .assignedDate
            }
        ' "$REGISTRY_FILE" 2>/dev/null | head -1)

        if [ -n "$REGISTRY_ENTRY" ]; then
            log_warning "Port $PORT_NUMBER is REGISTERED in port-registry.json"
            echo ""
            echo "Registry details:"
            echo "$REGISTRY_ENTRY" | jq -r '
                "  Project:       \(.project_name)",
                "  Category:      \(.category)",
                "  Type:          \(.type)",
                "  Port Type:     \(.port_type)",
                "  Status:        \(.status)",
                "  Priority:      \(.priority)",
                "  Assigned Date: \(.assigned_date)"
            '
            PORT_IN_REGISTRY=true
        else
            log_success "Port $PORT_NUMBER is NOT registered in port-registry.json"
            PORT_IN_REGISTRY=false
        fi
    else
        log_warning "jq not installed, skipping registry check"
        PORT_IN_REGISTRY=false
    fi
else
    log_warning "Port registry file not found: $REGISTRY_FILE"
    PORT_IN_REGISTRY=false
fi

echo ""

# Check 4: Reserved ports check
log_info "Checking if port is in a reserved range..."

RANGE_INFO=""
if [ "$PORT_NUMBER" -ge 1 ] && [ "$PORT_NUMBER" -le 1023 ]; then
    RANGE_INFO="System/Well-Known Ports (privileged)"
elif [ "$PORT_NUMBER" -ge 3000 ] && [ "$PORT_NUMBER" -le 3199 ]; then
    RANGE_INFO="Web Frontends Range"
elif [ "$PORT_NUMBER" -ge 8000 ] && [ "$PORT_NUMBER" -le 8199 ]; then
    RANGE_INFO="Backend APIs Range"
elif [ "$PORT_NUMBER" -ge 9000 ] && [ "$PORT_NUMBER" -le 9199 ]; then
    RANGE_INFO="Services Range"
elif [ "$PORT_NUMBER" -ge 10000 ] && [ "$PORT_NUMBER" -le 10199 ]; then
    RANGE_INFO="Internal Tools Range"
elif [ "$PORT_NUMBER" -eq 5432 ] || [ "$PORT_NUMBER" -eq 5433 ] || [ "$PORT_NUMBER" -eq 5434 ]; then
    RANGE_INFO="PostgreSQL Database"
elif [ "$PORT_NUMBER" -eq 3306 ] || [ "$PORT_NUMBER" -eq 3307 ]; then
    RANGE_INFO="MySQL Database"
elif [ "$PORT_NUMBER" -eq 6379 ] || [ "$PORT_NUMBER" -eq 6380 ] || [ "$PORT_NUMBER" -eq 6381 ]; then
    RANGE_INFO="Redis Cache"
elif [ "$PORT_NUMBER" -eq 27017 ] || [ "$PORT_NUMBER" -eq 27018 ]; then
    RANGE_INFO="MongoDB Database"
else
    RANGE_INFO="Custom/Unmanaged Range"
fi

echo -e "${CYAN}Port Range:${NC} $RANGE_INFO"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Final verdict
if [ "$PORT_LISTENING" = true ] || [ "$PORT_IN_DOCKER" = true ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  PORT $PORT_NUMBER IS IN USE - DO NOT USE               ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
    exit 1
elif [ "$PORT_IN_REGISTRY" = true ]; then
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  PORT $PORT_NUMBER IS RESERVED - CHECK BEFORE USE    ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  PORT $PORT_NUMBER IS FREE - SAFE TO USE             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    exit 0
fi
