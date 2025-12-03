#!/bin/bash
# Batch Migration for Staging Environment

STAGING_ROOT="/home/luis/projects_staging"

echo "Starting Staging Finalization..." >> /home/luis/projects/MIGRATION_LOG.txt

# Iterate over all directories in staging
for proj in "$STAGING_ROOT"/*; do
    if [ -d "$proj" ]; then
        # Skip non-project dirs if any
        if [[ "$proj" == *"ops-scripts"* || "$proj" == *"DeployHub"* ]]; then
            continue
        fi
        
        # Run the project migration tool to ensure start.sh and structure completeness
        # We use the existing tool but pass the staging path
        python3 /home/luis/projects/ops-scripts/migrate_project.py "$proj"
    fi
done

echo "Staging Environment Ready." >> /home/luis/projects/MIGRATION_LOG.txt
