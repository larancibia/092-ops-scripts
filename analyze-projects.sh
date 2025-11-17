#!/bin/bash
# Project Analysis Script
# Scans all projects and determines tech stack and deployment requirements

PROJECTS_DIR="/home/luis/projects"
OUTPUT_FILE="/home/luis/scripts/project-analysis.json"

echo "{" > "$OUTPUT_FILE"
echo '  "analysis_date": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "$OUTPUT_FILE"
echo '  "projects": {' >> "$OUTPUT_FILE"

first=true

for project_dir in "$PROJECTS_DIR"/*; do
    # Skip non-directories and meta directories
    if [ ! -d "$project_dir" ]; then
        continue
    fi

    project_name=$(basename "$project_dir")

    # Skip meta directories
    if [[ "$project_name" == "active" ]] || [[ "$project_name" == "archived" ]] || \
       [[ "$project_name" == "company" ]] || [[ "$project_name" == "experiments" ]] || \
       [[ "$project_name" == "ops" ]] || [[ "$project_name" == "mi-wiki" ]]; then
        continue
    fi

    # Add comma separator (except for first entry)
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    echo "    \"$project_name\": {" >> "$OUTPUT_FILE"

    # Detect tech stack
    has_package_json=false
    has_cargo_toml=false
    has_requirements_txt=false
    has_pom_xml=false
    has_go_mod=false
    has_docker=false
    has_dockerfile=false
    has_docker_compose=false

    [ -f "$project_dir/package.json" ] && has_package_json=true
    [ -f "$project_dir/Cargo.toml" ] && has_cargo_toml=true
    [ -f "$project_dir/requirements.txt" ] && has_requirements_txt=true
    [ -f "$project_dir/pom.xml" ] && has_pom_xml=true
    [ -f "$project_dir/go.mod" ] && has_go_mod=true
    [ -f "$project_dir/Dockerfile" ] && has_dockerfile=true
    [ -f "$project_dir/docker-compose.yml" ] && has_docker_compose=true

    # Detect project type
    tech_stack=""
    project_type=""

    if [ "$has_package_json" = true ]; then
        tech_stack="node.js"
        # Check if it's Next.js, React, Vue, etc.
        if grep -q '"next"' "$project_dir/package.json" 2>/dev/null; then
            tech_stack="next.js"
            project_type="frontend"
        elif grep -q '"react"' "$project_dir/package.json" 2>/dev/null; then
            tech_stack="react"
            project_type="frontend"
        elif grep -q '"vue"' "$project_dir/package.json" 2>/dev/null; then
            tech_stack="vue"
            project_type="frontend"
        elif grep -q '"express"' "$project_dir/package.json" 2>/dev/null; then
            tech_stack="express"
            project_type="backend"
        elif grep -q '"fastify"' "$project_dir/package.json" 2>/dev/null; then
            tech_stack="fastify"
            project_type="backend"
        fi
    elif [ "$has_cargo_toml" = true ]; then
        tech_stack="rust"
        if grep -q "axum\|actix\|rocket" "$project_dir/Cargo.toml" 2>/dev/null; then
            project_type="backend"
        else
            project_type="cli"
        fi
    elif [ "$has_requirements_txt" = true ]; then
        tech_stack="python"
        if grep -q "fastapi\|flask\|django" "$project_dir/requirements.txt" 2>/dev/null; then
            project_type="backend"
        else
            project_type="cli"
        fi
    elif [ "$has_pom_xml" = true ]; then
        tech_stack="java"
        project_type="backend"
    elif [ "$has_go_mod" = true ]; then
        tech_stack="go"
        project_type="backend"
    else
        tech_stack="unknown"
        project_type="unknown"
    fi

    # Check for database requirements
    needs_postgres=false
    needs_redis=false

    if [ -f "$project_dir/package.json" ]; then
        grep -q "pg\|postgres\|prisma" "$project_dir/package.json" 2>/dev/null && needs_postgres=true
        grep -q "redis\|ioredis" "$project_dir/package.json" 2>/dev/null && needs_redis=true
    fi

    if [ -f "$project_dir/requirements.txt" ]; then
        grep -q "psycopg\|asyncpg\|sqlalchemy" "$project_dir/requirements.txt" 2>/dev/null && needs_postgres=true
        grep -q "redis\|aioredis" "$project_dir/requirements.txt" 2>/dev/null && needs_redis=true
    fi

    # Output JSON
    echo "      \"tech_stack\": \"$tech_stack\"," >> "$OUTPUT_FILE"
    echo "      \"project_type\": \"$project_type\"," >> "$OUTPUT_FILE"
    echo "      \"has_package_json\": $has_package_json," >> "$OUTPUT_FILE"
    echo "      \"has_cargo_toml\": $has_cargo_toml," >> "$OUTPUT_FILE"
    echo "      \"has_requirements_txt\": $has_requirements_txt," >> "$OUTPUT_FILE"
    echo "      \"has_pom_xml\": $has_pom_xml," >> "$OUTPUT_FILE"
    echo "      \"has_go_mod\": $has_go_mod," >> "$OUTPUT_FILE"
    echo "      \"has_dockerfile\": $has_dockerfile," >> "$OUTPUT_FILE"
    echo "      \"has_docker_compose\": $has_docker_compose," >> "$OUTPUT_FILE"
    echo "      \"needs_postgres\": $needs_postgres," >> "$OUTPUT_FILE"
    echo "      \"needs_redis\": $needs_redis" >> "$OUTPUT_FILE"
    echo -n "    }" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "  }" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "Analysis complete. Results saved to $OUTPUT_FILE"
