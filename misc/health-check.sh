#!/bin/bash
# /home/luis/health-check.sh
# Health Check Script - Server 217.216.64.237

echo "🔍 HEALTH CHECK - $(date)"
echo ""

# Containers
running=$(docker ps -q | wc -l)
total=$(docker ps -aq | wc -l)
echo "✅ Containers running: $running/$total"

# Databases
pg_dbs=$(docker exec postgres-standalone psql -U postgres -t -c "SELECT COUNT(*) FROM pg_database WHERE datistemplate = false;" 2>/dev/null | tr -d ' ' || echo "0")
echo "✅ PostgreSQL databases: $pg_dbs"

# Critical services
vw=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8880/)
nc=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/)
echo "✅ Vaultwarden: HTTP $vw"
echo "⚠️ Nextcloud: HTTP $nc"

# Nginx
nginx_status=$(systemctl is-active nginx)
echo "✅ Nginx: $nginx_status"

# Resources
ram_pct=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
disk_pct=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
echo "✅ RAM: ${ram_pct}% used"
echo "✅ Disk: ${disk_pct}% used"

echo ""
if [ "$nc" == "200" ]; then
    echo "Status: ALL SYSTEMS OPERATIONAL ✅"
else
    echo "Status: PARTIAL - NEXTCLOUD NEEDS ATTENTION ⚠️"
fi
