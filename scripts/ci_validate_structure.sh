#!/bin/bash
# CI Validation Script for Raxol Module Structure
# Ensures consistency with the refactored codebase structure

set -e

echo "==================================="
echo "Raxol CI Structure Validation"
echo "==================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Counter for checks
CHECKS_PASSED=0
CHECKS_FAILED=0

# Function to check if a module exists
check_module() {
    local module_path=$1
    local module_name=$2
    
    if [ -f "$module_path" ]; then
        echo -e "${GREEN}✓${NC} $module_name exists"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $module_name missing at $module_path"
        ((CHECKS_FAILED++))
    fi
}

# Function to check directory structure
check_directory() {
    local dir_path=$1
    local dir_name=$2
    
    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}✓${NC} $dir_name directory exists"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $dir_name directory missing at $dir_path"
        ((CHECKS_FAILED++))
    fi
}

echo ""
echo "1. Checking Graphics Module Structure..."
echo "-----------------------------------------"

# Check new graphics modules from the refactoring
check_module "lib/raxol/terminal/graphics/data_visualization.ex" "DataVisualization"
check_module "lib/raxol/terminal/graphics/chart_renderers.ex" "ChartRenderers"
check_module "lib/raxol/terminal/graphics/chart_operations.ex" "ChartOperations"
check_module "lib/raxol/terminal/graphics/chart_export.ex" "ChartExport"
check_module "lib/raxol/terminal/graphics/visualization_helpers.ex" "VisualizationHelpers"
check_module "lib/raxol/terminal/graphics/streaming_manager.ex" "StreamingManager"
check_module "lib/raxol/terminal/graphics/gpu_accelerator.ex" "GPUAccelerator"
check_module "lib/raxol/terminal/graphics/memory_manager.ex" "MemoryManager"

echo ""
echo "2. Checking Core Module Structure..."
echo "-------------------------------------"

check_directory "lib/raxol/core" "Core"
check_module "lib/raxol/core/error_handling.ex" "ErrorHandling"
check_module "lib/raxol/core/accessibility.ex" "Accessibility"

echo ""
echo "3. Checking Test Structure..."
echo "------------------------------"

check_directory "test/raxol/terminal/graphics" "Graphics Tests"
check_module "test/raxol/terminal/graphics/kitty_protocol_test.exs" "KittyProtocol Tests"

echo ""
echo "4. Compilation Checks..."
echo "-------------------------"

# Check for zero warnings
echo "Running compilation with warnings as errors..."
if SKIP_TERMBOX2_TESTS=true mix compile --warnings-as-errors 2>&1 | grep -q "warning:"; then
    echo -e "${RED}✗${NC} Compilation warnings detected"
    ((CHECKS_FAILED++))
else
    echo -e "${GREEN}✓${NC} Zero compilation warnings"
    ((CHECKS_PASSED++))
fi

echo ""
echo "5. Code Quality Metrics..."
echo "---------------------------"

# Check if statement count (should be 2 or less)
IF_COUNT=$(grep -r "^\s*if\s" lib/ --include="*.ex" --include="*.exs" | grep -v "# if" | wc -l)
echo "If statement count: $IF_COUNT"
if [ "$IF_COUNT" -le 2 ]; then
    echo -e "${GREEN}✓${NC} If statement elimination target met (≤2)"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Too many if statements: $IF_COUNT (target: ≤2)"
    ((CHECKS_FAILED++))
fi

# Check for proper module documentation
echo ""
echo "6. Module Documentation Check..."
echo "---------------------------------"

for module in lib/raxol/terminal/graphics/*.ex; do
    if grep -q "@moduledoc" "$module"; then
        echo -e "${GREEN}✓${NC} $(basename $module) has @moduledoc"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $(basename $module) missing @moduledoc"
        ((CHECKS_FAILED++))
    fi
done

echo ""
echo "==================================="
echo "Validation Summary"
echo "==================================="
echo -e "Checks Passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks Failed: ${RED}$CHECKS_FAILED${NC}"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ All validation checks passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Validation failed with $CHECKS_FAILED errors${NC}"
    exit 1
fi