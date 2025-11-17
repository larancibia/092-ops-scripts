#!/bin/bash
# Script para ejecutar el web agent en tu máquina local con RTX 3090
# Autor: Claude Code
# Fecha: 2025-11-16

echo "🚀 TurboScribe Web Agent con DeepSeek R1"
echo "========================================"
echo ""

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "❌ Ollama no está corriendo"
    echo "💡 Ejecutá en otra terminal: ollama serve"
    exit 1
fi

echo "✅ Ollama está corriendo"
echo ""

# Pull models if needed
echo "📦 Verificando modelos..."
ollama list | grep -q "deepseek-r1:8b" || {
    echo "⬇️  Descargando DeepSeek R1 8B (~8GB)..."
    ollama pull deepseek-r1:8b
}

ollama list | grep -q "llava:7b" || {
    echo "⬇️  Descargando LLaVA 7B (~4.5GB)..."
    ollama pull llava:7b
}

echo ""
echo "✅ Modelos listos"
echo ""

# Run the agent
echo "🎯 Ejecutando agente para extraer cookies de TurboScribe..."
echo ""

python3 /home/luis/ollama-web-agent-reasoning.py \
    --task "Login to turboscribe.ai with Google OAuth and wait for the dashboard to load" \
    --url "https://turboscribe.ai" \
    --reasoning-model "deepseek-r1:8b" \
    --vision-model "llava:7b" \
    --max-steps 20 \
    --save-cookies "/home/luis/turboscribe-mcp/cookies.json"

echo ""
echo "✅ Proceso completado"
echo ""
echo "📁 Cookies guardadas en: /home/luis/turboscribe-mcp/cookies.json"
echo ""
echo "💡 Podés revisar las cookies con:"
echo "   cat /home/luis/turboscribe-mcp/cookies.json | jq ."
