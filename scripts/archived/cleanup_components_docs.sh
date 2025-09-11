#!/bin/bash

# Cleanup script for components documentation
# This script verifies the new structure and removes redundant files

set -e

echo "🧹 Cleaning up components documentation..."

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo "❌ Error: This script must be run from the project root"
    exit 1
fi

# Define the expected structure
EXPECTED_FILES=(
    "docs/components/README.md"
    "docs/components/style_guide.md"
    "docs/components/testing.md"
    "docs/components/api/README.md"
)

# Check for expected files
echo "📋 Checking expected files..."
for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

# List all files in components directory
echo ""
echo "📁 Current components documentation structure:"
find docs/components -type f -name "*.md" | sort

# Count files
TOTAL_FILES=$(find docs/components -type f -name "*.md" | wc -l)
echo ""
echo "📊 Total files: $TOTAL_FILES"

# Check for any remaining redundant files
echo ""
echo "🔍 Checking for redundant files..."

# Look for files that might be redundant
REDUNDANT_PATTERNS=(
    "*_api.md"
    "*_reference.md"
    "*_guide.md"
    "*_manual.md"
    "*_tutorial.md"
    "*_examples.md"
    "*_patterns.md"
    "*_best_practices.md"
)

REDUNDANT_FILES=()
for pattern in "${REDUNDANT_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
        if [[ "$file" != "docs/components/README.md" && 
              "$file" != "docs/components/style_guide.md" && 
              "$file" != "docs/components/testing.md" && 
              "$file" != "docs/components/api/README.md" ]]; then
            REDUNDANT_FILES+=("$file")
        fi
    done < <(find docs/components -name "$pattern" -print0 2>/dev/null)
done

if [ ${#REDUNDANT_FILES[@]} -gt 0 ]; then
    echo "⚠️  Found potentially redundant files:"
    for file in "${REDUNDANT_FILES[@]}"; do
        echo "   - $file"
    done
    
    echo ""
    read -p "🗑️  Remove these files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${REDUNDANT_FILES[@]}"; do
            rm "$file"
            echo "🗑️  Removed: $file"
        done
    fi
else
    echo "✅ No redundant files found"
fi

# Check for empty directories
echo ""
echo "📂 Checking for empty directories..."
find docs/components -type d -empty -print

# Verify file sizes are reasonable
echo ""
echo "📏 Checking file sizes..."
for file in "${EXPECTED_FILES[@]}"; do
    size=$(wc -c < "$file")
    if [ "$size" -lt 100 ]; then
        echo "⚠️  Warning: $file is very small ($size bytes)"
    elif [ "$size" -gt 50000 ]; then
        echo "⚠️  Warning: $file is very large ($size bytes)"
    else
        echo "✅ $file: $size bytes"
    fi
done

# Check for broken links
echo ""
echo "🔗 Checking for broken internal links..."
for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Look for markdown links
        links=$(grep -o '\[.*\]([^)]*)' "$file" | sed 's/.*(\([^)]*\))/\1/' | grep -v '^http' | grep -v '^#' || true)
        
        for link in $links; do
            if [[ "$link" == *".md"* ]]; then
                target_file=$(echo "$link" | sed 's/^\.\///')
                if [ ! -f "$target_file" ]; then
                    echo "⚠️  Broken link in $file: $link"
                fi
            fi
        done
    fi
done

# Final summary
echo ""
echo "🎉 Components documentation cleanup complete!"
echo ""
echo "📋 Final structure:"
tree docs/components 2>/dev/null || find docs/components -type f -name "*.md" | sort

echo ""
echo "📊 Summary:"
echo "   - Expected files: ${#EXPECTED_FILES[@]}"
echo "   - Total files: $(find docs/components -type f -name "*.md" | wc -l)"
echo "   - Redundant files removed: ${#REDUNDANT_FILES[@]}"

echo ""
echo "✅ Components documentation is now clean and organized!" 