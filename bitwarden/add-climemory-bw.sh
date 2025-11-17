#!/bin/bash
# Script para agregar CLI Memory a Bitwarden de forma segura
set -e

echo "🔐 Agregando CLI Memory Admin Panel a Bitwarden"
echo ""

# Unlock vault (pedirá contraseña de forma segura)
echo "🔓 Desbloqueando vault..."
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION

if [ -z "$BW_SESSION" ]; then
    echo "❌ Error al desbloquear vault"
    exit 1
fi

echo "✅ Vault desbloqueado"
echo ""

# Sync first
echo "🔄 Sincronizando vault..."
bw sync --session "$BW_SESSION" > /dev/null 2>&1 || true
echo "✅ Sincronizado"
echo ""

# Check if folder exists
echo "📁 Verificando carpeta 'GuanacoLabs - Projects'..."
FOLDER_JSON=$(bw list folders --session "$BW_SESSION")
FOLDER_ID=$(echo "$FOLDER_JSON" | jq -r '.[] | select(.name == "GuanacoLabs - Projects") | .id')

if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" == "null" ]; then
    echo "📁 Creando carpeta 'GuanacoLabs - Projects'..."
    FOLDER_RESULT=$(bw get template folder | jq '.name = "GuanacoLabs - Projects"' | bw encode | bw create folder --session "$BW_SESSION")
    FOLDER_ID=$(echo "$FOLDER_RESULT" | jq -r '.id')
    echo "✅ Carpeta creada: $FOLDER_ID"
else
    echo "✅ Carpeta existe: $FOLDER_ID"
fi

echo ""

# Check if item already exists
echo "🔍 Verificando si la entrada ya existe..."
EXISTING_ITEM=$(bw list items --search "CLI Memory - Admin Panel" --session "$BW_SESSION" | jq -r '.[0].id // empty')

if [ -n "$EXISTING_ITEM" ]; then
    echo "⚠️  La entrada 'CLI Memory - Admin Panel' ya existe (ID: $EXISTING_ITEM)"
    echo "¿Querés actualizar la existente o crear una nueva?"
    echo "Por ahora, no voy a crear duplicada. Podés eliminar la existente primero si querés."
    exit 0
fi

echo "🔐 Creando entrada 'CLI Memory - Admin Panel'..."

# Create the item
ITEM_JSON=$(bw get template item | jq \
  --arg folder_id "$FOLDER_ID" \
  '{
    folderId: $folder_id,
    type: 1,
    name: "CLI Memory - Admin Panel",
    notes: "Panel de administración para CLI Memory landing page.\nContiene toda la documentación del proyecto.\n\nAcceso:\n- START_HERE.md - Guía rápida\n- DEPLOY_NOW.md - Deployment\n- AIRTABLE_SETUP.md - Waitlist setup\n- LAUNCH_CHECKLIST.md - Launch plan\n- Marketing Campaign - 7 días de contenido\n- OG_IMAGE_GUIDE.md - Social images\n- README.md - Documentación completa\n\nProyecto: CLI Memory\nGitHub: github.com/larancibia/ai-cli-memory\nLanding: https://climemory.guanacolabs.com\nAdmin: https://climemory.guanacolabs.com/admin.html",
    login: {
      username: "admin@climemory",
      password: "CLImem2024$Secure!",
      uris: [
        {
          match: 3,
          uri: "https://climemory.guanacolabs.com/admin.html"
        }
      ]
    }
  }')

ITEM_RESULT=$(echo "$ITEM_JSON" | bw encode | bw create item --session "$BW_SESSION")
ITEM_ID=$(echo "$ITEM_RESULT" | jq -r '.id')

echo "✅ Entrada creada exitosamente! ID: $ITEM_ID"
echo ""

# Sync
echo "🔄 Sincronizando con servidor..."
bw sync --session "$BW_SESSION" > /dev/null 2>&1

echo ""
echo "✅ ¡Listo! Credenciales guardadas en Bitwarden"
echo ""
echo "📝 Detalles:"
echo "   Nombre: CLI Memory - Admin Panel"
echo "   Usuario: admin@climemory"
echo "   Password: CLImem2024$Secure!"
echo "   URL: https://climemory.guanacolabs.com/admin.html"
echo "   Carpeta: GuanacoLabs - Projects"
echo "   Match Detection: Host (tipo 3)"
echo ""
echo "🌐 Ahora podés acceder a: https://climemory.guanacolabs.com/admin.html"
echo "   Bitwarden debería auto-sugerir las credenciales en el browser"
echo ""

# Update MCP config with new session
echo "🔧 ¿Querés actualizar el MCP config con esta sesión? (y/n)"
read -r UPDATE_MCP

if [ "$UPDATE_MCP" == "y" ] || [ "$UPDATE_MCP" == "Y" ]; then
    MCP_CONFIG="/home/luis/projects/experiments/claude-mcp-global-config/mcp.json"

    # Backup first
    cp "$MCP_CONFIG" "$MCP_CONFIG.backup.$(date +%s)"

    # Update session in config
    jq --arg session "$BW_SESSION" \
       '.mcpServers."guanaco-bitwarden-enhanced".env.BW_SESSION = $session' \
       "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"

    echo "✅ MCP config actualizado!"
    echo "   Reiniciá Claude Desktop para que tome la nueva sesión"
fi

echo ""
echo "🎉 ¡Todo listo!"
