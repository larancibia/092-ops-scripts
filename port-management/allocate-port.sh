#!/bin/bash

###############################################################################
# allocate-port.sh - Professional Port Allocation System
#
# Description: Allocates the next available port for a project
# Usage: ./allocate-port.sh <project-name> <port-type> [priority]
#
# Examples:
#   ./allocate-port.sh my-new-app frontend high
#   ./allocate-port.sh api-service backend medium
#   ./allocate-port.sh cache-server redis low
###############################################################################

set -euo pipefail

REGISTRY_FILE="/home/luis/port-registry.json"
TEMP_FILE="/tmp/port-registry-temp.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if registry file exists
if [ ! -f "$REGISTRY_FILE" ]; then
    log_error "Port registry file not found: $REGISTRY_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Install with: sudo apt install jq"
    exit 1
fi

# Parse arguments
PROJECT_NAME="${1:-}"
PORT_TYPE="${2:-}"
PRIORITY="${3:-medium}"

if [ -z "$PROJECT_NAME" ] || [ -z "$PORT_TYPE" ]; then
    echo "Usage: $0 <project-name> <port-type> [priority]" >&2
    echo "" >&2
    echo "Port Types:" >&2
    echo "  frontend      - Web frontends (3000-3199)" >&2
    echo "  backend       - Backend APIs (8000-8199)" >&2
    echo "  service       - Microservices (9000-9199)" >&2
    echo "  internal      - Internal tools (10000-10199)" >&2
    echo "  postgresql    - PostgreSQL (5432+)" >&2
    echo "  mysql         - MySQL (3306+)" >&2
    echo "  redis         - Redis (6379+)" >&2
    echo "  mongodb       - MongoDB (27017+)" >&2
    echo "" >&2
    echo "Priority levels: critical, high, medium, low" >&2
    exit 1
fi

# Function to find next available port in range
find_next_port() {
    local range_start=$1
    local range_end=$2
    local current_port=$range_start

    while [ $current_port -le $range_end ]; do
        # Check if port is in use (in registry or system)
        local in_registry=$(jq -r --arg port "$current_port" '
            .allocations |
            to_entries |
            map(.value | to_entries | map(.value.ports | to_entries | map(.value))) |
            flatten |
            map(tostring) |
            any(. == $port)
        ' "$REGISTRY_FILE")

        local in_reserved=$(jq -r --arg port "$current_port" '
            .reservedPorts.inUse |
            map(tostring) |
            any(. == $port)
        ' "$REGISTRY_FILE")

        # Check if port is actually listening on the system
        local port_listening=$(ss -tlnp 2>/dev/null | grep -c ":$current_port " || true)

        if [ "$in_registry" == "false" ] && [ "$in_reserved" == "false" ] && [ "$port_listening" == "0" ]; then
            echo $current_port
            return 0
        fi

        current_port=$((current_port + 1))
    done

    log_error "No available ports in range $range_start-$range_end"
    return 1
}

# Function to get base port for database types
get_next_database_port() {
    local db_type=$1
    local base_port=$2
    local offset=0

    while true; do
        local candidate_port=$((base_port + offset))

        local in_use=$(jq -r --arg port "$candidate_port" '
            .allocations |
            to_entries |
            map(.value | to_entries | map(.value.ports | to_entries | map(.value))) |
            flatten |
            map(tostring) |
            any(. == $port)
        ' "$REGISTRY_FILE")

        local port_listening=$(ss -tlnp 2>/dev/null | grep -c ":$candidate_port " || true)

        if [ "$in_use" == "false" ] && [ "$port_listening" == "0" ]; then
            echo $candidate_port
            return 0
        fi

        offset=$((offset + 1))

        if [ $offset -gt 100 ]; then
            log_error "No available ports for $db_type (checked 100 ports)"
            return 1
        fi
    done
}

# Allocate port based on type
log_info "Allocating port for project: $PROJECT_NAME"
log_info "Port type: $PORT_TYPE"
log_info "Priority: $PRIORITY"
echo ""

case $PORT_TYPE in
    frontend)
        ALLOCATED_PORT=$(find_next_port 3000 3199)
        PORT_KEY="frontend"
        ;;
    backend)
        ALLOCATED_PORT=$(find_next_port 8000 8199)
        PORT_KEY="backend"
        ;;
    service)
        ALLOCATED_PORT=$(find_next_port 9000 9199)
        PORT_KEY="service"
        ;;
    internal)
        ALLOCATED_PORT=$(find_next_port 10000 10199)
        PORT_KEY="internal"
        ;;
    postgresql)
        ALLOCATED_PORT=$(get_next_database_port "postgresql" 5432)
        PORT_KEY="database"
        ;;
    mysql)
        ALLOCATED_PORT=$(get_next_database_port "mysql" 3306)
        PORT_KEY="database"
        ;;
    mongodb)
        ALLOCATED_PORT=$(get_next_database_port "mongodb" 27017)
        PORT_KEY="database"
        ;;
    redis)
        ALLOCATED_PORT=$(get_next_database_port "redis" 6379)
        PORT_KEY="cache"
        ;;
    *)
        log_error "Unknown port type: $PORT_TYPE"
        echo "Valid types: frontend, backend, service, internal, postgresql, mysql, mongodb, redis"
        exit 1
        ;;
esac

if [ -z "$ALLOCATED_PORT" ]; then
    log_error "Failed to allocate port"
    exit 1
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create new entry in registry
log_info "Adding to registry..."

# Sanitize project name for JSON key (replace spaces and special chars with dashes)
PROJECT_KEY=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

# Update the registry file
jq --arg key "$PROJECT_KEY" \
   --arg name "$PROJECT_NAME" \
   --arg port "$ALLOCATED_PORT" \
   --arg port_key "$PORT_KEY" \
   --arg priority "$PRIORITY" \
   --arg timestamp "$TIMESTAMP" \
   '.allocations.active[$key] = {
      "projectName": $name,
      "type": "service",
      "status": "reserved",
      "ports": {($port_key): ($port | tonumber)},
      "assignedDate": $timestamp,
      "priority": $priority
   } | .reservedPorts.inUse += [($port | tonumber)] | .reservedPorts.inUse |= unique | .metadata.lastUpdated = $timestamp' \
   "$REGISTRY_FILE" > "$TEMP_FILE"

# Backup original and replace (rotating backup)
cp "$REGISTRY_FILE" "${REGISTRY_FILE}.bak"
mv "$TEMP_FILE" "$REGISTRY_FILE"

log_success "Port allocated successfully!"
echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "  Project:  $PROJECT_NAME" >&2
echo "  Type:     $PORT_TYPE" >&2
echo "  Port:     $ALLOCATED_PORT" >&2
echo "  Priority: $PRIORITY" >&2
echo "  Status:   reserved" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2
log_info "Next steps:"
echo "  1. Update your docker-compose.yml to use port $ALLOCATED_PORT" >&2
echo "  2. Run ./check-port.sh $ALLOCATED_PORT to verify it's free" >&2
echo "  3. Start your service and test" >&2
echo "" >&2
log_info "Registry backed up to: ${REGISTRY_FILE}.bak"

# FINAL OUTPUT: JUST THE PORT
echo "$ALLOCATED_PORT"
