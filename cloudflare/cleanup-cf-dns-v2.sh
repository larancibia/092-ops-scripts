#!/bin/bash

# Script mejorado para limpieza DNS Cloudflare
# Sin set -e para que continue con errores

# Credenciales
API_TOKEN="NUXAARmpEp_dWsC9Spb2_FYeGlI3gwrL7JSaPKsg"
ZONE_ID="18b19eaf575c2b7c7d31272741e88a99"

echo "=== LIMPIEZA DNS CLOUDFLARE ==="

# Lista de subdominios a eliminar
SUBDOMAINS_TO_DELETE=(
    # Sin carpeta local
    "crypto-pump-crash-system"
    "crypto-research-agents"
    "mcp-bitwarden-enhanced"
    "mcp-annas-archive"
    "mcp-claude-global-config"
    "aider-improved"
    "climemory"
    # Legacy/Dev
    "fireman-dev"
    "edu-senales"
    "edu-trading"
    # Duplicados
    "crypto"
    "arbitrage"
    "money"
    "trading"
    "gmail-ai"
    "investigador"
    "scrum-ai"
    # Sin proyecto
    "debate"
    "mercadopago"
    "research"
    "rules"
    "memory"
    # Versiones antiguas
    "artisview-api"
    "artisview"
    # Nombres inconsistentes
    "agro"
)

deleted=0
failed=0
not_found=0

for subdomain in "${SUBDOMAINS_TO_DELETE[@]}"; do
    fqdn="${subdomain}.guanacolabs.com"

    # Obtener el ID del registro
    record_id=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${fqdn}&type=A" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

    if [ -z "$record_id" ]; then
        echo "⚠️  ${fqdn} - No encontrado (ya eliminado?)"
        ((not_found++))
        continue
    fi

    # Eliminar el registro
    response=$(curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json")

    success=$(echo "$response" | jq -r '.success')

    if [ "$success" = "true" ]; then
        echo "✅ ${fqdn} - Eliminado"
        ((deleted++))
    else
        error=$(echo "$response" | jq -r '.errors[0].message // "Error desconocido"')
        echo "❌ ${fqdn} - Error: $error"
        ((failed++))
    fi

    sleep 0.5  # Para no saturar la API
done

# Resumen
echo ""
echo "=== RESUMEN ==="
echo "Eliminados exitosamente: $deleted"
echo "No encontrados: $not_found"
echo "Fallidos: $failed"
echo "Total procesados: ${#SUBDOMAINS_TO_DELETE[@]}"

# Listar subdominios restantes
echo ""
echo "=== SUBDOMINIOS RESTANTES ==="
curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&per_page=100" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[] | .name' | sort

exit 0
