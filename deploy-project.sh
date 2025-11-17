#!/bin/bash
# Single Project Deployment Script
# Usage: ./deploy-project.sh <project-name>

set -e

PROJECT_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_CONFIGS_DIR="/home/luis/deployment-configs"
PROJECTS_DIR="/home/luis/projects"
LANDING_PAGES_DIR="/var/www/landing-pages"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name>"
    echo "Example: $0 AutoScribe"
    exit 1
fi

# Load deployment data
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"
if [ ! -f "$DEPLOY_DATA" ]; then
    echo "Error: Deployment data not found at $DEPLOY_DATA"
    exit 1
fi

# Get project info
PROJECT_INFO=$(jq -r ".deployment_plan[\"$PROJECT_NAME\"]" "$DEPLOY_DATA")
if [ "$PROJECT_INFO" == "null" ]; then
    echo "Error: Project '$PROJECT_NAME' not found in deployment plan"
    exit 1
fi

ORIGINAL_NAME=$(echo "$PROJECT_INFO" | jq -r '.original_name')
CATEGORY=$(echo "$PROJECT_INFO" | jq -r '.category')
STATUS=$(echo "$PROJECT_INFO" | jq -r '.status')
PRIORITY=$(echo "$PROJECT_INFO" | jq -r '.priority')

echo "======================================"
echo "Deploying Project: $PROJECT_NAME"
echo "======================================"
echo "Original Name: $ORIGINAL_NAME"
echo "Category: $CATEGORY"
echo "Priority: $PRIORITY"
echo "Status: $STATUS"
echo "======================================"
echo ""

# Step 1: Deploy nginx configs
echo "[1/5] Deploying Nginx configurations..."
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled

for config in "$DEPLOY_CONFIGS_DIR/$PROJECT_NAME"/nginx-*.conf; do
    if [ -f "$config" ]; then
        config_name=$(basename "$config")
        echo "  Installing $config_name"
        sudo cp "$config" "/etc/nginx/sites-available/${PROJECT_NAME}-${config_name}"
        sudo ln -sf "/etc/nginx/sites-available/${PROJECT_NAME}-${config_name}" \
                    "/etc/nginx/sites-enabled/${PROJECT_NAME}-${config_name}"
    fi
done

# Test nginx config
if ! sudo nginx -t 2>/dev/null; then
    echo "Error: Nginx configuration test failed!"
    exit 1
fi

echo "  Nginx configs deployed successfully"
echo ""

# Step 2: Deploy Docker containers (if applicable)
echo "[2/5] Deploying Docker containers..."
if [ "$CATEGORY" == "mcp_servers" ] || [ "$CATEGORY" == "cli_tools" ] || [ "$CATEGORY" == "archived" ]; then
    echo "  Skipping Docker deployment for $CATEGORY project"
else
    COMPOSE_FILE="$DEPLOY_CONFIGS_DIR/$PROJECT_NAME/docker-compose.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        echo "  Starting containers with docker-compose"
        cd "$PROJECTS_DIR/$PROJECT_NAME"

        # Copy generated docker-compose if it doesn't exist
        if [ ! -f "docker-compose.yml" ]; then
            cp "$COMPOSE_FILE" "docker-compose.yml"
        fi

        # Start containers
        docker-compose pull 2>/dev/null || true
        docker-compose up -d --build
        echo "  Containers started successfully"
    else
        echo "  No docker-compose.yml found, checking for existing deployment"
        # Check if containers are already running
        if docker ps | grep -q "$PROJECT_NAME"; then
            echo "  Containers already running"
        else
            echo "  Warning: No deployment method found"
        fi
    fi
fi
echo ""

# Step 3: Setup landing page
echo "[3/5] Setting up landing page..."
sudo mkdir -p "$LANDING_PAGES_DIR/$ORIGINAL_NAME"
LANDING_SRC="$PROJECTS_DIR/$PROJECT_NAME/landing-page"

if [ -d "$LANDING_SRC" ]; then
    echo "  Copying landing page from project directory"
    sudo cp -r "$LANDING_SRC"/* "$LANDING_PAGES_DIR/$ORIGINAL_NAME/"
else
    echo "  Creating default landing page"
    sudo tee "$LANDING_PAGES_DIR/$ORIGINAL_NAME/index.html" > /dev/null <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJECT_NAME - GuanacoLabs</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #333; }
        .status { padding: 10px; background: #f0f0f0; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>$PROJECT_NAME</h1>
    <div class="status">
        <p><strong>Status:</strong> $STATUS</p>
        <p><strong>Category:</strong> $CATEGORY</p>
        <p><strong>Priority:</strong> $PRIORITY</p>
    </div>
    <p>This is the landing page for $PROJECT_NAME.</p>
    <p>Project documentation and details will be added soon.</p>
    <hr>
    <p><small>&copy; 2025 GuanacoLabs. All rights reserved.</small></p>
</body>
</html>
EOF
fi
echo "  Landing page deployed"
echo ""

# Step 4: Reload nginx
echo "[4/5] Reloading Nginx..."
sudo nginx -s reload
echo "  Nginx reloaded"
echo ""

# Step 5: Health check
echo "[5/5] Performing health check..."
sleep 3

# Check if docker containers are running (if applicable)
if [ "$CATEGORY" != "mcp_servers" ] && [ "$CATEGORY" != "cli_tools" ] && [ "$CATEGORY" != "archived" ]; then
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo "  Docker containers: HEALTHY"
    else
        echo "  Docker containers: WARNING - Some containers may not be running"
    fi
fi

# Check nginx config
if sudo nginx -t 2>/dev/null; then
    echo "  Nginx config: VALID"
else
    echo "  Nginx config: ERROR"
fi

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Access points:"
MAIN_DOMAIN=$(echo "$PROJECT_INFO" | jq -r '.subdomains.main')
API_DOMAIN=$(echo "$PROJECT_INFO" | jq -r '.subdomains.api')
LANDING_DOMAIN=$(echo "$PROJECT_INFO" | jq -r '.subdomains.landing')

echo "  Landing Page: http://$LANDING_DOMAIN (after DNS setup)"
if [ "$CATEGORY" == "fullstack_web" ] || [ "$CATEGORY" == "frontend_only" ]; then
    echo "  Main App: http://$MAIN_DOMAIN (after DNS setup)"
fi
if [ "$CATEGORY" == "fullstack_web" ] || [ "$CATEGORY" == "backend_api" ]; then
    echo "  API: http://$API_DOMAIN (after DNS setup)"
fi

echo ""
echo "Next steps:"
echo "  1. Setup DNS records: ./setup-dns.sh $PROJECT_NAME"
echo "  2. Setup SSL certificates: ./setup-ssl.sh $PROJECT_NAME"
echo "======================================"
