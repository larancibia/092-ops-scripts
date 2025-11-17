#!/bin/bash
# Script para extraer cookies de TurboScribe usando el container de autoscribe

echo "🍪 TurboScribe Cookie Extractor (Docker Mode)"
echo "=============================================="
echo ""
echo "Este script usa el container de autoscribe que ya tiene Playwright."
echo ""
echo "IMPORTANTE: Necesitás tener acceso a un navegador para el login inicial."
echo ""
echo "Opciones:"
echo "1. Usar método manual (copiar cookies desde navegador)"
echo "2. Usar X11 forwarding (ssh -X)"
echo ""
read -p "¿Qué opción preferís? (1/2): " option

if [ "$option" == "1" ]; then
    echo ""
    echo "📋 Método Manual - Instrucciones:"
    echo "=================================="
    echo ""
    echo "1. Abrí https://turboscribe.ai en tu navegador"
    echo "2. Logueate con Google OAuth"
    echo "3. Abrí DevTools (F12) -> Console"
    echo "4. Pegá este código:"
    echo ""
    echo "----------------------------------------"
    cat << 'EOF'
JSON.stringify(document.cookie.split(';').map(c => {
    const [name, ...v] = c.trim().split('=');
    return {name, value: v.join('='), domain: '.turboscribe.ai',
            path: '/', secure: true, httpOnly: false, sameSite: 'Lax'};
}), null, 2)
EOF
    echo "----------------------------------------"
    echo ""
    echo "5. Copiá el resultado (JSON) y pegalo acá:"
    echo ""
    echo "Pegá el JSON de las cookies (Ctrl+D cuando termines):"

    # Leer input hasta EOF
    cookies_json=$(cat)

    # Guardar en el directorio montado
    echo "$cookies_json" | sudo tee /home/luis/turboscribe-mcp/cookies.json > /dev/null

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Cookies guardadas exitosamente en: /home/luis/turboscribe-mcp/cookies.json"
        echo ""
        echo "Preview:"
        cat /home/luis/turboscribe-mcp/cookies.json | head -20
    else
        echo "❌ Error al guardar cookies"
        exit 1
    fi

elif [ "$option" == "2" ]; then
    echo ""
    echo "🔧 Método X11 Forwarding"
    echo "========================"
    echo ""
    echo "Para usar este método:"
    echo "1. Desconectate del servidor"
    echo "2. Reconectate con: ssh -X usuario@servidor"
    echo "3. Volvé a ejecutar este script"
    echo ""
else
    echo "❌ Opción inválida"
    exit 1
fi
