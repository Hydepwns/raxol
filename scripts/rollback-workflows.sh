#!/bin/bash

# Workflow Rollback Script
# Use this to rollback to the old workflow structure if needed

set -e

echo "========================================="
echo "GitHub Actions Workflow Rollback"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEPRECATED_DIR=".github/workflows-deprecated"

echo ""
echo "This will rollback to the old workflow structure."
read -p "Are you sure you want to rollback? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled."
    exit 1
fi

echo ""
echo "Step 1: Restoring deprecated workflows..."
echo "-----------------------------------------"

if [ -d "$DEPRECATED_DIR" ]; then
    for workflow in "$DEPRECATED_DIR"/*.yml; do
        if [ -f "$workflow" ]; then
            filename=$(basename "$workflow")
            mv "$workflow" ".github/workflows/"
            echo -e "${GREEN}✓${NC}  Restored $filename"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC}  No deprecated workflows found"
fi

echo ""
echo "Step 2: Removing new workflows..."
echo "----------------------------------"

NEW_WORKFLOWS=(
    "ci-unified.yml"
    "security.yml"
    "nightly.yml"
)

for workflow in "${NEW_WORKFLOWS[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        rm ".github/workflows/$workflow"
        echo -e "${GREEN}✓${NC}  Removed $workflow"
    fi
done

echo ""
echo "Step 3: Reverting PR comment workflow..."
echo "----------------------------------------"

if [ -f ".github/workflows/pr-comment.yml" ]; then
    sed -i.bak 's/workflows: \["Unified CI Pipeline"\]/workflows: ["Raxol Pre-commit Checks"]/' .github/workflows/pr-comment.yml
    rm .github/workflows/pr-comment.yml.bak
    echo -e "${GREEN}✓${NC}  Reverted pr-comment.yml"
fi

echo ""
echo "Step 4: Cleaning up..."
echo "----------------------"

rm -f .github/workflows/MIGRATION_NOTICE.md
rm -rf "$DEPRECATED_DIR"
echo -e "${GREEN}✓${NC}  Cleanup complete"

echo ""
echo "========================================="
echo -e "${GREEN}Rollback Complete!${NC}"
echo "========================================="
echo ""
echo "The old workflow structure has been restored."
echo "Remember to update branch protection rules back to the old workflow names."
echo ""