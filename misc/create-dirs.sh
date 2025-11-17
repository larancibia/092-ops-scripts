#!/bin/bash
set -e

# Create main directory structure
mkdir -p ~/projects/active/{ai,web,infrastructure,tools,medical,finance,agriculture}
mkdir -p ~/projects/company
mkdir -p ~/projects/experiments
mkdir -p ~/projects/archived
mkdir -p ~/docs
mkdir -p ~/config
mkdir -p ~/.private/{keys,scripts,config}
chmod 700 ~/.private

# For MCPs
mkdir -p ~/.claude/mcp-servers

# For WhatsApp drafts
mkdir -p ~/whatsapp-drafts
chmod 700 ~/whatsapp-drafts

echo "✅ Directory structure created!"
tree -L 3 ~/projects 2>/dev/null || ls -laR ~/projects
