#!/bin/bash
# Setup Ollama Web Agent en tu máquina local

echo "🚀 Ollama Web Agent Setup"
echo "========================="
echo ""

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "📥 Instalando Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "✅ Ollama ya está instalado"
fi

# Start Ollama service
echo ""
echo "🔄 Iniciando Ollama..."
ollama serve &
sleep 3

# Pull vision model
echo ""
echo "📦 Descargando modelo Qwen2-VL 7B (puede tardar ~10 min)..."
echo "   Tamaño: ~4.5GB"
ollama pull qwen2-vl:7b

# Check GPU
echo ""
echo "🎮 Verificando GPU..."
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader

# Install Python dependencies
echo ""
echo "📚 Instalando dependencias Python..."
pip3 install --user playwright httpx

# Install Playwright browsers
echo ""
echo "🌐 Instalando navegadores Playwright..."
python3 -m playwright install chromium

echo ""
echo "✅ Setup completo!"
echo ""
echo "🎯 Prueba el agente:"
echo "   python3 ollama-web-agent.py --task 'Login to turboscribe.ai with Google'"
echo ""
echo "📚 Comandos útiles:"
echo "   ollama list                    # Ver modelos instalados"
echo "   ollama ps                      # Ver modelos en ejecución"
echo "   nvidia-smi                     # Monitorear GPU"
