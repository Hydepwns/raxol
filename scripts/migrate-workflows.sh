#!/bin/bash

# CI/CD Workflow Migration Script
# This script archives deprecated workflows and activates the new unified pipeline

set -e

echo "========================================="
echo "GitHub Actions Workflow Migration"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create deprecated workflows directory
DEPRECATED_DIR=".github/workflows-deprecated"
mkdir -p "$DEPRECATED_DIR"

# List of workflows to deprecate
WORKFLOWS_TO_DEPRECATE=(
    "ci.yml"
    "raxol-checks.yml"
    "test-snyk.yml"
    "macos-ci-fix.yml"
    "ci-local.yml"
    "ci-local-deps.yml"
    "dummy-test.yml"
)

# List of workflows to keep
WORKFLOWS_TO_KEEP=(
    "ci-unified.yml"
    "security.yml"
    "nightly.yml"
    "release.yml"
    "performance-tracking.yml"
    "pr-comment.yml"
    "cross_platform_tests.yml"
)

echo ""
echo "Step 1: Checking current workflows..."
echo "--------------------------------------"

for workflow in "${WORKFLOWS_TO_DEPRECATE[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        echo -e "${YELLOW}⚠${NC}  $workflow - Will be archived"
    else
        echo -e "${GREEN}✓${NC}  $workflow - Already removed"
    fi
done

echo ""
echo "Step 2: Checking new workflows..."
echo "----------------------------------"

for workflow in "${WORKFLOWS_TO_KEEP[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        echo -e "${GREEN}✓${NC}  $workflow - Active"
    else
        echo -e "${RED}✗${NC}  $workflow - Missing!"
    fi
done

echo ""
echo "Step 3: Migration Actions"
echo "-------------------------"
echo "The following actions will be performed:"
echo "1. Move deprecated workflows to $DEPRECATED_DIR"
echo "2. Update pr-comment.yml to use ci-unified.yml"
echo "3. Create workflow dispatch triggers for testing"
echo ""

read -p "Do you want to proceed with migration? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 1
fi

echo ""
echo "Step 4: Archiving deprecated workflows..."
echo "-----------------------------------------"

for workflow in "${WORKFLOWS_TO_DEPRECATE[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        mv ".github/workflows/$workflow" "$DEPRECATED_DIR/"
        echo -e "${GREEN}✓${NC}  Archived $workflow"
    fi
done

echo ""
echo "Step 5: Updating PR comment workflow..."
echo "---------------------------------------"

# Update pr-comment.yml to reference the new workflow
if [ -f ".github/workflows/pr-comment.yml" ]; then
    sed -i.bak 's/workflows: \["Raxol Pre-commit Checks"\]/workflows: ["Unified CI Pipeline"]/' .github/workflows/pr-comment.yml
    rm .github/workflows/pr-comment.yml.bak
    echo -e "${GREEN}✓${NC}  Updated pr-comment.yml"
fi

echo ""
echo "Step 6: Creating transition notice..."
echo "-------------------------------------"

cat > .github/workflows/MIGRATION_NOTICE.md << 'EOF'
# Workflow Migration Notice

As of 2025-09-10, we have migrated to a new unified CI/CD pipeline.

## New Workflow Structure

- **Main CI**: `ci-unified.yml` replaces `ci.yml` and `raxol-checks.yml`
- **Security**: `security.yml` replaces `test-snyk.yml`
- **Nightly**: `nightly.yml` provides comprehensive regression testing

## For Developers

- All PR checks now run through `ci-unified.yml`
- Security scans are automated and don't require Docker
- Test results are reported faster due to parallelization

## Branch Protection Updates Needed

Please update your branch protection rules:
- Remove: "CI", "Raxol Pre-commit Checks"
- Add: "CI Status" (from ci-unified.yml)

## Questions?

Contact the maintainers or check the workflow documentation in `.github/workflows/README.md`
EOF

echo -e "${GREEN}✓${NC}  Created migration notice"

echo ""
echo "========================================="
echo -e "${GREEN}Migration Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review the changes with: git status"
echo "2. Test the new workflow with: gh workflow run ci-unified.yml"
echo "3. Update branch protection rules in GitHub settings"
echo "4. Commit the changes"
echo ""
echo "To rollback if needed:"
echo "  ./scripts/rollback-workflows.sh"
echo ""