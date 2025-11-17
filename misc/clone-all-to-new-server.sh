#!/bin/bash
# Clone all repositories to new server with clean structure
# Run this script ON THE NEW SERVER (217.216.64.237)

set -e

echo "=== CLONING ALL REPOS TO NEW SERVER ==="
echo ""

# Statistics
total_repos=0
cloned_repos=0
failed_repos=0

# Base directory
BASE_DIR=~/projects

# Create structure
mkdir -p $BASE_DIR/{active/{ai,web,infrastructure,tools,medical,finance,agriculture},company,experiments,archived}

# Function to clone repo
clone_repo() {
  local url=$1
  local target_dir=$2
  local repo_name=$(basename "$url" .git)
  
  echo "[$(date +%T)] Cloning $repo_name to $target_dir..."
  
  if [ -d "$target_dir/$repo_name" ]; then
    echo "  ⚠️  Already exists, skipping"
    return 0
  fi
  
  if git clone "$url" "$target_dir/$repo_name" 2>/dev/null; then
    echo "  ✅ Cloned successfully"
    ((cloned_repos++))
    return 0
  else
    echo "  ❌ Failed to clone"
    ((failed_repos++))
    return 1
  fi
}

# AI Projects
echo ""
echo "=== CLONING AI PROJECTS ==="
clone_repo "git@github.com:larancibia/ai-investigador-system.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-autonomous-scrum-team.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-business-rules-engine.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-dev-team.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-scrum-team.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-gmail-organizer.git" "$BASE_DIR/active/ai"
clone_repo "git@github.com:larancibia/ai-iterm2-orchestrator.git" "$BASE_DIR/active/ai"

# Web Projects
echo ""
echo "=== CLONING WEB PROJECTS ==="
clone_repo "git@github.com:larancibia/web-autoscribe.git" "$BASE_DIR/active/web"
clone_repo "git@github.com:larancibia/web-fireman-developer.git" "$BASE_DIR/active/web"
clone_repo "git@github.com:larancibia/web-maxwell.git" "$BASE_DIR/active/web"

# Infrastructure/Platform Projects
echo ""
echo "=== CLONING INFRASTRUCTURE PROJECTS ==="
clone_repo "git@github.com:larancibia/platform-deployer.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/platform-guanacolabs-sites.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/mini-autodeploy-platform.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/ops-infrastructure-contabo.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/ops-devops-toolkit.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/ops-ubuntu-server-setup.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/ops-server-setup.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/ops-memory-optimizer.git" "$BASE_DIR/active/infrastructure"

# Tools Projects
echo ""
echo "=== CLONING TOOLS PROJECTS ==="
clone_repo "git@github.com:larancibia/tools-photo-swiper.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-ocr-testing-tool.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-qr-code-generator.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-auto-chat-typer.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-dotfiles.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-sidedoc-app.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-notebooklm-bulk-importer.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/dev-intellij-copy-files-plugin.git" "$BASE_DIR/active/tools"

# Medical Projects
echo ""
echo "=== CLONING MEDICAL PROJECTS ==="
clone_repo "git@github.com:larancibia/med-posturography-systems.git" "$BASE_DIR/active/medical"
clone_repo "git@github.com:larancibia/med-matlab-labis.git" "$BASE_DIR/active/medical"
clone_repo "git@github.com:larancibia/orthoposture.git" "$BASE_DIR/active/medical"

# Finance Projects
echo ""
echo "=== CLONING FINANCE PROJECTS ==="
clone_repo "git@github.com:larancibia/fin-crypto-arbitrage-bot.git" "$BASE_DIR/active/finance"
clone_repo "git@github.com:larancibia/fin-fintelliview.git" "$BASE_DIR/active/finance"
clone_repo "git@github.com:larancibia/trading-strategy.git" "$BASE_DIR/active/finance"

# Agriculture Projects
echo ""
echo "=== CLONING AGRICULTURE PROJECTS ==="
clone_repo "git@github.com:larancibia/agro-management-app.git" "$BASE_DIR/active/agriculture"
clone_repo "git@github.com:larancibia/agro-platform.git" "$BASE_DIR/active/agriculture"

# Company Projects
echo ""
echo "=== CLONING COMPANY PROJECTS ==="
clone_repo "git@github.com:larancibia/company-guanacolabs-projects-hub.git" "$BASE_DIR/company"
clone_repo "git@github.com:larancibia/company-guanacolabs-telegram-bot.git" "$BASE_DIR/company"
clone_repo "git@github.com:larancibia/company-guanacolabs-website.git" "$BASE_DIR/company"
clone_repo "git@github.com:larancibia/company-guanacolabs-starter-template.git" "$BASE_DIR/company"

# Documentation Projects
echo ""
echo "=== CLONING DOCUMENTATION PROJECTS ==="
clone_repo "git@github.com:larancibia/doc-artisdoc-monorepo.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/doc-docma-monorepo.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/doc-projects-overview.git" "$BASE_DIR/active/infrastructure"
clone_repo "git@github.com:larancibia/doc-tradinglatino-transcripts.git" "$BASE_DIR/active/infrastructure"

# MCP Projects
echo ""
echo "=== CLONING MCP PROJECTS ==="
clone_repo "git@github.com:larancibia/mcp-bitwarden-enhanced.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/mcp-annas-archive.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/mcp-whatsapp-secure.git" "$BASE_DIR/active/tools"
clone_repo "git@github.com:larancibia/mcp-claude-global-config.git" "$BASE_DIR/active/tools"

# Experiments/Legacy
echo ""
echo "=== CLONING EXPERIMENTS ==="
clone_repo "git@github.com:larancibia/claude-agent-poc.git" "$BASE_DIR/experiments"
clone_repo "git@github.com:larancibia/challenge-nauta.git" "$BASE_DIR/experiments"
clone_repo "git@github.com:larancibia/autonomous-driver-agent.git" "$BASE_DIR/experiments"
clone_repo "git@github.com:larancibia/personal-dashboard.git" "$BASE_DIR/experiments"
clone_repo "git@github.com:larancibia/guanaco-secrets-vault.git" "$BASE_DIR/experiments"

# Archived Projects
echo ""
echo "=== CLONING ARCHIVED PROJECTS ==="
clone_repo "git@github.com:larancibia/archived-senales-interactivo.git" "$BASE_DIR/archived"
clone_repo "git@github.com:larancibia/archive-GuanacoBotApp.git" "$BASE_DIR/archived"
clone_repo "git@github.com:larancibia/archive-guanaco-labs.git" "$BASE_DIR/archived"
clone_repo "git@github.com:larancibia/archive-guanacobot-main.git" "$BASE_DIR/archived"

# Final Statistics
echo ""
echo "=== CLONING COMPLETE ==="
echo "✅ Successfully cloned: $cloned_repos repos"
echo "❌ Failed to clone: $failed_repos repos"
echo ""
echo "Verifying structure..."
find $BASE_DIR -name .git -type d | wc -l | xargs echo "Total repos in $BASE_DIR:"
echo ""
echo "Directory structure:"
tree -L 3 -d $BASE_DIR | head -50

