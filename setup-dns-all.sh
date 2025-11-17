#!/bin/bash
# Setup Cloudflare DNS for all projects
# Creates DNS A records for all subdomains

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

# Load Cloudflare credentials
if [ -z "$CF_API_KEY" ] || [ -z "$CF_EMAIL" ]; then
    echo "Loading Cloudflare credentials from ~/.zshrc"
    source ~/.zshrc
fi

if [ -z "$CF_API_KEY" ] || [ -z "$CF_EMAIL" ]; then
    echo "Error: Cloudflare credentials not found"
    echo "Please set CF_API_KEY and CF_EMAIL in ~/.zshrc"
    exit 1
fi

SERVER_IP=$(jq -r '.server_ip' "$DEPLOY_DATA")
ZONE=$(jq -r '.zone' "$DEPLOY_DATA")

echo "======================================"
echo "Cloudflare DNS Setup - All Projects"
echo "======================================"
echo "Zone: $ZONE"
echo "Server IP: $SERVER_IP"
echo "======================================"
echo ""

# Get Cloudflare Zone ID
echo "Fetching Cloudflare Zone ID..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
    echo "Error: Could not find zone ID for $ZONE"
    exit 1
fi

echo "Zone ID: $ZONE_ID"
echo ""

# Function to create DNS record
create_dns_record() {
    local subdomain=$1
    local record_name="${subdomain}.${ZONE}"

    echo -n "Creating DNS record for $record_name... "

    # Check if record already exists
    existing=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [ -n "$existing" ] && [ "$existing" != "null" ]; then
        echo "ALREADY EXISTS (ID: $existing)"
        return
    fi

    # Create new record
    result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")

    success=$(echo "$result" | jq -r '.success')
    if [ "$success" == "true" ]; then
        record_id=$(echo "$result" | jq -r '.result.id')
        echo "CREATED (ID: $record_id)"
    else
        error=$(echo "$result" | jq -r '.errors[0].message')
        echo "FAILED ($error)"
    fi
}

# Process all projects
total_projects=$(jq -r '.deployment_plan | length' "$DEPLOY_DATA")
current=0

echo "Processing $total_projects projects..."
echo ""

jq -r '.deployment_plan | to_entries[] | "\(.key)|\(.value.original_name)|\(.value.category)"' "$DEPLOY_DATA" | while IFS='|' read -r project_name original_name category; do
    current=$((current + 1))
    echo "[$current/$total_projects] $project_name ($category)"

    # Create DNS records based on category
    case "$category" in
        fullstack_web)
            create_dns_record "$original_name"          # main app
            create_dns_record "api.$original_name"      # api
            create_dns_record "landing.$original_name"  # landing
            ;;
        backend_api)
            create_dns_record "api.$original_name"      # api
            create_dns_record "landing.$original_name"  # landing
            ;;
        frontend_only)
            create_dns_record "$original_name"          # main app
            create_dns_record "landing.$original_name"  # landing
            ;;
        mcp_servers|cli_tools|archived|unknown)
            create_dns_record "landing.$original_name"  # landing only
            ;;
    esac

    echo ""
done

echo "======================================"
echo "DNS Setup Complete!"
echo "======================================"
echo ""
echo "Note: DNS propagation may take a few minutes"
echo "Test with: dig <subdomain>.$ZONE"
echo ""
