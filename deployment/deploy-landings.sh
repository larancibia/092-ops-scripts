#!/bin/bash
#
# Script de deployment de landings generadas
# Copia landings a carpetas de proyecto y genera configs nginx
#

set -e

echo "=================================================="
echo "🚀 Deployment de Landings GuanacoLabs"
echo "=================================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

GENERATED_DIR="/home/luis/generated-landings"
SERVER_IP="YOUR_SERVER_IP_HERE"  # CAMBIAR por IP real

# Mapeo de proyecto a carpeta local
declare -A PROJECT_PATHS=(
    ["coderx-ai-assistant"]="/home/luis/coderx-ai-assistant"
    ["agro-platform"]="/home/luis/projects/active/agriculture/agro-platform"
    ["password-rotation-game"]="/home/luis/password-rotation-game"
    ["ai-scrum-team"]="/home/luis/projects/active/ai/ai-scrum-team"
    ["canopy-lang"]="/home/luis/canopy-lang"
    ["ai-investigador-system"]="/home/luis/projects/active/ai/ai-investigador-system"
    ["ai-dev-team"]="/home/luis/projects/active/ai/ai-dev-team"
    ["money-maker-system"]="/home/luis/projects/active/money-maker-system"
    ["web-maxwell"]="/home/luis/projects/active/web/web-maxwell"
    ["trading-strategy"]="/home/luis/projects/active/finance/trading-strategy"
    ["platform-deployer"]="/home/luis/projects/active/platform-deployer"
)

# Mapeo a subdominios
declare -A SUBDOMAINS=(
    ["coderx-ai-assistant"]="coderx"
    ["agro-platform"]="agroplatform"
    ["password-rotation-game"]="passguard"
    ["ai-scrum-team"]="ai-scrum-team"
    ["canopy-lang"]="canopy-lang"
    ["ai-investigador-system"]="ai-investigador"
    ["ai-dev-team"]="ai-dev-team"
    ["money-maker-system"]="money-maker"
    ["web-maxwell"]="maxwell"
    ["trading-strategy"]="trading-strategy"
    ["platform-deployer"]="platform-deployer"
)

# Función para copiar landing a proyecto
copy_landing() {
    local project="$1"
    local project_path="${PROJECT_PATHS[$project]}"

    if [ -z "$project_path" ]; then
        echo -e "${RED}❌ Ruta no definida para: $project${NC}"
        return 1
    fi

    if [ ! -d "$project_path" ]; then
        echo -e "${YELLOW}⚠️  Carpeta no existe: $project_path${NC}"
        return 1
    fi

    # Crear carpeta landing si no existe
    mkdir -p "$project_path/landing"

    # Copiar landing
    cp "$GENERATED_DIR/$project/index.html" "$project_path/landing/index.html"

    echo -e "${GREEN}✅ Landing copiada: $project_path/landing/index.html${NC}"
    return 0
}

# Función para generar config nginx
generate_nginx_config() {
    local project="$1"
    local subdomain="${SUBDOMAINS[$project]}"
    local project_path="${PROJECT_PATHS[$project]}"

    if [ -z "$subdomain" ]; then
        echo -e "${RED}❌ Subdominio no definido para: $project${NC}"
        return 1
    fi

    local config_file="/tmp/nginx-$subdomain.conf"

    cat > "$config_file" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $subdomain.guanacolabs.com;

    root $project_path/landing;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    echo -e "${GREEN}✅ Config nginx generada: $config_file${NC}"
    echo -e "${YELLOW}   Para instalar:${NC}"
    echo -e "${YELLOW}   sudo cp $config_file /etc/nginx/sites-available/$subdomain.conf${NC}"
    echo -e "${YELLOW}   sudo ln -s /etc/nginx/sites-available/$subdomain.conf /etc/nginx/sites-enabled/${NC}"
    echo -e "${YELLOW}   sudo nginx -t && sudo systemctl reload nginx${NC}"
    echo ""

    return 0
}

# Función para generar comando Cloudflare
generate_cloudflare_cmd() {
    local subdomain="$1"

    cat << EOF
# $subdomain.guanacolabs.com
curl -X POST 'https://api.cloudflare.com/client/v4/zones/\$CLOUDFLARE_ZONE_ID/dns_records' \\
  -H 'Authorization: Bearer \$CLOUDFLARE_API_TOKEN' \\
  -H 'Content-Type: application/json' \\
  --data '{"type":"A","name":"$subdomain","content":"$SERVER_IP","proxied":true}'

EOF
}

# Proceso principal
echo "1️⃣  Copiando landings a carpetas de proyecto..."
echo ""

copied=0
failed=0

for project in "${!PROJECT_PATHS[@]}"; do
    if [ -f "$GENERATED_DIR/$project/index.html" ]; then
        if copy_landing "$project"; then
            ((copied++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠️  Landing no encontrada: $project${NC}"
    fi
done

echo ""
echo "=================================================="
echo "2️⃣  Generando configuraciones nginx..."
echo ""

for project in "${!SUBDOMAINS[@]}"; do
    if [ -f "$GENERATED_DIR/$project/index.html" ]; then
        generate_nginx_config "$project"
    fi
done

echo ""
echo "=================================================="
echo "3️⃣  Comandos Cloudflare DNS"
echo "=================================================="
echo ""
echo "Ejecutar estos comandos después de configurar:"
echo "export CLOUDFLARE_API_TOKEN=\"tu_token\""
echo "export CLOUDFLARE_ZONE_ID=\"tu_zone_id\""
echo ""

for project in "${!SUBDOMAINS[@]}"; do
    if [ -f "$GENERATED_DIR/$project/index.html" ]; then
        generate_cloudflare_cmd "${SUBDOMAINS[$project]}"
    fi
done

echo ""
echo "=================================================="
echo "📊 Resumen"
echo "=================================================="
echo -e "${GREEN}✅ Landings copiadas: $copied${NC}"
echo -e "${RED}❌ Fallos: $failed${NC}"
echo ""
echo "📂 Configs nginx generadas en: /tmp/nginx-*.conf"
echo ""
echo "✨ Próximos pasos:"
echo "   1. Revisar las landings copiadas"
echo "   2. Instalar configs nginx (ver comandos arriba)"
echo "   3. Configurar DNS en Cloudflare"
echo "   4. Configurar SSL con certbot"
echo ""
