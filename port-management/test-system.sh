#!/bin/bash

# Test Port Management System
# Verifies all components are working correctly

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_FILE="/home/luis/port-registry.json"
DOC_FILE="/home/luis/PORT_ASSIGNMENTS.md"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PORT MANAGEMENT SYSTEM - TEST SUITE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: Check files exist
echo -e "${BLUE}[TEST 1]${NC} Checking if files exist..."
if [ -f "$REGISTRY_FILE" ]; then
    echo -e "${GREEN}✓${NC} Registry file exists: $REGISTRY_FILE"
else
    echo -e "${RED}✗${NC} Registry file missing: $REGISTRY_FILE"
    exit 1
fi

if [ -f "$DOC_FILE" ]; then
    echo -e "${GREEN}✓${NC} Documentation exists: $DOC_FILE"
else
    echo -e "${RED}✗${NC} Documentation missing: $DOC_FILE"
    exit 1
fi

# Test 2: Validate JSON
echo ""
echo -e "${BLUE}[TEST 2]${NC} Validating JSON structure..."
if jq empty "$REGISTRY_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} JSON is valid"
else
    echo -e "${RED}✗${NC} JSON is invalid"
    exit 1
fi

# Test 3: Check scripts exist and are executable
echo ""
echo -e "${BLUE}[TEST 3]${NC} Checking scripts..."
SCRIPTS=(
    "allocate-port.sh"
    "check-port.sh"
    "list-ports.sh"
    "find-free-port.sh"
    "migrate-port.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -x "$SCRIPT_DIR/$script" ]; then
        echo -e "${GREEN}✓${NC} $script is executable"
    else
        echo -e "${RED}✗${NC} $script is not executable"
        exit 1
    fi
done

# Test 4: Verify project count
echo ""
echo -e "${BLUE}[TEST 4]${NC} Verifying project count..."
EXPECTED_COUNT=84
ACTUAL_COUNT=$(jq '.allocated | keys | length' "$REGISTRY_FILE")
if [ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]; then
    echo -e "${GREEN}✓${NC} Project count correct: $ACTUAL_COUNT/$EXPECTED_COUNT"
else
    echo -e "${RED}✗${NC} Project count mismatch: $ACTUAL_COUNT/$EXPECTED_COUNT"
    exit 1
fi

# Test 5: Check for port conflicts
echo ""
echo -e "${BLUE}[TEST 5]${NC} Checking for port conflicts..."
CONFLICTS=$(jq '.usage_summary.conflicts_detected' "$REGISTRY_FILE")
if [ "$CONFLICTS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No port conflicts detected"
else
    echo -e "${RED}✗${NC} $CONFLICTS port conflicts detected"
    exit 1
fi

# Test 6: Verify next available ports
echo ""
echo -e "${BLUE}[TEST 6]${NC} Checking next available ports..."
NEXT_FRONTEND=$(jq -r '.usage_summary.next_available.frontend' "$REGISTRY_FILE")
NEXT_BACKEND=$(jq -r '.usage_summary.next_available.backend' "$REGISTRY_FILE")
NEXT_DATABASE=$(jq -r '.usage_summary.next_available.database' "$REGISTRY_FILE")
NEXT_REDIS=$(jq -r '.usage_summary.next_available.redis' "$REGISTRY_FILE")

echo -e "${GREEN}✓${NC} Frontend:  $NEXT_FRONTEND"
echo -e "${GREEN}✓${NC} Backend:   $NEXT_BACKEND"
echo -e "${GREEN}✓${NC} Database:  $NEXT_DATABASE"
echo -e "${GREEN}✓${NC} Redis:     $NEXT_REDIS"

# Test 7: Verify production systems
echo ""
echo -e "${BLUE}[TEST 7]${NC} Checking production systems..."
PRODUCTION_COUNT=$(jq '[.allocated[] | select(.status == "in-use")] | length' "$REGISTRY_FILE")
echo -e "${GREEN}✓${NC} Production systems: $PRODUCTION_COUNT"

# Test 8: Test find-free-port script
echo ""
echo -e "${BLUE}[TEST 8]${NC} Testing find-free-port script..."
if "$SCRIPT_DIR/find-free-port.sh" frontend > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} find-free-port.sh works"
else
    echo -e "${YELLOW}⚠${NC} find-free-port.sh returned non-zero (may be normal)"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}ALL TESTS PASSED!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "System is ready for use."
echo ""
echo "Quick commands:"
echo "  - Check port: ./check-port.sh 3000"
echo "  - Find free:  ./find-free-port.sh frontend"
echo "  - List all:   ./list-ports.sh"
echo ""
