#!/bin/bash

# Script para renombrar todos los repos en GitHub
# Lee del archivo commercial-names-mapping.json y procesa cada repo

MAPPING_FILE="/home/luis/commercial-names-mapping.json"
LOG_FILE="/home/luis/rename_repos_report.log"
SUCCESSFUL=0
FAILED=0
ALREADY_NAMED=0

# Inicializar archivo de log
> "$LOG_FILE"

echo "========================================" | tee -a "$LOG_FILE"
echo "REPORTE DE RENOMBRAMIENTOS DE REPOS" | tee -a "$LOG_FILE"
echo "Inicio: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Procesar cada repo del JSON
# Extraer los datos usando jq y procesar
cat "$MAPPING_FILE" | jq -r '.repositories[] | .repos[] | "\(.original)|\(.commercial)"' | while IFS='|' read -r original commercial; do

    echo -n "Procesando: $original -> $commercial ... "

    # Intentar renombrar el repo
    output=$(gh repo rename "$commercial" --repo "larancibia/$original" --yes 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "✓ ÉXITO" | tee -a "$LOG_FILE"
        echo "  - Original: $original" >> "$LOG_FILE"
        echo "  - Nuevo nombre: $commercial" >> "$LOG_FILE"
        echo "  - Status: Renombrado correctamente" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        ((SUCCESSFUL++))
    else
        # Verificar si ya tiene el nombre (error típico)
        if echo "$output" | grep -q "already named"; then
            echo "↻ YA RENOMBRADO" | tee -a "$LOG_FILE"
            echo "  - Original: $original" >> "$LOG_FILE"
            echo "  - Nombre actual: $commercial" >> "$LOG_FILE"
            echo "  - Status: Ya tiene este nombre" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
            ((ALREADY_NAMED++))
        else
            echo "✗ ERROR" | tee -a "$LOG_FILE"
            echo "  - Original: $original" >> "$LOG_FILE"
            echo "  - Objetivo: $commercial" >> "$LOG_FILE"
            echo "  - Error: $output" >> "$LOG_FILE"
            echo "" >> "$LOG_FILE"
            ((FAILED++))
        fi
    fi
done

# Resumen final
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "RESUMEN FINAL" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Renombrados exitosamente: $SUCCESSFUL repos" | tee -a "$LOG_FILE"
echo "Ya renombrados: $ALREADY_NAMED repos" | tee -a "$LOG_FILE"
echo "Con errores: $FAILED repos" | tee -a "$LOG_FILE"
echo "Total procesados: $((SUCCESSFUL + ALREADY_NAMED + FAILED))" | tee -a "$LOG_FILE"
echo "Fin: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

echo ""
echo "Reporte guardado en: $LOG_FILE"
