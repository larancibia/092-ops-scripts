#!/bin/bash

# Script para ejecutar la limpieza de DNS en Cloudflare
# Basado en el análisis completo de proyectos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== LIMPIEZA DNS CLOUDFLARE - GUANACOLABS.COM ==="
echo ""

# Configurar credenciales
CLOUDFLARE_API_TOKEN="NUXAARmpEp_dWsC9Spb2_FYeGlI3gwrL7JSaPKsg"
CLOUDFLARE_ZONE_ID="18b19eaf575c2b7c7d31272741e88a99"

# Función para eliminar un registro DNS
delete_dns_record() {
    local name=$1
    local record_id=$2
    local reason=$3

    echo -ne "${YELLOW}Eliminando${NC} $name... "

    response=$(curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json")

    success=$(echo "$response" | jq -r '.success')

    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✓${NC} Eliminado ($reason)"
        return 0
    else
        error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        echo -e "${RED}✗${NC} Error: $error"
        return 1
    fi
}

echo "Obteniendo lista actual de registros DNS..."
DNS_RECORDS=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&per_page=200" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json")

TOTAL_BEFORE=$(echo "$DNS_RECORDS" | jq -r '.result | length')
echo "Total de registros antes: $TOTAL_BEFORE"
echo ""

# Contadores
deleted=0
failed=0

echo "=== Iniciando eliminación de subdominios ==="
echo ""

# Categoría 1: Sin carpeta local (8)
echo "${YELLOW}Categoría 1: Sin carpeta local${NC}"
for subdomain in \
    "api-keys-dashboard" \
    "crypto-pump-crash-system" \
    "crypto-research-agents" \
    "mcp-bitwarden-enhanced" \
    "mcp-annas-archive" \
    "mcp-claude-global-config" \
    "aider-improved" \
    "climemory"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Sin carpeta local"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Categoría 2: Legacy/Dev (3)
echo "${YELLOW}Categoría 2: Legacy/Dev${NC}"
for subdomain in \
    "fireman-dev" \
    "edu-senales" \
    "edu-trading"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Legacy/Dev obsoleto"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Categoría 3: Duplicados (7)
echo "${YELLOW}Categoría 3: Duplicados${NC}"
for subdomain in \
    "crypto" \
    "arbitrage" \
    "money" \
    "trading" \
    "gmail-ai" \
    "investigador" \
    "scrum-ai"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Duplicado genérico"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Categoría 4: Sin proyecto (5)
echo "${YELLOW}Categoría 4: Sin proyecto${NC}"
for subdomain in \
    "debate" \
    "mercadopago" \
    "research" \
    "rules" \
    "memory"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Sin proyecto correspondiente"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Categoría 5: Versiones antiguas (2)
echo "${YELLOW}Categoría 5: Versiones antiguas${NC}"
for subdomain in \
    "artisview-api" \
    "artisview"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Versión antigua"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Categoría 6: Nombres inconsistentes (2)
echo "${YELLOW}Categoría 6: Nombres inconsistentes${NC}"
for subdomain in \
    "agro"
do
    record_id=$(echo "$DNS_RECORDS" | jq -r ".result[] | select(.name==\"${subdomain}.guanacolabs.com\") | .id")
    if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
        if delete_dns_record "${subdomain}.guanacolabs.com" "$record_id" "Nombre inconsistente (usar agro-platform)"; then
            ((deleted++))
        else
            ((failed++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} ${subdomain}.guanacolabs.com no encontrado"
    fi
done
echo ""

# Obtener total después
DNS_RECORDS_AFTER=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&per_page=200" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json")

TOTAL_AFTER=$(echo "$DNS_RECORDS_AFTER" | jq -r '.result | length')

echo "=== RESUMEN DE LIMPIEZA ==="
echo -e "Total ANTES:     ${YELLOW}${TOTAL_BEFORE}${NC} subdominios"
echo -e "Total DESPUÉS:   ${GREEN}${TOTAL_AFTER}${NC} subdominios"
echo -e "Eliminados:      ${GREEN}${deleted}${NC}"
echo -e "Fallidos:        ${RED}${failed}${NC}"
echo -e "Reducción:       ${GREEN}$(( (TOTAL_BEFORE - TOTAL_AFTER) * 100 / TOTAL_BEFORE ))%${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ Limpieza completada exitosamente${NC}"
else
    echo -e "${YELLOW}⚠ Limpieza completada con algunos errores${NC}"
fi

echo ""
echo "Subdominios restantes:"
echo "$DNS_RECORDS_AFTER" | jq -r '.result[] | .name' | sort

exit 0
