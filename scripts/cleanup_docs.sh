#!/bin/bash

# Raxol Documentation Cleanup Script
# This script removes redundant documentation files and reorganizes the structure

set -e

echo "=== Raxol Documentation Cleanup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

# Function to safely remove file
remove_file() {
    local file=$1
    local reason=$2
    if [ -f "$file" ]; then
        rm "$file"
        print_status "OK" "Removed $file ($reason)"
    else
        print_status "WARN" "File not found: $file"
    fi
}

# Function to safely remove directory
remove_dir() {
    local dir=$1
    local reason=$2
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        print_status "OK" "Removed directory $dir ($reason)"
    else
        print_status "WARN" "Directory not found: $dir"
    fi
}

echo "1. Removing redundant testing files..."
remove_file "docs/testing/test_writing_guide.md" "consolidated into testing/README.md"
remove_file "docs/testing/quality.md" "consolidated into testing/README.md"
remove_file "docs/testing/coverage.md" "consolidated into testing/README.md"
remove_file "docs/testing/performance_testing.md" "consolidated into testing/README.md"
remove_file "docs/testing/prometheus.md" "consolidated into testing/README.md"
remove_file "docs/testing/test_tracking.md" "consolidated into testing/README.md"
remove_file "docs/testing/tools.md" "consolidated into testing/README.md"
remove_file "docs/testing/COMPILATION_ERROR_PLAN.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/testing/CRITICAL_FIXES_QUICK_REFERENCE.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/testing/TEST_ORGANIZATION.md" "consolidated into testing/README.md"
remove_file "docs/testing/ai_agent_guide.md" "consolidated into testing/README.md"
remove_file "docs/testing/analysis.md" "consolidated into testing/README.md"

echo ""
echo "2. Removing redundant component files..."
remove_file "docs/components/component_architecture.md" "consolidated into components/README.md"
remove_file "docs/components/composition.md" "consolidated into components/README.md"
remove_file "docs/components/dependency_manager.md" "consolidated into components/README.md"
remove_file "docs/components/file_watcher.md" "consolidated into components/README.md"
remove_file "docs/components/table.md" "consolidated into components/README.md"

echo ""
echo "3. Removing redundant changes files..."
remove_file "docs/changes/common_test_failures.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/changes/database-fixes.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/changes/refactoring.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/changes/single_line_input_syntax_error.md" "consolidated into TROUBLESHOOTING.md"
remove_file "docs/changes/LARGE_FILES_FOR_REFACTOR.md" "consolidated into TROUBLESHOOTING.md"

echo ""
echo "4. Removing redundant metrics files..."
remove_file "docs/metrics/UNIFIED_METRICS.md" "consolidated into TROUBLESHOOTING.md"

echo ""
echo "5. Cleaning up empty directories..."
if [ -d "docs/testing" ] && [ -z "$(ls -A docs/testing)" ]; then
    remove_dir "docs/testing" "empty after cleanup"
fi

if [ -d "docs/changes" ] && [ -z "$(ls -A docs/changes)" ]; then
    remove_dir "docs/changes" "empty after cleanup"
fi

if [ -d "docs/metrics" ] && [ -z "$(ls -A docs/metrics)" ]; then
    remove_dir "docs/metrics" "empty after cleanup"
fi

echo ""
echo "6. Creating new directory structure..."

# Create new testing directory with consolidated content
mkdir -p docs/testing
if [ ! -f "docs/testing/README.md" ]; then
    print_status "WARN" "testing/README.md not found - please create it"
fi

# Keep the component API directory
if [ -d "docs/components/api" ]; then
    print_status "OK" "Keeping components/api directory"
fi

# Keep the style guide
if [ -f "docs/components/style_guide.md" ]; then
    print_status "OK" "Keeping components/style_guide.md"
fi

echo ""
echo "7. Verifying new structure..."

# Check main documentation files
main_files=(
    "docs/README.md"
    "docs/DEVELOPMENT.md"
    "docs/ARCHITECTURE.md"
    "docs/CONFIGURATION.md"
    "docs/TROUBLESHOOTING.md"
    "docs/NIX_TROUBLESHOOTING.md"
    "docs/testing/README.md"
    "docs/components/README.md"
    "docs/components/testing.md"
)

for file in "${main_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "OK" "Main file exists: $file"
    else
        print_status "FAIL" "Missing main file: $file"
    fi
done

echo ""
echo "=== Cleanup Summary ==="
echo ""
echo "New documentation structure:"
echo "docs/"
echo "├── README.md                    # Main documentation index"
echo "├── DEVELOPMENT.md               # Development setup and workflow"
echo "├── ARCHITECTURE.md              # System architecture"
echo "├── CONFIGURATION.md             # Configuration guide"
echo "├── TROUBLESHOOTING.md           # General troubleshooting"
echo "├── NIX_TROUBLESHOOTING.md       # Nix-specific issues"
echo "├── testing/"
echo "│   └── README.md                # Unified testing guide"
echo "└── components/"
echo "    ├── README.md                # Component guide"
echo "    ├── testing.md               # Component testing"
echo "    ├── style_guide.md           # Styling patterns"
echo "    └── api/                     # Component APIs"
echo ""

print_status "OK" "Documentation cleanup completed!"
echo ""
echo "Next steps:"
echo "1. Review the consolidated documentation"
echo "2. Update any remaining cross-references"
echo "3. Test the documentation navigation"
echo "4. Commit the changes" 