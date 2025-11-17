#!/bin/bash

# Script para obtener credenciales de Cloudflare desde Bitwarden y ejecutar limpieza de DNS

echo "=== Obteniendo credenciales de Cloudflare desde Bitwarden ==="

# Configurar sesión de Bitwarden
export BW_SESSION="2Ybz/mAI6x8xJ9W7Zvs6S0Mo5dxgShPeMaUK6eaT121dKD4pCqdy3ql4MbLA1GCWrkexELH3mRMmCiwoQFhKLg=="

# Buscar el item de Cloudflare en Bitwarden
echo "Buscando credenciales de Cloudflare..."
CLOUDFLARE_ITEM=$(bw list items --search "cloudflare" --session "$BW_SESSION" 2>/dev/null | jq -r '.[0]')

if [ -z "$CLOUDFLARE_ITEM" ] || [ "$CLOUDFLARE_ITEM" = "null" ]; then
    echo "❌ No se encontró item de Cloudflare en Bitwarden"
    echo "Usando credenciales del archivo de configuración MCP..."

    # Extraer del archivo mcp.json
    CLOUDFLARE_API_TOKEN="NUXAARmpEp_dWsC9Spb2_FYeGlI3gwrL7JSaPKsg"
    CLOUDFLARE_ACCOUNT_ID="5de70f4ba8110b9cf400a3157ff420c3"
else
    echo "✅ Credenciales encontradas en Bitwarden"

    # Extraer las credenciales del item
    CLOUDFLARE_API_TOKEN=$(echo "$CLOUDFLARE_ITEM" | jq -r '.login.password // empty')

    # Buscar Account ID en custom fields o notes
    CLOUDFLARE_ACCOUNT_ID=$(echo "$CLOUDFLARE_ITEM" | jq -r '.fields[] | select(.name=="account_id" or .name=="ACCOUNT_ID") | .value // empty')

    if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
        CLOUDFLARE_ACCOUNT_ID="5de70f4ba8110b9cf400a3157ff420c3"
    fi
fi

# Obtener Zone ID de guanacolabs.com
echo "Obteniendo Zone ID de guanacolabs.com..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=guanacolabs.com" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

CLOUDFLARE_ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // empty')

if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo "❌ Error al obtener Zone ID. Respuesta de API:"
    echo "$ZONE_RESPONSE" | jq .
    exit 1
fi

echo "✅ Zone ID obtenido: $CLOUDFLARE_ZONE_ID"

# Exportar variables
export CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ACCOUNT_ID
export CLOUDFLARE_ZONE_ID

echo ""
echo "=== Credenciales configuradas ==="
echo "Account ID: $CLOUDFLARE_ACCOUNT_ID"
echo "Zone ID: $CLOUDFLARE_ZONE_ID"
echo "API Token: ${CLOUDFLARE_API_TOKEN:0:10}..."
echo ""

# Listar registros DNS actuales
echo "=== Listando registros DNS actuales ==="
DNS_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&per_page=200" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json")

TOTAL_RECORDS=$(echo "$DNS_RECORDS" | jq -r '.result | length')
echo "Total de registros A: $TOTAL_RECORDS"
echo ""

# Mostrar los primeros 10
echo "Primeros registros:"
echo "$DNS_RECORDS" | jq -r '.result[0:10][] | "\(.name) -> \(.content)"'

echo ""
echo "=== Script completado ==="
echo "Las credenciales están disponibles en las variables de entorno."
echo "Para usarlas en otro script: source get-cloudflare-credentials.sh"
