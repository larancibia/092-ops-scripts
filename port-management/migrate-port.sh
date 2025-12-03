#!/bin/bash

###############################################################################
# migrate-port.sh - Migrate Project to New Port
#
# Description: Updates port assignment for a project in the registry
# Usage: ./migrate-port.sh <project-key> <port-type> <new-port>
#
# Examples:
#   ./migrate-port.sh web-autoscribe frontend 3090
#   ./migrate-port.sh platform-deployer backend 8050
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
PROJECT_KEY="${1:-}"
PORT_TYPE="${2:-}"
NEW_PORT="${3:-}"

if [ -z "$PROJECT_KEY" ] || [ -z "$PORT_TYPE" ] || [ -z "$NEW_PORT" ]; then
    echo "Usage: $0 <project-key> <port-type> <new-port>"
    echo ""
    echo "Examples:"
    echo "  $0 web-autoscribe frontend 3090"
    echo "  $0 platform-deployer backend 8050"
    echo ""
    echo "Port Types: frontend, backend, database, service, cache"
    exit 1
fi

# Validate new port number
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
    log_error "Invalid port number. Must be between 1 and 65535"
    exit 1
fi

# Find project in registry
log_info "Searching for project: $PROJECT_KEY"

PROJECT_CATEGORY=$(jq -r --arg key "$PROJECT_KEY" '
    .allocations | to_entries[] |
    select(.value | has($key)) |
    .key
' "$REGISTRY_FILE" | head -1)

if [ -z "$PROJECT_CATEGORY" ]; then
    log_error "Project '$PROJECT_KEY' not found in registry"
    echo ""
    echo "Available projects:"
    jq -r '.allocations | to_entries[] | .value | keys[]' "$REGISTRY_FILE" | sort | head -20
    exit 1
fi

log_success "Found project in category: $PROJECT_CATEGORY"

# Get current port
CURRENT_PORT=$(jq -r --arg cat "$PROJECT_CATEGORY" --arg key "$PROJECT_KEY" --arg port_type "$PORT_TYPE" '
    .allocations[$cat][$key].ports[$port_type] // "not-set"
' "$REGISTRY_FILE")

if [ "$CURRENT_PORT" = "not-set" ] || [ "$CURRENT_PORT" = "null" ]; then
    log_warning "Project does not have a $PORT_TYPE port set"
    echo "Adding new $PORT_TYPE port: $NEW_PORT"
else
    log_info "Current $PORT_TYPE port: $CURRENT_PORT"
    echo "Migrating to new port: $NEW_PORT"
fi

# Check if new port is already in use
log_info "Checking if new port is available..."

PORT_CHECK=$(./check-port.sh "$NEW_PORT" 2>&1 | grep -c "IN USE" || echo "0")

if [ "$PORT_CHECK" != "0" ]; then
    log_error "Port $NEW_PORT is already in use!"
    ./check-port.sh "$NEW_PORT"
    exit 1
fi

log_success "Port $NEW_PORT is available"
echo ""

# Confirm migration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MIGRATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Project:    $PROJECT_KEY"
echo "  Category:   $PROJECT_CATEGORY"
echo "  Port Type:  $PORT_TYPE"
if [ "$CURRENT_PORT" != "not-set" ] && [ "$CURRENT_PORT" != "null" ]; then
    echo "  Old Port:   $CURRENT_PORT"
fi
echo "  New Port:   $NEW_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Proceed with migration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Migration cancelled"
    exit 0
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update the registry
log_info "Updating registry..."

jq --arg cat "$PROJECT_CATEGORY" \
   --arg key "$PROJECT_KEY" \
   --arg port_type "$PORT_TYPE" \
   --arg new_port "$NEW_PORT" \
   --arg old_port "$CURRENT_PORT" \
   --arg timestamp "$TIMESTAMP" '
    .allocations[$cat][$key].ports[$port_type] = ($new_port | tonumber) |
    .allocations[$cat][$key].lastMigrated = $timestamp |
    .allocations[$cat][$key].migrationNote = "Migrated \($port_type) from \($old_port) to \($new_port)" |
    if $old_port != "not-set" and $old_port != "null" then
        .reservedPorts.inUse = (.reservedPorts.inUse - [($old_port | tonumber)])
    else . end |
    .reservedPorts.inUse += [($new_port | tonumber)] |
    .reservedPorts.inUse |= unique |
    .metadata.lastUpdated = $timestamp
' "$REGISTRY_FILE" > "$TEMP_FILE"

# Backup original and replace (rotating backup)
BACKUP_FILE="${REGISTRY_FILE}.bak"
cp "$REGISTRY_FILE" "$BACKUP_FILE"
mv "$TEMP_FILE" "$REGISTRY_FILE"

log_success "Migration completed successfully!"
echo ""
log_info "Registry backed up to: $BACKUP_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_warning "IMPORTANT: Next steps"
echo ""
echo "1. Update your docker-compose.yml:"
echo "   Replace port $CURRENT_PORT with $NEW_PORT"
echo ""
echo "2. Restart the service:"
echo "   docker-compose down"
echo "   docker-compose up -d"
echo ""
echo "3. Update any reverse proxy configs (nginx, traefik, etc.)"
echo ""
echo "4. Update any firewall rules if applicable"
echo ""
