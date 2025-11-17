#!/bin/bash
#
# Script para verificar estado de deployment
# Revisa qué proyectos están listos para producción
#

echo "=================================================="
echo "🔍 Estado de Deployment - GuanacoLabs Projects"
echo "=================================================="
echo ""

# Proyectos con landings generadas
PROJECTS=(
    "coderx-ai-assistant:CoderX:coderx:/home/luis/coderx-ai-assistant"
    "agro-platform:AgroInsight:agroplatform:/home/luis/projects/active/agriculture/agro-platform"
    "password-rotation-game:PassGuard:passguard:/home/luis/password-rotation-game"
    "ai-scrum-team:AI Scrum Team:ai-scrum-team:/home/luis/projects/active/ai/ai-scrum-team"
    "canopy-lang:Canopy Lang:canopy-lang:/home/luis/canopy-lang"
)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "📊 Verificando estado de proyectos prioritarios..."
echo ""

total=0
landing_ready=0
nginx_ready=0
dns_ready=0
ssl_ready=0

for project_data in "${PROJECTS[@]}"; do
    IFS=':' read -r project_id name subdomain path <<< "$project_data"
    ((total++))

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 $name${NC} (${project_id})"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check 1: Landing generada
    if [ -f "/home/luis/generated-landings/$project_id/index.html" ]; then
        echo -e "  Landing generada:    ${GREEN}✅ Sí${NC}"
        ((landing_ready++))
    else
        echo -e "  Landing generada:    ${RED}❌ No${NC}"
    fi

    # Check 2: Landing copiada a proyecto
    if [ -f "$path/landing/index.html" ]; then
        echo -e "  Landing en proyecto: ${GREEN}✅ Sí${NC}"
    else
        echo -e "  Landing en proyecto: ${YELLOW}⚠️  No copiada${NC}"
    fi

    # Check 3: Nginx config
    if [ -f "/etc/nginx/sites-enabled/${subdomain}.conf" ] || \
       [ -f "/etc/nginx/sites-enabled/${subdomain}-guanacolabs.conf" ]; then
        echo -e "  Nginx config:        ${GREEN}✅ Configurado${NC}"
        ((nginx_ready++))
    else
        echo -e "  Nginx config:        ${YELLOW}⚠️  No configurado${NC}"
    fi

    # Check 4: DNS (verificar con dig)
    dns_result=$(dig +short ${subdomain}.guanacolabs.com 2>/dev/null)
    if [ -n "$dns_result" ]; then
        echo -e "  DNS:                 ${GREEN}✅ Resuelve a: $dns_result${NC}"
        ((dns_ready++))
    else
        echo -e "  DNS:                 ${YELLOW}⚠️  No configurado${NC}"
    fi

    # Check 5: SSL (verificar con curl)
    if curl -sk "https://${subdomain}.guanacolabs.com" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "^[23]"; then
        echo -e "  SSL:                 ${GREEN}✅ Activo${NC}"
        ((ssl_ready++))
    else
        echo -e "  SSL:                 ${YELLOW}⚠️  No configurado${NC}"
    fi

    # Status general del proyecto
    echo ""
    if [ -f "$path/landing/index.html" ] && \
       [ -f "/etc/nginx/sites-enabled/${subdomain}.conf" -o -f "/etc/nginx/sites-enabled/${subdomain}-guanacolabs.conf" ] && \
       [ -n "$dns_result" ]; then
        echo -e "  ${GREEN}🚀 Estado: LISTO PARA PRODUCCIÓN${NC}"
    else
        echo -e "  ${YELLOW}⚙️  Estado: REQUIERE CONFIGURACIÓN${NC}"
    fi

    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 RESUMEN GENERAL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Total proyectos verificados: $total"
echo ""
echo -e "Landings generadas:  ${GREEN}$landing_ready${NC}/$total"
echo -e "Nginx configurado:   ${GREEN}$nginx_ready${NC}/$total"
echo -e "DNS configurado:     ${GREEN}$dns_ready${NC}/$total"
echo -e "SSL activo:          ${GREEN}$ssl_ready${NC}/$total"
echo ""

# Calcular porcentaje de completitud
completion=$((($landing_ready + $nginx_ready + $dns_ready + $ssl_ready) * 100 / ($total * 4)))
echo -e "Completitud general: ${GREEN}${completion}%${NC}"
echo ""

# Próximos pasos
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 PRÓXIMOS PASOS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $landing_ready -lt $total ]; then
    echo "1. Generar landings faltantes:"
    echo "   python3 /home/luis/landing-generator.py"
    echo ""
fi

if [ $nginx_ready -lt $total ]; then
    echo "2. Configurar Nginx:"
    echo "   ./deploy-landings.sh"
    echo ""
fi

if [ $dns_ready -lt $total ]; then
    echo "3. Configurar DNS en Cloudflare"
    echo "   Ver: /home/luis/mi-wiki/proyectos-auditoria-2025-11-17.md"
    echo ""
fi

if [ $ssl_ready -lt $total ]; then
    echo "4. Configurar SSL:"
    echo "   sudo certbot --nginx -d [subdominio].guanacolabs.com"
    echo ""
fi

echo "📚 Documentación completa:"
echo "   /home/luis/QUICK-START.md"
echo "   /home/luis/AUTOMATIZACION-COMPLETA-README.md"
echo ""
