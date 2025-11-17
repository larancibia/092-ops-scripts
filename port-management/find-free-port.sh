#!/bin/bash

###############################################################################
# find-free-port.sh - Find Next Free Port in Range
#
# Description: Finds the next available free port in a specified range
# Usage: ./find-free-port.sh <range-type> [count]
#
# Examples:
#   ./find-free-port.sh frontend
#   ./find-free-port.sh backend 5
#   ./find-free-port.sh service
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
RANGE_TYPE="${1:-}"
COUNT="${2:-1}"

if [ -z "$RANGE_TYPE" ]; then
    echo "Usage: $0 <range-type> [count]"
    echo ""
    echo "Range Types:"
    echo "  frontend   - Web frontends (3000-3199)"
    echo "  backend    - Backend APIs (8000-8199)"
    echo "  service    - Microservices (9000-9199)"
    echo "  internal   - Internal tools (10000-10199)"
    echo "  postgresql - PostgreSQL (5432+)"
    echo "  mysql      - MySQL (3306+)"
    echo "  redis      - Redis (6379+)"
    echo ""
    echo "Count: Number of free ports to find (default: 1)"
    exit 1
fi

# Set range based on type
case $RANGE_TYPE in
    frontend)
        RANGE_START=3000
        RANGE_END=3199
        ;;
    backend)
        RANGE_START=8000
        RANGE_END=8199
        ;;
    service)
        RANGE_START=9000
        RANGE_END=9199
        ;;
    internal)
        RANGE_START=10000
        RANGE_END=10199
        ;;
    postgresql)
        RANGE_START=5432
        RANGE_END=5532
        ;;
    mysql)
        RANGE_START=3306
        RANGE_END=3406
        ;;
    redis)
        RANGE_START=6379
        RANGE_END=6479
        ;;
    *)
        log_error "Unknown range type: $RANGE_TYPE"
        exit 1
        ;;
esac

log_info "Searching for $COUNT free port(s) in range $RANGE_START-$RANGE_END"
echo ""

# Get reserved ports from registry if available
RESERVED_PORTS=""
if [ -f "$REGISTRY_FILE" ] && command -v jq &> /dev/null; then
    RESERVED_PORTS=$(jq -r '
        .allocations |
        to_entries |
        map(.value | to_entries | map(.value.ports | to_entries | map(.value))) |
        flatten |
        .[]
    ' "$REGISTRY_FILE" 2>/dev/null | sort -n || echo "")
fi

# Function to check if port is free
is_port_free() {
    local port=$1

    # Check if port is listening
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1
    fi

    # Check if port is in registry
    if echo "$RESERVED_PORTS" | grep -q "^$port$"; then
        return 1
    fi

    return 0
}

# Find free ports
FOUND_PORTS=()
current_port=$RANGE_START

while [ $current_port -le $RANGE_END ] && [ ${#FOUND_PORTS[@]} -lt $COUNT ]; do
    if is_port_free $current_port; then
        FOUND_PORTS+=($current_port)
    fi
    current_port=$((current_port + 1))
done

# Display results
if [ ${#FOUND_PORTS[@]} -eq 0 ]; then
    log_error "No free ports found in range $RANGE_START-$RANGE_END"
    exit 1
fi

log_success "Found ${#FOUND_PORTS[@]} free port(s):"
echo ""

for port in "${FOUND_PORTS[@]}"; do
    echo -e "  ${GREEN}✓${NC} Port $port is free"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ${#FOUND_PORTS[@]} -eq 1 ]; then
    echo "Next available port: ${FOUND_PORTS[0]}"
else
    echo "Next available ports: ${FOUND_PORTS[*]}"
fi

echo ""
echo "To allocate this port to a project, run:"
echo "  ./allocate-port.sh <project-name> $RANGE_TYPE"
echo ""
