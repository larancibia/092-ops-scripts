#!/bin/bash

# Script para limpiar configuraciones Nginx de subdominios eliminados

set -e

echo "=== LIMPIEZA DE CONFIGURACIONES NGINX ==="
echo ""

# Subdominios que fueron eliminados de Cloudflare
DELETED_SUBDOMAINS=(
    "agro"
    "aider-improved"
    "api-keys-dashboard"
    "climemory"
    "crypto-pump-crash-system"
    "crypto-research-agents"
    "crypto"
    "edu-senales"
    "edu-trading"
    "mcp-annas-archive"
    "mcp-bitwarden-enhanced"
    "mcp-claude-global-config"
    "memory"
    "money"
    "artisview"
)

# Crear directorio de backup
BACKUP_DIR="/home/luis/nginx-configs-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creando backup en: $BACKUP_DIR"
echo ""

disabled=0
backed_up=0

for subdomain in "${DELETED_SUBDOMAINS[@]}"; do
    # Buscar archivos de configuración que coincidan
    for config_file in /etc/nginx/sites-enabled/*${subdomain}* /etc/nginx/sites-enabled/${subdomain}.conf; do
        if [ -e "$config_file" ]; then
            filename=$(basename "$config_file")

            echo "📁 Encontrado: $filename"

            # Hacer backup del archivo original
            if [ -L "$config_file" ]; then
                # Es un symlink, copiar el archivo original
                original_file=$(readlink -f "$config_file")
                if [ -f "$original_file" ]; then
                    sudo cp "$original_file" "$BACKUP_DIR/"
                    echo "   ✅ Backup creado"
                    ((backed_up++))
                fi
            fi

            # Deshabilitar (eliminar symlink)
            sudo rm "$config_file"
            echo "   ✅ Deshabilitado"
            ((disabled++))
            echo ""
        fi
    done
done

# Verificar configuración de Nginx
echo "Verificando configuración de Nginx..."
if sudo nginx -t; then
    echo "✅ Configuración Nginx válida"

    # Recargar Nginx
    echo ""
    echo "Recargando Nginx..."
    sudo systemctl reload nginx
    echo "✅ Nginx recargado"
else
    echo "❌ Error en configuración Nginx"
    echo "Los archivos de backup están en: $BACKUP_DIR"
    exit 1
fi

echo ""
echo "=== RESUMEN ==="
echo "Configuraciones deshabilitadas: $disabled"
echo "Backups creados: $backed_up"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Listar configuraciones restantes
echo "=== CONFIGURACIONES NGINX ACTIVAS ==="
ls /etc/nginx/sites-enabled/ | sort

exit 0
