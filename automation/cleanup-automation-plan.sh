#!/bin/bash
# Script de limpieza automatizada para servidor GuanacoLabs
# IMPORTANTE: Revisar antes de ejecutar - NO ejecutar todo de una vez

set -e

echo "=================================="
echo "SERVIDOR GUANACOLABS - CLEANUP"
echo "Generado: $(date)"
echo "=================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funciones
backup_repos_with_changes() {
    echo -e "${YELLOW}[1/10] Backup repos con cambios sin commit...${NC}"
    
    BACKUP_DIR="/home/luis/backups/repos-backup-$(date +%Y%m%d)"
    mkdir -p "$BACKUP_DIR"
    
    REPOS_WITH_CHANGES=(
        "/home/luis/.claude/mcp-servers/annas-archive"
        "/home/luis/.claude/mcp-servers/bitwarden"
        "/home/luis/.claude/mcp-servers/google-photos"
        "/home/luis/.claude/mcp-servers/whatsapp"
        "/home/luis/ai-dev-team"
        "/home/luis/ai-gmail-organizer"
        "/home/luis/api-keys-dashboard-nextjs"
        "/home/luis/canopy-lang"
        "/home/luis/dev-qr-code-generator"
        "/home/luis/mailcow-dockerized"
        "/home/luis/mcp-collection"
        "/home/luis/projects/active/agriculture/agro-management-app"
        "/home/luis/projects/active/agro-management-app"
        "/home/luis/projects/active/ai/ai-gmail-organizer"
        "/home/luis/projects/active/ai/ai-scrum-team"
        "/home/luis/projects/active/middleware-mercadopago"
        "/home/luis/projects/active/money-maker-system"
        "/home/luis/projects/active/platform-deployer"
        "/home/luis/projects/active/web-agent"
        "/home/luis/projects/active/web/web-autoscribe"
        "/home/luis/projects/artisview-modo-dios"
        "/home/luis/projects/company/company-guanacolabs-projects-hub"
        "/home/luis/projects/company/company-guanacolabs-website"
        "/home/luis/projects/experiments/autonomous-driver-agent"
        "/home/luis/projects/experiments/claude-mcp-global-config"
        "/home/luis/trading-latino-academy"
    )
    
    for repo in "${REPOS_WITH_CHANGES[@]}"; do
        if [ -d "$repo" ]; then
            repo_name=$(basename "$repo")
            echo "  Backing up: $repo_name"
            cp -r "$repo" "$BACKUP_DIR/$repo_name"
        fi
    done
    
    echo -e "${GREEN}Backup completado en: $BACKUP_DIR${NC}"
}

organize_markdown_files() {
    echo -e "${YELLOW}[2/10] Organizando archivos .md...${NC}"
    
    mkdir -p /home/luis/mi-wiki/{deployment,infrastructure,cloudflare,bitwarden,github,guides,reports}
    
    # Deployment
    mv /home/luis/GUANACOLABS_DEPLOYMENT_PLAN.md /home/luis/mi-wiki/deployment/ 2>/dev/null || true
    mv /home/luis/deployment-gap-analysis.md /home/luis/mi-wiki/deployment/ 2>/dev/null || true
    mv /home/luis/GUANACOLABS_AGENT_ASSIGNMENT_MATRIX.md /home/luis/mi-wiki/deployment/ 2>/dev/null || true
    mv /home/luis/GUANACOLABS_PROJECTS_COMMERCIAL_NAMES.md /home/luis/mi-wiki/deployment/ 2>/dev/null || true
    
    # Infrastructure
    mv /home/luis/INFRASTRUCTURE*.md /home/luis/mi-wiki/infrastructure/ 2>/dev/null || true
    mv /home/luis/DNS-SETUP-GUIDE.md /home/luis/mi-wiki/infrastructure/ 2>/dev/null || true
    mv /home/luis/DATABASE_CREDENTIALS_SECURE.md /home/luis/mi-wiki/infrastructure/ 2>/dev/null || true
    
    # Cloudflare
    mv /home/luis/*CLOUDFLARE*.md /home/luis/mi-wiki/cloudflare/ 2>/dev/null || true
    mv /home/luis/*cloudflare*.md /home/luis/mi-wiki/cloudflare/ 2>/dev/null || true
    
    # Bitwarden
    mv /home/luis/BITWARDEN*.md /home/luis/mi-wiki/bitwarden/ 2>/dev/null || true
    
    # GitHub
    mv /home/luis/GITHUB*.md /home/luis/mi-wiki/github/ 2>/dev/null || true
    mv /home/luis/REPOS*.md /home/luis/mi-wiki/github/ 2>/dev/null || true
    
    # Guides
    mv /home/luis/CONTRIBUTING.md /home/luis/mi-wiki/guides/ 2>/dev/null || true
    mv /home/luis/README.md /home/luis/mi-wiki/guides/ 2>/dev/null || true
    mv /home/luis/START-HERE.md /home/luis/mi-wiki/guides/ 2>/dev/null || true
    mv /home/luis/QUICK*.md /home/luis/mi-wiki/guides/ 2>/dev/null || true
    mv /home/luis/AUTOMATIZACION*.md /home/luis/mi-wiki/guides/ 2>/dev/null || true
    
    echo -e "${GREEN}Archivos .md organizados${NC}"
}

archive_old_reports() {
    echo -e "${YELLOW}[3/10] Archivando reportes viejos...${NC}"
    
    mkdir -p /home/luis/docs/archive
    
    mv /home/luis/MIGRATION*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/INFORME*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/REPORTE*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/*REPORT*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/*SUMMARY*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/SESSION*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/CLEANUP*.md /home/luis/docs/archive/ 2>/dev/null || true
    mv /home/luis/FILES*.md /home/luis/docs/archive/ 2>/dev/null || true
    
    echo -e "${GREEN}Reportes archivados${NC}"
}

organize_scripts() {
    echo -e "${YELLOW}[4/10] Organizando scripts...${NC}"
    
    mkdir -p /home/luis/scripts/{deployment,cloudflare,bitwarden,monitoring,utils}
    
    # Deployment
    mv /home/luis/deploy-landings.sh /home/luis/scripts/deployment/ 2>/dev/null || true
    mv /home/luis/check-deployment-status.sh /home/luis/scripts/deployment/ 2>/dev/null || true
    mv /home/luis/analisis-deployment-status.sh /home/luis/scripts/deployment/ 2>/dev/null || true
    
    # Cloudflare
    mv /home/luis/add-dns-record-cloudflare.sh /home/luis/scripts/cloudflare/ 2>/dev/null || true
    mv /home/luis/cleanup-cloudflare-dns.sh /home/luis/scripts/cloudflare/ 2>/dev/null || true
    mv /home/luis/cleanup-cf-dns-v2.sh /home/luis/scripts/cloudflare/ 2>/dev/null || true
    mv /home/luis/execute-cloudflare-cleanup.sh /home/luis/scripts/cloudflare/ 2>/dev/null || true
    mv /home/luis/get-cloudflare-credentials.sh /home/luis/scripts/cloudflare/ 2>/dev/null || true
    
    # Bitwarden
    mv /home/luis/add-climemory*.sh /home/luis/scripts/bitwarden/ 2>/dev/null || true
    mv /home/luis/bitwarden*.sh /home/luis/scripts/bitwarden/ 2>/dev/null || true
    mv /home/luis/run_bitwarden*.sh /home/luis/scripts/bitwarden/ 2>/dev/null || true
    
    # Utils
    mv /home/luis/cleanup-nginx-configs.sh /home/luis/scripts/utils/ 2>/dev/null || true
    mv /home/luis/health-check.sh /home/luis/scripts/utils/ 2>/dev/null || true
    mv /home/luis/create-dirs.sh /home/luis/scripts/utils/ 2>/dev/null || true
    mv /home/luis/user-tools.sh /home/luis/scripts/utils/ 2>/dev/null || true
    
    echo -e "${GREEN}Scripts organizados${NC}"
}

clean_junk_files() {
    echo -e "${YELLOW}[5/10] Limpiando archivos basura...${NC}"
    
    # Logs
    rm -f /home/luis/*.log
    rm -f /home/luis/backend-pid.txt
    
    # Imagenes temporales
    rm -f /home/luis/documento*.jpg
    rm -f /home/luis/IMG-*.jpg
    
    # Archivos temporales
    rm -f /home/luis/claude-conversation-logs.txt
    rm -f /home/luis/nextcloud-data-inventory.txt
    rm -f /home/luis/repos-remotes-unique.txt
    rm -f /home/luis/thread.log
    
    # TXT temporales
    rm -f /home/luis/*COMPLETE*.txt
    rm -f /home/luis/cloudflare-cleanup-*.txt
    
    echo -e "${GREEN}Archivos basura eliminados${NC}"
}

consolidate_nginx_backups() {
    echo -e "${YELLOW}[6/10] Consolidando backups nginx...${NC}"
    
    mkdir -p /home/luis/backups/nginx
    
    # Mover backups de sites-available
    sudo mv /etc/nginx/sites-available/*.backup-* /home/luis/backups/nginx/ 2>/dev/null || true
    
    # Mover backups de sites-enabled
    sudo mv /etc/nginx/sites-enabled/*.bak /home/luis/backups/nginx/ 2>/dev/null || true
    
    # Cambiar permisos
    sudo chown -R luis:luis /home/luis/backups/nginx/
    
    echo -e "${GREEN}Backups nginx consolidados${NC}"
}

create_port_registry() {
    echo -e "${YELLOW}[7/10] Creando registro de puertos...${NC}"
    
    mkdir -p /home/luis/config
    
    cat > /home/luis/config/port-registry.json << 'EOFJSON'
{
  "metadata": {
    "version": "1.0",
    "last_updated": "2025-11-17",
    "total_ports": 57
  },
  "port_ranges": {
    "web_apps_landings": "3000-3099",
    "web_apps_tools": "3100-3199",
    "web_apps_internal": "3200-3299",
    "backend_api_main": "5000-5099",
    "backend_api_micro": "5100-5199",
    "postgresql": "5400-5499",
    "mysql": "5500-5599",
    "redis_cache": "6000-6099",
    "message_queues": "6100-6199",
    "services": "8000-8099",
    "monitoring": "8100-8199",
    "devops": "9000-9099",
    "monitoring_tools": "9100-9199"
  },
  "reserved_ports": {
    "ssh": 22,
    "http": 80,
    "https": 443,
    "smtp": 25,
    "pop3": 110,
    "imap": 143,
    "smtps": 465,
    "submission": 587,
    "imaps": 993,
    "pop3s": 995,
    "sieve": 4190
  },
  "active_ports": [
    {"port": 3000, "project": "guanacolabs-landing", "service": "frontend", "status": "active"},
    {"port": 3001, "project": "guanacolabs-projects-hub", "service": "frontend", "status": "active"},
    {"port": 3002, "project": "crypto-app", "service": "frontend", "status": "active"},
    {"port": 3010, "project": "ai-gmail-organizer", "service": "frontend", "status": "active"},
    {"port": 3011, "project": "ai-dev-team", "service": "frontend", "status": "active"},
    {"port": 5000, "project": "guanacolabs-app", "service": "backend", "status": "active"},
    {"port": 8880, "project": "vaultwarden", "service": "web", "status": "active"},
    {"port": 8888, "project": "nextcloud", "service": "web", "status": "active"},
    {"port": 9000, "project": "artisview", "service": "frontend", "status": "active"},
    {"port": 9090, "project": "artisview", "service": "backend", "status": "active"}
  ]
}
EOFJSON
    
    echo -e "${GREEN}Port registry creado: /home/luis/config/port-registry.json${NC}"
}

create_project_structure() {
    echo -e "${YELLOW}[8/10] Creando estructura de directorios...${NC}"
    
    mkdir -p /home/luis/projects/active/{ai,mcp,web,finance,devops,tools,company,agriculture,medical,docs}
    mkdir -p /home/luis/projects/{archived,experiments}
    mkdir -p /home/luis/mi-wiki/{deployment,infrastructure,cloudflare,bitwarden,github,guides,reports}
    mkdir -p /home/luis/scripts/{deployment,cloudflare,bitwarden,monitoring,utils}
    mkdir -p /home/luis/docs/{active,archive}
    mkdir -p /home/luis/config
    mkdir -p /home/luis/backups/{nginx,databases,repos}
    mkdir -p /home/luis/deployments/{web-apps,services,infrastructure}
    
    echo -e "${GREEN}Estructura de directorios creada${NC}"
}

generate_summary_report() {
    echo -e "${YELLOW}[9/10] Generando reporte resumen...${NC}"
    
    cat > /home/luis/CLEANUP-SUMMARY-$(date +%Y%m%d).md << EOFREPORT
# RESUMEN DE LIMPIEZA - SERVIDOR GUANACOLABS
Fecha: $(date)

## Acciones Completadas

- [x] Backup de repos con cambios (26 repos)
- [x] Organizacion de archivos .md en mi-wiki/
- [x] Archivado de reportes viejos
- [x] Organizacion de scripts en /home/luis/scripts/
- [x] Limpieza de archivos basura
- [x] Consolidacion de backups nginx
- [x] Creacion de port registry
- [x] Creacion de estructura de directorios

## Pendientes

- [ ] Commit y push cambios importantes (26 repos)
- [ ] Push commits pendientes (2 repos)
- [ ] Eliminar repos duplicados (11 duplicaciones)
- [ ] Clonar repos faltantes (46 repos)
- [ ] Cleanup Cloudflare (~800 subdominios)
- [ ] Deploy repos prioritarios

## Archivos Movidos

### Mi Wiki
- Deployment: $(ls /home/luis/mi-wiki/deployment/ 2>/dev/null | wc -l) archivos
- Infrastructure: $(ls /home/luis/mi-wiki/infrastructure/ 2>/dev/null | wc -l) archivos
- Cloudflare: $(ls /home/luis/mi-wiki/cloudflare/ 2>/dev/null | wc -l) archivos
- Bitwarden: $(ls /home/luis/mi-wiki/bitwarden/ 2>/dev/null | wc -l) archivos
- GitHub: $(ls /home/luis/mi-wiki/github/ 2>/dev/null | wc -l) archivos
- Guides: $(ls /home/luis/mi-wiki/guides/ 2>/dev/null | wc -l) archivos

### Scripts
- Deployment: $(ls /home/luis/scripts/deployment/ 2>/dev/null | wc -l) scripts
- Cloudflare: $(ls /home/luis/scripts/cloudflare/ 2>/dev/null | wc -l) scripts
- Bitwarden: $(ls /home/luis/scripts/bitwarden/ 2>/dev/null | wc -l) scripts
- Utils: $(ls /home/luis/scripts/utils/ 2>/dev/null | wc -l) scripts

## Proximos Pasos

1. Revisar repos con cambios y hacer commits necesarios
2. Eliminar duplicados manualmente (requiere revision)
3. Clonar repos faltantes segun prioridad
4. Implementar script de asignacion automatica de puertos
5. Ejecutar cleanup de Cloudflare

---
*Generado automaticamente*
EOFREPORT
    
    echo -e "${GREEN}Reporte generado: /home/luis/CLEANUP-SUMMARY-$(date +%Y%m%d).md${NC}"
}

show_next_steps() {
    echo -e "${YELLOW}[10/10] Proximos pasos...${NC}"
    
    cat << EOFSTEPS

================================
PROXIMOS PASOS MANUALES
================================

1. REVISAR REPOS CON CAMBIOS (26 repos):
   cd /home/luis/backups/repos-backup-$(date +%Y%m%d)
   # Revisar cada repo y decidir que commitear

2. PUSH COMMITS PENDIENTES (2 repos):
   cd /home/luis/projects/active/finance/crypto-arbitrage-bot && git push
   cd /home/luis/projects/active/web/web-fireman-developer && git push

3. ELIMINAR REPOS DUPLICADOS:
   # Revisar lista en SERVIDOR-GUANACOLABS-ANALISIS-COMPLETO-$(date +%Y%m%d).md
   # Eliminar manualmente despues de verificar

4. CLONAR REPOS FALTANTES (46 repos):
   # Ver lista completa en analisis
   # Clonar segun prioridad en /home/luis/projects/active/

5. IMPLEMENTAR SISTEMA DE PUERTOS:
   # Usar /home/luis/config/port-registry.json como base
   # Crear script de validacion

================================

EOFSTEPS
}

# Menu principal
show_menu() {
    echo ""
    echo "Selecciona una opcion:"
    echo "1. Ejecutar limpieza COMPLETA (todas las acciones)"
    echo "2. Solo backup de repos con cambios"
    echo "3. Solo organizar archivos .md"
    echo "4. Solo organizar scripts"
    echo "5. Solo limpiar archivos basura"
    echo "6. Solo consolidar backups nginx"
    echo "7. Mostrar proximos pasos"
    echo "0. Salir"
    echo ""
    read -p "Opcion: " option
    
    case $option in
        1)
            backup_repos_with_changes
            organize_markdown_files
            archive_old_reports
            organize_scripts
            clean_junk_files
            consolidate_nginx_backups
            create_port_registry
            create_project_structure
            generate_summary_report
            show_next_steps
            ;;
        2) backup_repos_with_changes ;;
        3) organize_markdown_files ;;
        4) organize_scripts ;;
        5) clean_junk_files ;;
        6) consolidate_nginx_backups ;;
        7) show_next_steps ;;
        0) echo "Saliendo..."; exit 0 ;;
        *) echo "Opcion invalida"; show_menu ;;
    esac
}

# Ejecutar menu
show_menu
