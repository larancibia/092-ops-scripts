#!/bin/bash
set -e

# Project Context
# Assuming structure: /path/to/ProjectName/backend
COMPONENT_NAME=$(basename "$PWD") # e.g., 'web', 'backend', 'landing'
PROJECT_DIR=$(dirname "$PWD")
APP_NAME=$(basename "$PROJECT_DIR") # e.g., 'GuanacoBot'
FULL_SERVICE_NAME="${APP_NAME}-${COMPONENT_NAME}"

# Path to Port Allocator
ALLOCATOR="/home/luis/projects/ops-scripts/port-management/allocate-port.sh"

# Determine Port Type
PORT_TYPE="service"
if [[ "$COMPONENT_NAME" == "web" || "$COMPONENT_NAME" == "landing" ]]; then
    PORT_TYPE="frontend"
elif [[ "$COMPONENT_NAME" == "backend" ]]; then
    PORT_TYPE="backend"
fi

# Allocate/Retrieve Port
echo "[INFO] Requesting port for $FULL_SERVICE_NAME ($PORT_TYPE)..."
if [ -x "$ALLOCATOR" ]; then
    PORT=$($ALLOCATOR "$FULL_SERVICE_NAME" "$PORT_TYPE")
    # Sanitize PORT (remove whitespace/newlines)
    PORT=$(echo "$PORT" | tr -d '[:space:]')
    echo "[SUCCESS] Allocated Port: $PORT"
else
    echo "[ERROR] Port allocator not found at $ALLOCATOR"
    exit 1
fi

# Export for the application
export PORT

# Update/Create .env for Docker/App
if [ -f ".env" ]; then
    # Update existing PORT if present, or append
    if grep -q "^PORT=" .env; then
        # Use a temporary file to avoid race conditions/errors
        sed "s/^PORT=.*/PORT=$PORT/" .env > .env.tmp && mv .env.tmp .env
    else
        echo "PORT=$PORT" >> .env
    fi
else
    echo "PORT=$PORT" > .env
fi

echo "[INFO] Starting application on port $PORT..."

# --- TECHNOLOGY DETECTION & STARTUP ---

# 1. NODE.JS / JAVASCRIPT
if [ -f "package.json" ]; then
    echo "[INFO] Detected Node.js project."
    
    if [ -f "yarn.lock" ]; then
        echo "[INFO] Installing dependencies with Yarn..."
        yarn install
        echo "[INFO] Starting with Yarn..."
        yarn start
    else
        echo "[INFO] Installing dependencies with NPM..."
        npm install
        echo "[INFO] Starting with NPM..."
        npm start
    fi

# 2. PYTHON
elif [ -f "requirements.txt" ] || [ -f "main.py" ] || [ -f "app.py" ] || [ -f "manage.py" ]; then
    echo "[INFO] Detected Python project."

    # Check/Create Virtual Environment
    if [ ! -d "venv" ]; then
        echo "[INFO] Creating virtual environment (venv)..."
        python3 -m venv venv
    fi

    # Activate Virtual Environment
    # We use dot source to activate in the current shell script context
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    else
        echo "[ERROR] venv creation failed or activate script missing."
        exit 1
    fi

    # Install Dependencies
    if [ -f "requirements.txt" ]; then
        echo "[INFO] Installing dependencies from requirements.txt..."
        pip install -r requirements.txt
    fi

    # Determine Entry Point
    if [ -f "manage.py" ]; then
        echo "[INFO] Detected Django/Flask manage.py..."
        python manage.py runserver 0.0.0.0:$PORT
    elif [ -f "main.py" ]; then
        echo "[INFO] Running main.py..."
        python main.py
    elif [ -f "app.py" ]; then
        echo "[INFO] Running app.py..."
        python app.py
    else
        echo "[WARN] No standard entry point (app.py, main.py, manage.py) found. Attempting to run via module or waiting..."
        # Fallback: Try running a module if defined in env, else just keep env open (for testing)
    fi

# 3. DOCKER
elif [ -f "docker-compose.yml" ]; then
    echo "[INFO] Detected Docker Compose."
    docker-compose up -d --build

# 4. UNKNOWN
else
    echo "[WARN] No recognized technology (Node, Python, Docker). Looking for custom start script..."
    if [ -f "custom_start.sh" ]; then
        ./custom_start.sh
    else
        echo "[ERROR] No entry point found. Please create package.json, requirements.txt, or docker-compose.yml."
        exit 1
    fi
fi