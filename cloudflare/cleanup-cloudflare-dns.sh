#!/bin/bash

# Cloudflare DNS Cleanup Script
# Generated: 2025-11-17
# Purpose: Remove obsolete subdomain DNS records from Cloudflare

# Cloudflare Configuration
CLOUDFLARE_API_TOKEN="NUXAARmpEp_dWsC9Spb2_FYeGlI3gwrL7JSaPKsg"
CLOUDFLARE_ZONE_ID="18b19eaf575c2b7c7d31272741e88a99"

echo "=========================================="
echo "Cloudflare DNS Cleanup Script"
echo "Zone: guanacolabs.com"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Function to delete DNS record
delete_dns_record() {
    local record_id="$1"
    local subdomain="$2"

    echo "Deleting: $subdomain"

    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json")

    success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [ "$success" = "true" ]; then
        echo "  ✓ Successfully deleted: $subdomain"
    else
        echo "  ✗ Failed to delete: $subdomain"
        echo "  Response: $response"
    fi
    echo ""
}

echo "Starting DNS cleanup process..."
echo ""

# Category 1: Projects without local folder (not cloned/deployed)
echo "=== Category 1: Projects without local folder ==="
delete_dns_record "cc7ff787449f3259609a23a80495fc77" "api-keys-dashboard.guanacolabs.com"
delete_dns_record "db550b632b32d22ee485f8ba62649962" "crypto-pump-crash-system.guanacolabs.com"
delete_dns_record "5f09c67123c2f2561ae43ee70b95c127" "crypto-research-agents.guanacolabs.com"
delete_dns_record "624fc2b936cfdaf35367a8d62d95f7a9" "mcp-bitwarden-enhanced.guanacolabs.com"
delete_dns_record "5a63c5797e5e31e391985de5eed1b177" "mcp-annas-archive.guanacolabs.com"
delete_dns_record "8385016f2e5626ef8836965660c7b205" "mcp-claude-global-config.guanacolabs.com"
delete_dns_record "6841e783f1bf626f846014d6b160c449" "aider-improved.guanacolabs.com"
delete_dns_record "f3d8c6b6e6607dc9acc626cbb7118f3f" "climemory.guanacolabs.com"

# Category 2: Legacy/Development subdomains
echo "=== Category 2: Legacy/Development subdomains ==="
delete_dns_record "92883b798272f542bd39b2263a2171bc" "fireman-dev.guanacolabs.com"
delete_dns_record "411e5e42fec3dc2247d9668ae19f8acf" "edu-senales.guanacolabs.com"
delete_dns_record "d37e1c8afd85d9c4182baae6018be629" "edu-trading.guanacolabs.com"

# Category 3: Duplicated/Superseded projects
echo "=== Category 3: Duplicated/Superseded projects ==="
delete_dns_record "5fa568ee7449996fa0c3a94a8ba8592a" "crypto.guanacolabs.com"
delete_dns_record "910f2d6af4dbbc4c5ced5abee6ce7a1d" "arbitrage.guanacolabs.com"
delete_dns_record "1cd6609eaedac9c3f94346f4e19115f7" "money.guanacolabs.com"
delete_dns_record "8a61603a2d194bc472bc45ce0d2b3cf4" "trading.guanacolabs.com"
delete_dns_record "85264189f004835b39100aaf4fe2e36b" "gmail-ai.guanacolabs.com"
delete_dns_record "ce7ad815a74a9ce601e900750fb76608" "investigador.guanacolabs.com"
delete_dns_record "975f7318bdd8288604425e01f63aaa5c" "scrum-ai.guanacolabs.com"

# Category 4: Projects without landing or inactive
echo "=== Category 4: Projects without landing or inactive ==="
delete_dns_record "a0f055fdecb6622f01febba04ba35893" "debate.guanacolabs.com"
delete_dns_record "cf65fa73687d883f717735f4a0c6a3e8" "mercadopago.guanacolabs.com"
delete_dns_record "5bebc99e645b5860d085d835e2129470" "research.guanacolabs.com"
delete_dns_record "8abcb421c909871b242e83d7b759f014" "rules.guanacolabs.com"
delete_dns_record "613a2ea0b49bee8abfdabebfa6443b43" "memory.guanacolabs.com"

# Category 5: Superseded by newer versions
echo "=== Category 5: Superseded infrastructure domains ==="
delete_dns_record "1378433d7cc1c8c9751b84decb8fc906" "artisview-api.guanacolabs.com"
delete_dns_record "9e091281a8c614700f04a90886ab0234" "artisview.guanacolabs.com"

# Category 6: Domain name mismatches
echo "=== Category 6: Subdomain name mismatches ==="
delete_dns_record "4aae6e5a8ce0b1a08780ff1f8794350b" "agro.guanacolabs.com"

echo ""
echo "=========================================="
echo "Cleanup process completed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Total records processed: 27"
echo "  - Categories: 6"
echo ""
echo "IMPORTANT: Review the output above before proceeding."
echo "Some deletions may have failed if records don't exist."
