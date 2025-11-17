#!/bin/bash

# Bitwarden Credentials Manager Script
# This script updates or creates database credentials in Bitwarden vault

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Bitwarden Database Credentials Manager ===${NC}\n"

# Check if BW_SESSION is set
if [ -z "$BW_SESSION" ]; then
    echo -e "${YELLOW}No Bitwarden session found. Please unlock vault:${NC}"
    export BW_SESSION=$(bw unlock --raw)
    if [ -z "$BW_SESSION" ]; then
        echo -e "${RED}Failed to unlock vault. Exiting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Vault unlocked successfully!${NC}\n"
fi

# Function to create or update credential
create_or_update_credential() {
    local name="$1"
    local username="$2"
    local password="$3"
    local uri="$4"
    local notes="$5"
    local host="$6"
    local port="$7"

    echo -e "${BLUE}Processing: $name${NC}"

    # Search for existing item
    local existing_item=$(bw list items --search "$name" --session "$BW_SESSION" 2>/dev/null)
    local item_count=$(echo "$existing_item" | jq '. | length' 2>/dev/null || echo "0")

    if [ "$item_count" -gt 0 ]; then
        # Item exists - update it
        local item_id=$(echo "$existing_item" | jq -r '.[0].id')
        echo -e "${YELLOW}  Found existing item (ID: $item_id) - Updating...${NC}"

        # Get the existing item
        local item=$(bw get item "$item_id" --session "$BW_SESSION")

        # Update the item
        local updated_item=$(echo "$item" | jq \
            --arg name "$name" \
            --arg username "$username" \
            --arg password "$password" \
            --arg uri "$uri" \
            --arg notes "$notes" \
            --arg host "$host" \
            --arg port "$port" \
            '.name = $name |
             .login.username = $username |
             .login.password = $password |
             .login.uris = [{"match": null, "uri": $uri}] |
             .notes = $notes |
             .fields = [
                {"name": "Host", "value": $host, "type": 0},
                {"name": "Port", "value": $port, "type": 0},
                {"name": "Connection String", "value": $uri, "type": 0}
             ]')

        # Encode and update
        local encoded=$(echo "$updated_item" | bw encode)
        bw edit item "$item_id" "$encoded" --session "$BW_SESSION" > /dev/null

        echo -e "${GREEN}  ✓ UPDATED: $name (ID: $item_id)${NC}\n"
        echo "UPDATED|$item_id|$name"

    else
        # Item doesn't exist - create it
        echo -e "${YELLOW}  Item not found - Creating new...${NC}"

        # Create new item from template
        local new_item=$(bw get template item --session "$BW_SESSION" | jq \
            --arg name "$name" \
            --arg username "$username" \
            --arg password "$password" \
            --arg uri "$uri" \
            --arg notes "$notes" \
            --arg host "$host" \
            --arg port "$port" \
            '.type = 1 |
             .name = $name |
             .login = {
                "username": $username,
                "password": $password,
                "uris": [{"match": null, "uri": $uri}]
             } |
             .notes = $notes |
             .fields = [
                {"name": "Host", "value": $host, "type": 0},
                {"name": "Port", "value": $port, "type": 0},
                {"name": "Connection String", "value": $uri, "type": 0}
             ] |
             .organizationId = null |
             .folderId = null')

        # Encode and create
        local encoded=$(echo "$new_item" | bw encode)
        local result=$(bw create item "$encoded" --session "$BW_SESSION")
        local new_item_id=$(echo "$result" | jq -r '.id')

        echo -e "${GREEN}  ✓ CREATED: $name (ID: $new_item_id)${NC}\n"
        echo "CREATED|$new_item_id|$name"
    fi
}

# Store results
results_file="/tmp/bw_results_$$.txt"
> "$results_file"

echo -e "${BLUE}Processing credentials...${NC}\n"

# 1. PostgreSQL Standalone Database
{
    create_or_update_credential \
        "PostgreSQL Standalone Server (localhost:5432)" \
        "postgres" \
        "ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=" \
        "postgresql://postgres:ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=@localhost:5432" \
        "Standalone PostgreSQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost. Contains databases: platform_deployer, crypto_trading, autoscribe, deployer, guanaco_projects, etc." \
        "localhost" \
        "5432"
} | tee -a "$results_file"

# 2. Redis Standalone Server
{
    create_or_update_credential \
        "Redis Standalone Server (localhost:6379)" \
        "" \
        "7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=" \
        "redis://:7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=@localhost:6379/0" \
        "Standalone Redis server on Contabo VPS. Updated 2025-11-15 after malware incident. Password authentication enabled. Only accessible from localhost." \
        "localhost" \
        "6379"
} | tee -a "$results_file"

# 3. MySQL Standalone Server
{
    create_or_update_credential \
        "MySQL Standalone Server (localhost:3306)" \
        "root" \
        "IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=" \
        "mysql://root:IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=@localhost:3306" \
        "Standalone MySQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost." \
        "localhost" \
        "3306"
} | tee -a "$results_file"

echo -e "\n${BLUE}Syncing vault...${NC}"
bw sync --session "$BW_SESSION" > /dev/null
echo -e "${GREEN}✓ Vault synced successfully${NC}\n"

echo -e "${BLUE}=== Summary ===${NC}\n"

# Parse and display results
while IFS='|' read -r action item_id item_name; do
    if [ "$action" = "CREATED" ]; then
        echo -e "${GREEN}✓ CREATED${NC}: $item_name"
        echo -e "  ID: $item_id"
    elif [ "$action" = "UPDATED" ]; then
        echo -e "${YELLOW}✓ UPDATED${NC}: $item_name"
        echo -e "  ID: $item_id"
    fi
done < <(grep -E "^(CREATED|UPDATED)" "$results_file")

echo -e "\n${BLUE}Locking vault...${NC}"
bw lock > /dev/null 2>&1 || true
echo -e "${GREEN}✓ Vault locked${NC}\n"

echo -e "${GREEN}All operations completed successfully!${NC}"

# Cleanup
rm -f "$results_file"
