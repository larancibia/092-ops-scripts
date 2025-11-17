#!/bin/bash

# Obtener lista de repositorios
repos=$(gh repo list larancibia --limit 100 --json nameWithOwner --jq '.[].nameWithOwner')

echo "Repositorios válidos para deployment:"
echo "======================================"

for repo in $repos; do
  # Verificar si tiene backend/pom.xml
  has_backend=$(gh api repos/$repo/contents/backend/pom.xml 2>/dev/null && echo "yes" || echo "no")
  
  # Verificar si tiene web/package.json
  has_web=$(gh api repos/$repo/contents/web/package.json 2>/dev/null && echo "yes" || echo "no")
  
  # Si tiene al menos uno, es válido
  if [ "$has_backend" = "yes" ] || [ "$has_web" = "yes" ]; then
    components=""
    [ "$has_backend" = "yes" ] && components="API"
    [ "$has_web" = "yes" ] && components="$components WEB"
    echo "✓ $repo ($components)"
  fi
done
