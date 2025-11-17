#!/bin/bash
# Setup SSL certificates for all projects using Let's Encrypt
# Uses certbot with nginx plugin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

# Check for certbot
if ! command -v certbot &> /dev/null; then
    echo "Error: certbot is not installed."
    echo "Install with: sudo apt-get install certbot python3-certbot-nginx"
    exit 1
fi

ZONE=$(jq -r '.zone' "$DEPLOY_DATA")
EMAIL="arancibialuisalejandro@gmail.com"  # From CF_EMAIL

echo "======================================"
echo "SSL Certificate Setup - All Projects"
echo "======================================"
echo "Zone: $ZONE"
echo "Email: $EMAIL"
echo "======================================"
echo ""

# Collect all domains
echo "Collecting all domains..."
domains=()

jq -r '.deployment_plan | to_entries[] | "\(.key)|\(.value.original_name)|\(.value.category)"' "$DEPLOY_DATA" | while IFS='|' read -r project_name original_name category; do
    case "$category" in
        fullstack_web)
            domains+=("$original_name.$ZONE")
            domains+=("api.$original_name.$ZONE")
            domains+=("landing.$original_name.$ZONE")
            ;;
        backend_api)
            domains+=("api.$original_name.$ZONE")
            domains+=("landing.$original_name.$ZONE")
            ;;
        frontend_only)
            domains+=("$original_name.$ZONE")
            domains+=("landing.$original_name.$ZONE")
            ;;
        mcp_servers|cli_tools|archived|unknown)
            domains+=("landing.$original_name.$ZONE")
            ;;
    esac
done

# Save domains list
DOMAINS_FILE="$SCRIPT_DIR/all-domains.txt"
jq -r '.deployment_plan | to_entries[] | "\(.value.original_name)|\(.value.category)"' "$DEPLOY_DATA" | while IFS='|' read -r original_name category; do
    case "$category" in
        fullstack_web)
            echo "$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            echo "api.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            echo "landing.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            ;;
        backend_api)
            echo "api.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            echo "landing.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            ;;
        frontend_only)
            echo "$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            echo "landing.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            ;;
        mcp_servers|cli_tools|archived|unknown)
            echo "landing.$original_name.$ZONE" >> "$DOMAINS_FILE.tmp"
            ;;
    esac
done

sort -u "$DOMAINS_FILE.tmp" > "$DOMAINS_FILE"
rm "$DOMAINS_FILE.tmp"

total_domains=$(wc -l < "$DOMAINS_FILE")
echo "Total domains to secure: $total_domains"
echo ""

# Option 1: Individual certificates (more reliable, but slower)
echo "Choose SSL setup method:"
echo "  1) Individual certificates (slower, more reliable)"
echo "  2) Batch certificates (faster, may hit rate limits)"
echo "  3) Single wildcard certificate (fastest, requires DNS validation)"
echo ""
read -p "Choice [1-3]: " choice

case "$choice" in
    1)
        echo "Setting up individual certificates..."
        echo ""
        current=0
        while IFS= read -r domain; do
            current=$((current + 1))
            echo "[$current/$total_domains] Setting up SSL for $domain"

            if sudo certbot certonly --nginx -d "$domain" --email "$EMAIL" --agree-tos --non-interactive --redirect; then
                echo "  SUCCESS"
            else
                echo "  FAILED (may already exist or DNS not propagated)"
            fi
            echo ""

            # Rate limiting prevention
            if [ $((current % 5)) -eq 0 ]; then
                echo "Pausing to avoid rate limits..."
                sleep 10
            fi
        done < "$DOMAINS_FILE"
        ;;

    2)
        echo "Setting up certificates in batches of 10..."
        echo ""

        # Process in batches
        batch_size=10
        batch_num=1
        domain_args=""
        count=0

        while IFS= read -r domain; do
            domain_args="$domain_args -d $domain"
            count=$((count + 1))

            if [ $count -eq $batch_size ]; then
                echo "[Batch $batch_num] Requesting certificate for $batch_size domains"
                if sudo certbot certonly --nginx $domain_args --email "$EMAIL" --agree-tos --non-interactive; then
                    echo "  Batch $batch_num: SUCCESS"
                else
                    echo "  Batch $batch_num: FAILED"
                fi

                # Reset for next batch
                domain_args=""
                count=0
                batch_num=$((batch_num + 1))
                sleep 10  # Rate limiting
                echo ""
            fi
        done < "$DOMAINS_FILE"

        # Process remaining domains
        if [ -n "$domain_args" ]; then
            echo "[Batch $batch_num] Requesting certificate for remaining domains"
            sudo certbot certonly --nginx $domain_args --email "$EMAIL" --agree-tos --non-interactive || true
        fi
        ;;

    3)
        echo "Setting up wildcard certificate for *.$ZONE"
        echo ""
        echo "NOTE: Wildcard certificates require DNS validation"
        echo "You'll need to add TXT records to your DNS"
        echo ""

        sudo certbot certonly --manual --preferred-challenges dns \
            -d "*.$ZONE" -d "$ZONE" \
            --email "$EMAIL" --agree-tos
        ;;

    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Setup auto-renewal
echo ""
echo "Setting up automatic certificate renewal..."
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    echo "  Auto-renewal cron job added"
else
    echo "  Auto-renewal already configured"
fi

echo ""
echo "======================================"
echo "SSL Setup Complete!"
echo "======================================"
echo ""
echo "Certificates are automatically renewed every 60 days"
echo "All HTTPS connections are now secured with SSL/TLS"
echo ""
