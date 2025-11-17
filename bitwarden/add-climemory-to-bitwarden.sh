#!/bin/bash
# Script para agregar CLI Memory credentials a Bitwarden
# Uso: ./add-climemory-to-bitwarden.sh

set -e

echo "🔐 Agregando CLI Memory Admin Panel a Bitwarden"
echo ""

# Check if logged in
if ! bw status | grep -q "unlocked\|locked"; then
    echo "📝 Necesitas loguearte primero:"
    echo "   bw login arancibialuisalejandro@gmail.com"
    bw login arancibialuisalejandro@gmail.com
fi

# Unlock if locked
if bw status | grep -q "locked"; then
    echo "🔓 Desbloqueando vault..."
    export BW_SESSION="$(bw unlock --raw)"
else
    echo "🔓 Desbloqueando vault..."
    export BW_SESSION="$(bw unlock --raw)"
fi

echo ""
echo "✅ Vault desbloqueado"
echo ""

# Check if folder exists, if not create it
echo "📁 Verificando carpeta 'GuanacoLabs - Projects'..."
FOLDER_ID=$(bw list folders --session "$BW_SESSION" | grep -o '"name":"GuanacoLabs - Projects"' -B2 | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$FOLDER_ID" ]; then
    echo "📁 Creando carpeta 'GuanacoLabs - Projects'..."
    FOLDER_ID=$(bw get template folder | jq '.name = "GuanacoLabs - Projects"' | bw encode | bw create folder --session "$BW_SESSION" | jq -r '.id')
    echo "✅ Carpeta creada: $FOLDER_ID"
else
    echo "✅ Carpeta existe: $FOLDER_ID"
fi

echo ""
echo "🔐 Creando entrada 'CLI Memory - Admin Panel'..."

# Create the item
bw get template item | jq \
  --arg folder_id "$FOLDER_ID" \
  '.folderId = $folder_id |
   .type = 1 |
   .name = "CLI Memory - Admin Panel" |
   .notes = "Panel de administración para CLI Memory landing page.\nContiene toda la documentación del proyecto.\n\nAcceso:\n- START_HERE.md - Guía rápida\n- DEPLOY_NOW.md - Deployment\n- AIRTABLE_SETUP.md - Waitlist setup\n- LAUNCH_CHECKLIST.md - Launch plan\n- Marketing Campaign - 7 días de contenido\n- OG_IMAGE_GUIDE.md - Social images\n- README.md - Documentación completa\n\nProyecto: CLI Memory\nGitHub: github.com/larancibia/ai-cli-memory\nLanding: https://climemory.guanacolabs.com\nAdmin: https://climemory.guanacolabs.com/admin.html" |
   .login = {
     "username": "admin@climemory",
     "password": "CLImem2024$Secure!",
     "uris": [
       {
         "match": 3,
         "uri": "https://climemory.guanacolabs.com/admin.html"
       }
     ]
   }' | \
  bw encode | \
  bw create item --session "$BW_SESSION"

echo ""
echo "✅ Entrada creada exitosamente!"
echo ""
echo "🔄 Sincronizando con servidor..."
bw sync --session "$BW_SESSION"

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
echo "🌐 Probá acceder a: https://climemory.guanacolabs.com/admin.html"
echo "   Bitwarden debería auto-sugerir las credenciales"
