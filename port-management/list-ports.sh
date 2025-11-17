#!/bin/bash

###############################################################################
# list-ports.sh - Port Registry Viewer
#
# Description: Lists all assigned ports with filtering options
# Usage: ./list-ports.sh [category] [status]
#
# Examples:
#   ./list-ports.sh                    # List all ports
#   ./list-ports.sh active             # List only active projects
#   ./list-ports.sh active in-use      # List active projects in use
#   ./list-ports.sh company            # List company projects
#   ./list-ports.sh experiments        # List experimental projects
###############################################################################

set -euo pipefail

REGISTRY_FILE="/home/luis/port-registry.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
CATEGORY_FILTER="${1:-all}"
STATUS_FILTER="${2:-all}"

# Function to print colored status
print_status() {
    local status=$1
    case $status in
        in-use)
            echo -e "${GREEN}$status${NC}"
            ;;
        reserved)
            echo -e "${YELLOW}$status${NC}"
            ;;
        archived)
            echo -e "${CYAN}$status${NC}"
            ;;
        *)
            echo -e "$status"
            ;;
    esac
}

# Function to print colored priority
print_priority() {
    local priority=$1
    case $priority in
        critical)
            echo -e "${RED}$priority${NC}"
            ;;
        high)
            echo -e "${MAGENTA}$priority${NC}"
            ;;
        medium)
            echo -e "${YELLOW}$priority${NC}"
            ;;
        low|archived)
            echo -e "${CYAN}$priority${NC}"
            ;;
        *)
            echo -e "$priority"
            ;;
    esac
}

# Print header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PORT REGISTRY OVERVIEW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show metadata
log_info "Registry Information"
jq -r '.metadata |
    "  Version:         \(.version)",
    "  Last Updated:    \(.lastUpdated)",
    "  Total Projects:  \(.totalProjects)",
    "  Ports Allocated: \(.portsAllocated)"' "$REGISTRY_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show port ranges summary
log_info "Port Ranges Summary"
echo ""
printf "%-20s %-15s %-10s %-15s\n" "Range" "Ports" "Usage" "Description"
printf "%-20s %-15s %-10s %-15s\n" "────────────────────" "───────────────" "──────────" "───────────────"

jq -r '.portRanges | to_entries[] | select(.value.range) |
    "\(.key)|\(.value.range)|\(.value.currentUsage)/\(.value.capacity)|\(.value.description)"' "$REGISTRY_FILE" | \
while IFS='|' read -r name range usage desc; do
    printf "%-20s %-15s %-10s %-30s\n" "$name" "$range" "$usage" "$desc"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# List projects
if [ "$CATEGORY_FILTER" = "all" ]; then
    log_info "Listing ALL projects"
    CATEGORIES=$(jq -r '.allocations | keys[]' "$REGISTRY_FILE")
else
    log_info "Filtering by category: $CATEGORY_FILTER"
    CATEGORIES="$CATEGORY_FILTER"
fi

echo ""

for category in $CATEGORIES; do
    # Check if category exists
    if ! jq -e ".allocations.\"$category\"" "$REGISTRY_FILE" > /dev/null 2>&1; then
        log_warning "Category '$category' not found in registry"
        continue
    fi

    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $(printf '%-73s' "CATEGORY: $(echo $category | tr '[:lower:]' '[:upper:]')") ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Count projects in category
    PROJECT_COUNT=$(jq -r ".allocations.\"$category\" | length" "$REGISTRY_FILE")
    echo "Projects in this category: $PROJECT_COUNT"
    echo ""

    # Print table header
    printf "%-35s %-8s %-10s %-25s %-10s\n" "Project" "Status" "Priority" "Ports" "Type"
    printf "%-35s %-8s %-10s %-25s %-10s\n" "───────────────────────────────────" "────────" "──────────" "─────────────────────────" "──────────"

    # Get projects in category
    jq -r --arg cat "$category" --arg status_filter "$STATUS_FILTER" '
        .allocations[$cat] | to_entries[] |
        select(if $status_filter == "all" then true else .value.status == $status_filter end) |
        {
            name: .value.projectName,
            status: .value.status,
            priority: .value.priority,
            ports: (.value.ports | to_entries | map("\(.key):\(.value)") | join(", ")),
            type: .value.type
        } |
        "\(.name)|\(.status)|\(.priority)|\(.ports)|\(.type)"
    ' "$REGISTRY_FILE" | while IFS='|' read -r name status priority ports type; do
        # Truncate long names
        if [ ${#name} -gt 34 ]; then
            name="${name:0:31}..."
        fi
        if [ ${#ports} -gt 24 ]; then
            ports="${ports:0:21}..."
        fi

        printf "%-35s " "$name"
        printf "%-8s " "$(print_status "$status")"
        printf "%-10s " "$(print_priority "$priority")"
        printf "%-25s " "$ports"
        printf "%-10s\n" "$type"
    done

    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show statistics
log_info "Port Usage Statistics"
echo ""

TOTAL_IN_USE=$(jq -r '[.allocations[][] | select(.status == "in-use")] | length' "$REGISTRY_FILE")
TOTAL_RESERVED=$(jq -r '[.allocations[][] | select(.status == "reserved")] | length' "$REGISTRY_FILE")
TOTAL_ARCHIVED=$(jq -r '[.allocations[][] | select(.status == "archived")] | length' "$REGISTRY_FILE")

echo "  In Use:    $TOTAL_IN_USE projects"
echo "  Reserved:  $TOTAL_RESERVED projects"
echo "  Archived:  $TOTAL_ARCHIVED projects"

echo ""

# Show currently listening ports
log_info "System Ports Currently Listening"
echo ""

LISTENING_PORTS=$(ss -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oP ':\K[0-9]+$' | sort -n | uniq | head -20)
echo "Top 20 active ports on system:"
echo "$LISTENING_PORTS" | head -20

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Port listing complete!"
echo ""
echo "Usage tips:"
echo "  - Filter by category: ./list-ports.sh active"
echo "  - Filter by status:   ./list-ports.sh active in-use"
echo "  - Check specific port: ./check-port.sh 3000"
echo "  - Allocate new port:   ./allocate-port.sh my-app frontend"
echo ""
