#!/bin/bash
# One-liner version - assumes BW_SESSION is already set in your environment
# Usage: source this file or run with an active BW_SESSION

if [ -z "$BW_SESSION" ]; then
    echo "ERROR: BW_SESSION not set. Please unlock your vault first:"
    echo "  export BW_SESSION=\$(bw unlock --raw)"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "Using existing Bitwarden session..."
echo ""

# PostgreSQL
echo "1/3 Processing PostgreSQL..."
pg_exists=$(bw list items --search "PostgreSQL Standalone Server (localhost:5432)" --session "$BW_SESSION" | jq -r '.[0].id // "null"')
if [ "$pg_exists" != "null" ]; then
    bw get item "$pg_exists" --session "$BW_SESSION" | jq \
        '.name = "PostgreSQL Standalone Server (localhost:5432)" |
         .login.username = "postgres" |
         .login.password = "ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=" |
         .login.uris = [{"match": null, "uri": "postgresql://postgres:ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=@localhost:5432"}] |
         .notes = "Standalone PostgreSQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost. Contains databases: platform_deployer, crypto_trading, autoscribe, deployer, guanaco_projects, etc." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "5432", "type": 0}, {"name": "Connection String", "value": "postgresql://postgres:ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=@localhost:5432", "type": 0}]' | \
    bw encode | bw edit item "$pg_exists" --session "$BW_SESSION" > /dev/null && echo "  ✓ UPDATED (ID: $pg_exists)"
else
    bw get template item --session "$BW_SESSION" | jq \
        '.type = 1 |
         .name = "PostgreSQL Standalone Server (localhost:5432)" |
         .login = {"username": "postgres", "password": "ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=", "uris": [{"match": null, "uri": "postgresql://postgres:ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=@localhost:5432"}]} |
         .notes = "Standalone PostgreSQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost. Contains databases: platform_deployer, crypto_trading, autoscribe, deployer, guanaco_projects, etc." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "5432", "type": 0}, {"name": "Connection String", "value": "postgresql://postgres:ffYnfncokzH3btTMn2S+iVo03gDEjlGzeAbvQ7k3eWw=@localhost:5432", "type": 0}] |
         .organizationId = null' | \
    bw encode | bw create item --session "$BW_SESSION" | jq -r '"  ✓ CREATED (ID: " + .id + ")"'
fi

# Redis
echo "2/3 Processing Redis..."
redis_exists=$(bw list items --search "Redis Standalone Server (localhost:6379)" --session "$BW_SESSION" | jq -r '.[0].id // "null"')
if [ "$redis_exists" != "null" ]; then
    bw get item "$redis_exists" --session "$BW_SESSION" | jq \
        '.name = "Redis Standalone Server (localhost:6379)" |
         .login.username = "" |
         .login.password = "7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=" |
         .login.uris = [{"match": null, "uri": "redis://:7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=@localhost:6379/0"}] |
         .notes = "Standalone Redis server on Contabo VPS. Updated 2025-11-15 after malware incident. Password authentication enabled. Only accessible from localhost." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "6379", "type": 0}, {"name": "Connection String", "value": "redis://:7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=@localhost:6379/0", "type": 0}]' | \
    bw encode | bw edit item "$redis_exists" --session "$BW_SESSION" > /dev/null && echo "  ✓ UPDATED (ID: $redis_exists)"
else
    bw get template item --session "$BW_SESSION" | jq \
        '.type = 1 |
         .name = "Redis Standalone Server (localhost:6379)" |
         .login = {"username": "", "password": "7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=", "uris": [{"match": null, "uri": "redis://:7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=@localhost:6379/0"}]} |
         .notes = "Standalone Redis server on Contabo VPS. Updated 2025-11-15 after malware incident. Password authentication enabled. Only accessible from localhost." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "6379", "type": 0}, {"name": "Connection String", "value": "redis://:7icV2GbpOo0B8X5J2RcJCYt8pvyHQxuAaZV6UTrxsGs=@localhost:6379/0", "type": 0}] |
         .organizationId = null' | \
    bw encode | bw create item --session "$BW_SESSION" | jq -r '"  ✓ CREATED (ID: " + .id + ")"'
fi

# MySQL
echo "3/3 Processing MySQL..."
mysql_exists=$(bw list items --search "MySQL Standalone Server (localhost:3306)" --session "$BW_SESSION" | jq -r '.[0].id // "null"')
if [ "$mysql_exists" != "null" ]; then
    bw get item "$mysql_exists" --session "$BW_SESSION" | jq \
        '.name = "MySQL Standalone Server (localhost:3306)" |
         .login.username = "root" |
         .login.password = "IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=" |
         .login.uris = [{"match": null, "uri": "mysql://root:IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=@localhost:3306"}] |
         .notes = "Standalone MySQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "3306", "type": 0}, {"name": "Connection String", "value": "mysql://root:IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=@localhost:3306", "type": 0}]' | \
    bw encode | bw edit item "$mysql_exists" --session "$BW_SESSION" > /dev/null && echo "  ✓ UPDATED (ID: $mysql_exists)"
else
    bw get template item --session "$BW_SESSION" | jq \
        '.type = 1 |
         .name = "MySQL Standalone Server (localhost:3306)" |
         .login = {"username": "root", "password": "IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=", "uris": [{"match": null, "uri": "mysql://root:IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=@localhost:3306"}]} |
         .notes = "Standalone MySQL server on Contabo VPS. Updated 2025-11-15 after malware incident. Only accessible from localhost." |
         .fields = [{"name": "Host", "value": "localhost", "type": 0}, {"name": "Port", "value": "3306", "type": 0}, {"name": "Connection String", "value": "mysql://root:IqH63lzi9Ia1DZVXHce2Gn2slrTn2oFK/QRNN9X4FIY=@localhost:3306", "type": 0}] |
         .organizationId = null' | \
    bw encode | bw create item --session "$BW_SESSION" | jq -r '"  ✓ CREATED (ID: " + .id + ")"'
fi

echo ""
echo "Syncing vault..."
bw sync --session "$BW_SESSION" > /dev/null && echo "✓ Sync complete"

echo ""
echo "All done! Don't forget to lock your vault when finished:"
echo "  bw lock"
