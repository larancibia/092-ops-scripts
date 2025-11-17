#!/bin/bash
# Setup shared database infrastructure
# Creates shared PostgreSQL and Redis instances to optimize resources
# Instead of 84 separate databases, we use 3 PostgreSQL + 2 Redis instances

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DATA="$SCRIPT_DIR/deployment-categorization.json"

echo "======================================"
echo "SHARED DATABASE INFRASTRUCTURE SETUP"
echo "======================================"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

# Show shared database plan
echo "Database Sharing Strategy:"
echo ""
jq -r '.shared_databases | to_entries[] | "  \(.key): \(.value.projects | length) projects on port \(.value.port)"' "$DEPLOY_DATA"
echo ""

read -p "Proceed with setup? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Setup cancelled"
    exit 0
fi

# Create shared docker-compose for databases
SHARED_DB_DIR="/home/luis/shared-databases"
mkdir -p "$SHARED_DB_DIR"

cat > "$SHARED_DB_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  # PostgreSQL - Main (General Projects)
  postgres-main:
    image: postgres:15-alpine
    container_name: postgres-main
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_MAIN:-changeme123}
      POSTGRES_USER: guanaco
      POSTGRES_DB: guanaco_main
    volumes:
      - postgres-main-data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - guanaco-network

  # PostgreSQL - AI Projects
  postgres-ai:
    image: postgres:15-alpine
    container_name: postgres-ai
    restart: unless-stopped
    ports:
      - "5433:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_AI:-changeme123}
      POSTGRES_USER: guanaco
      POSTGRES_DB: guanaco_ai
    volumes:
      - postgres-ai-data:/var/lib/postgresql/data
    networks:
      - guanaco-network

  # PostgreSQL - Finance & Trading
  postgres-finance:
    image: postgres:15-alpine
    container_name: postgres-finance
    restart: unless-stopped
    ports:
      - "5434:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_FINANCE:-changeme123}
      POSTGRES_USER: guanaco
      POSTGRES_DB: guanaco_finance
    volumes:
      - postgres-finance-data:/var/lib/postgresql/data
    networks:
      - guanaco-network

  # Redis - Main
  redis-main:
    image: redis:7-alpine
    container_name: redis-main
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD_MAIN:-changeme123}
    volumes:
      - redis-main-data:/data
    networks:
      - guanaco-network

  # Redis - AI Projects
  redis-ai:
    image: redis:7-alpine
    container_name: redis-ai
    restart: unless-stopped
    ports:
      - "6380:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD_AI:-changeme123}
    volumes:
      - redis-ai-data:/data
    networks:
      - guanaco-network

volumes:
  postgres-main-data:
  postgres-ai-data:
  postgres-finance-data:
  redis-main-data:
  redis-ai-data:

networks:
  guanaco-network:
    driver: bridge
EOF

# Create init script for PostgreSQL to create separate databases for each project
mkdir -p "$SHARED_DB_DIR/init-scripts"

echo "Creating database initialization scripts..."

# Generate init script for each database
cat > "$SHARED_DB_DIR/init-scripts/01-create-databases.sql" <<'EOF'
-- Create separate databases for each project within shared PostgreSQL instances
-- This allows logical separation while sharing infrastructure

-- Main PostgreSQL databases
EOF

# Add databases for each project using postgres-main
jq -r '.shared_databases["postgres_main"].projects[]' "$DEPLOY_DATA" | while read project; do
    db_name=$(echo "$project" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
    echo "CREATE DATABASE ${db_name}_db;" >> "$SHARED_DB_DIR/init-scripts/01-create-databases.sql"
    echo "GRANT ALL PRIVILEGES ON DATABASE ${db_name}_db TO guanaco;" >> "$SHARED_DB_DIR/init-scripts/01-create-databases.sql"
done

# Create environment file
cat > "$SHARED_DB_DIR/.env" <<EOF
# Shared Database Credentials
# IMPORTANT: Change these passwords in production!

POSTGRES_PASSWORD_MAIN=guanaco_main_$(openssl rand -hex 8)
POSTGRES_PASSWORD_AI=guanaco_ai_$(openssl rand -hex 8)
POSTGRES_PASSWORD_FINANCE=guanaco_finance_$(openssl rand -hex 8)

REDIS_PASSWORD_MAIN=redis_main_$(openssl rand -hex 8)
REDIS_PASSWORD_AI=redis_ai_$(openssl rand -hex 8)
EOF

echo ""
echo "Starting shared database infrastructure..."
cd "$SHARED_DB_DIR"
docker-compose up -d

echo ""
echo "Waiting for databases to be ready..."
sleep 10

# Verify databases are running
echo ""
echo "Verifying database health..."
for container in postgres-main postgres-ai postgres-finance redis-main redis-ai; do
    if docker ps | grep -q "$container"; then
        echo "  $container: RUNNING"
    else
        echo "  $container: NOT RUNNING"
    fi
done

echo ""
echo "======================================"
echo "Database Infrastructure Setup Complete"
echo "======================================"
echo ""

echo "Connection Information:"
echo ""
echo "PostgreSQL - Main (General Projects):"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  User: guanaco"
echo "  Database: guanaco_main (or project-specific DB)"
echo "  Password: See $SHARED_DB_DIR/.env"
echo ""
echo "PostgreSQL - AI Projects:"
echo "  Host: localhost"
echo "  Port: 5433"
echo "  User: guanaco"
echo "  Database: guanaco_ai (or project-specific DB)"
echo ""
echo "PostgreSQL - Finance Projects:"
echo "  Host: localhost"
echo "  Port: 5434"
echo "  User: guanaco"
echo "  Database: guanaco_finance (or project-specific DB)"
echo ""
echo "Redis - Main:"
echo "  Host: localhost"
echo "  Port: 6379"
echo "  Password: See $SHARED_DB_DIR/.env"
echo ""
echo "Redis - AI:"
echo "  Host: localhost"
echo "  Port: 6380"
echo "  Password: See $SHARED_DB_DIR/.env"
echo ""

# Create connection strings file for reference
cat > "$SHARED_DB_DIR/CONNECTION_STRINGS.md" <<EOF
# Shared Database Connection Strings

## PostgreSQL

### Main (General Projects)
\`\`\`
postgresql://guanaco:[PASSWORD]@localhost:5432/guanaco_main
\`\`\`

Projects using this DB:
$(jq -r '.shared_databases["postgres_main"].projects[] | "- " + .' "$DEPLOY_DATA")

### AI Projects
\`\`\`
postgresql://guanaco:[PASSWORD]@localhost:5433/guanaco_ai
\`\`\`

Projects using this DB:
$(jq -r '.shared_databases["postgres_ai"].projects[] | "- " + .' "$DEPLOY_DATA")

### Finance Projects
\`\`\`
postgresql://guanaco:[PASSWORD]@localhost:5434/guanaco_finance
\`\`\`

Projects using this DB:
$(jq -r '.shared_databases["postgres_finance"].projects[] | "- " + .' "$DEPLOY_DATA")

## Redis

### Main
\`\`\`
redis://:[PASSWORD]@localhost:6379/0
\`\`\`

Projects using this:
$(jq -r '.shared_databases["redis_main"].projects[] | "- " + .' "$DEPLOY_DATA")

### AI
\`\`\`
redis://:[PASSWORD]@localhost:6380/0
\`\`\`

Projects using this:
$(jq -r '.shared_databases["redis_ai"].projects[] | "- " + .' "$DEPLOY_DATA")

---

**Note:** Passwords are stored in \`.env\` file. Keep this file secure!
EOF

echo "Connection strings documentation: $SHARED_DB_DIR/CONNECTION_STRINGS.md"
echo ""
echo "Resource Savings:"
echo "  Instead of: 84 PostgreSQL + 84 Redis = 168 containers"
echo "  We use: 3 PostgreSQL + 2 Redis = 5 containers"
echo "  Estimated RAM saved: ~10 GB"
echo ""
echo "======================================"
