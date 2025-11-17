#!/bin/bash
# Script to add DNS record to Cloudflare
# Usage: ./add-dns-record-cloudflare.sh

set -e

echo "🌐 Cloudflare DNS Record Creator"
echo "================================="
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Configuration
DOMAIN="guanacolabs.com"
SUBDOMAIN="web-agent"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
IP_ADDRESS="217.216.64.237"
RECORD_TYPE="A"
PROXIED=false  # false = DNS only (orange cloud off), true = proxied through Cloudflare

echo "📋 Configuration:"
echo "   Domain: $DOMAIN"
echo "   Subdomain: $SUBDOMAIN"
echo "   Full domain: $FULL_DOMAIN"
echo "   IP: $IP_ADDRESS"
echo "   Proxied: $PROXIED"
echo ""

# Check if credentials file exists
CREDS_FILE="$HOME/.cloudflare-credentials"

if [ ! -f "$CREDS_FILE" ]; then
    echo "⚠️  Cloudflare credentials not found"
    echo ""
    echo "You need to create $CREDS_FILE with:"
    echo ""
    echo "CLOUDFLARE_API_TOKEN=your_api_token_here"
    echo "CLOUDFLARE_ZONE_ID=your_zone_id_here"
    echo ""
    echo "📚 How to get credentials:"
    echo ""
    echo "1. API Token:"
    echo "   - Go to https://dash.cloudflare.com/profile/api-tokens"
    echo "   - Click 'Create Token'"
    echo "   - Use 'Edit zone DNS' template"
    echo "   - Select zone: guanacolabs.com"
    echo "   - Create and copy the token"
    echo ""
    echo "2. Zone ID:"
    echo "   - Go to https://dash.cloudflare.com"
    echo "   - Select domain: guanacolabs.com"
    echo "   - Look for 'Zone ID' on the right sidebar"
    echo ""
    echo "Or manually add the DNS record:"
    echo ""
    echo "   Type: A"
    echo "   Name: web-agent"
    echo "   IPv4 address: 217.216.64.237"
    echo "   Proxy status: DNS only (grey cloud)"
    echo "   TTL: Auto"
    echo ""
    exit 1
fi

# Load credentials
source "$CREDS_FILE"

if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo "❌ Missing CLOUDFLARE_API_TOKEN or CLOUDFLARE_ZONE_ID in $CREDS_FILE"
    exit 1
fi

echo "✅ Credentials loaded"
echo ""

# Check if record already exists
echo "🔍 Checking if record already exists..."
EXISTING_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=${RECORD_TYPE}&name=${FULL_DOMAIN}" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type: application/json")

RECORD_COUNT=$(echo "$EXISTING_RECORD" | jq '.result | length')

if [ "$RECORD_COUNT" -gt 0 ]; then
    echo "⚠️  DNS record already exists!"
    echo ""
    echo "Existing record:"
    echo "$EXISTING_RECORD" | jq '.result[0]'
    echo ""
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    RECORD_ID=$(echo "$EXISTING_RECORD" | jq -r '.result[0].id')

    # Update existing record
    echo "🔄 Updating DNS record..."
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
         -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"${RECORD_TYPE}\",\"name\":\"${SUBDOMAIN}\",\"content\":\"${IP_ADDRESS}\",\"ttl\":1,\"proxied\":${PROXIED}}")
else
    # Create new record
    echo "➕ Creating new DNS record..."
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
         -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"${RECORD_TYPE}\",\"name\":\"${SUBDOMAIN}\",\"content\":\"${IP_ADDRESS}\",\"ttl\":1,\"proxied\":${PROXIED}}")
fi

# Check response
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
    echo "✅ DNS record created/updated successfully!"
    echo ""
    echo "$RESPONSE" | jq '.result'
    echo ""
    echo "📊 DNS Information:"
    echo "   Domain: $FULL_DOMAIN"
    echo "   Type: $RECORD_TYPE"
    echo "   IP: $IP_ADDRESS"
    echo "   Proxied: $PROXIED"
    echo ""
    echo "⏳ DNS propagation usually takes 1-5 minutes"
    echo ""
    echo "🔍 Check propagation with:"
    echo "   dig $FULL_DOMAIN +short"
    echo ""
    echo "🔐 Next step - Setup SSL:"
    echo "   sudo certbot --nginx -d $FULL_DOMAIN"
else
    echo "❌ Failed to create/update DNS record"
    echo ""
    echo "Error:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
