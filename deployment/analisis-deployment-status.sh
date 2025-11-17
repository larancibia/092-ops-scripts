#!/bin/bash

# Script para analizar cuántos repos están deployados vs cuántos faltan

echo "=== ANÁLISIS DE DEPLOYMENT STATUS ==="
echo ""

# Obtener todos los repos activos de GitHub
echo "Obteniendo lista de repositorios de GitHub..."
REPOS=$(gh repo list --limit 1000 --json name,isArchive | jq -r '.[] | select(.isArchive == false) | .name')
TOTAL_REPOS=$(echo "$REPOS" | wc -l)

echo "Total de repositorios activos: $TOTAL_REPOS"
echo ""

# Obtener subdominios activos en Cloudflare
echo "Obteniendo subdominios activos en Cloudflare..."
SUBDOMAINS=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/18b19eaf575c2b7c7d31272741e88a99/dns_records?type=A&per_page=200" \
    -H "Authorization: Bearer NUXAARmpEp_dWsC9Spb2_FYeGlI3gwrL7JSaPKsg" \
    -H "Content-Type: application/json" | jq -r '.result[].name' | grep "guanacolabs.com")

TOTAL_SUBDOMAINS=$(echo "$SUBDOMAINS" | wc -l)
echo "Total de subdominios: $TOTAL_SUBDOMAINS"
echo ""

# Infraestructura que no es proyecto
INFRASTRUCTURE=(
    "guanacolabs.com"
    "www.guanacolabs.com"
    "hub.guanacolabs.com"
    "mail.guanacolabs.com"
    "vault.guanacolabs.com"
    "grafana.guanacolabs.com"
    "prometheus.guanacolabs.com"
    "nextcloud.guanacolabs.com"
    "uptime.guanacolabs.com"
    "jelly.guanacolabs.com"
)

# Contar subdominios que son proyectos (no infraestructura)
project_subdomains=0
for subdomain in $SUBDOMAINS; do
    is_infra=false
    for infra in "${INFRASTRUCTURE[@]}"; do
        if [ "$subdomain" == "$infra" ]; then
            is_infra=true
            break
        fi
    done
    if [ "$is_infra" == "false" ]; then
        ((project_subdomains++))
    fi
done

echo "Subdominios de infraestructura: ${#INFRASTRUCTURE[@]}"
echo "Subdominios de proyectos: $project_subdomains"
echo ""

# Calcular repos sin deployment
repos_sin_deployment=$((TOTAL_REPOS - project_subdomains))

echo "=== RESUMEN ==="
echo "Total de repos activos en GitHub: $TOTAL_REPOS"
echo "Proyectos con subdominio/landing: $project_subdomains"
echo "Repos SIN deployment: $repos_sin_deployment"
echo ""

# Calcular porcentajes
deployed_percent=$((project_subdomains * 100 / TOTAL_REPOS))
pending_percent=$((repos_sin_deployment * 100 / TOTAL_REPOS))

echo "Deployados: $deployed_percent%"
echo "Pendientes: $pending_percent%"
echo ""

# Listar repos sin deployment (muestra los primeros 20)
echo "=== REPOS SIN DEPLOYMENT (primeros 20) ==="
echo ""

count=0
for repo in $REPOS; do
    # Convertir nombre de repo a posible subdominio
    subdomain_name=$(echo "$repo" | tr '_' '-' | tr '[:upper:]' '[:lower:]')

    # Verificar si existe subdominio
    has_subdomain=false
    for subdomain in $SUBDOMAINS; do
        if echo "$subdomain" | grep -q "$subdomain_name"; then
            has_subdomain=true
            break
        fi
    done

    if [ "$has_subdomain" == "false" ]; then
        echo "  - $repo"
        ((count++))
        if [ $count -ge 20 ]; then
            break
        fi
    fi
done

echo ""
echo "... y $((repos_sin_deployment - count)) más"

exit 0
