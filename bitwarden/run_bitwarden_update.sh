#!/bin/bash

# Quick runner script for Bitwarden credentials update
# This script will prompt for your master password once and then update all credentials

echo "=== Bitwarden Database Credentials Update ==="
echo ""
echo "This script will:"
echo "  1. Unlock your Bitwarden vault (you'll need to enter your master password)"
echo "  2. Update or create 3 database credentials:"
echo "     - PostgreSQL Standalone Server"
echo "     - Redis Standalone Server"
echo "     - MySQL Standalone Server"
echo "  3. Sync the vault"
echo "  4. Lock the vault when done"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Unlock and get session token
echo ""
echo "Unlocking vault..."
export BW_SESSION=$(bw unlock --raw)

if [ -z "$BW_SESSION" ]; then
    echo "ERROR: Failed to unlock vault. Please check your master password."
    exit 1
fi

echo "✓ Vault unlocked successfully!"
echo ""

# Run the main update script
/home/luis/bitwarden_credentials_update.sh

# The script will lock the vault at the end
unset BW_SESSION

echo ""
echo "Done! Check the output above for details on what was created or updated."
