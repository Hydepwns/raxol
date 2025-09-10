#!/bin/bash

# Fix remaining server references from Phase 3

echo "Fixing remaining server references..."
echo "====================================="

# Function to update references in a file
update_refs() {
    local file=$1
    local old_ref=$2
    local new_ref=$3
    
    echo "  Updating: $file"
    echo "    $old_ref -> $new_ref"
    
    # Update references
    sed -i '' "s/$old_ref/$new_ref/g" "$file" 2>/dev/null || true
}

echo ""
echo "Updating Memoization Server references..."
# Find files with Memoization.Server references
grep -r "Raxol.Core.Performance.Memoization.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Core.Performance.Memoization.Server" \
        "Raxol.Core.Performance.Memoization.MemoizationServer"
done

echo ""
echo "Updating UserContext Server references..."
# Find files with UserContext.Server references
grep -r "Raxol.Security.UserContext.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Security.UserContext.Server" \
        "Raxol.Security.UserContext.ContextServer"
done

echo ""
echo "Updating State Management Server references..."
# Find files with State.Management.Server references
grep -r "Raxol.UI.State.Management.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.UI.State.Management.Server" \
        "Raxol.UI.State.Management.StateManagementServer"
done

echo ""
echo "Updating Cloud Monitoring Server references..."
# Find files with Cloud.Monitoring.Server references
grep -r "Raxol.Cloud.Monitoring.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Cloud.Monitoring.Server" \
        "Raxol.Cloud.Monitoring.MonitoringServer"
done

echo ""
echo "Updating Terminal Window Manager Server references..."
# Find files with Terminal.Window.Manager.Server references
grep -r "Raxol.Terminal.Window.Manager.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Terminal.Window.Manager.Server" \
        "Raxol.Terminal.Window.Manager.WindowManagerServer"
done

echo ""
echo "Updating I18n Server references..."
grep -r "Raxol.Core.I18n.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Core.I18n.Server" \
        "Raxol.Core.I18n.I18nServer"
done

echo ""
echo "Updating Terminal Emulator Server references..."
grep -r "Raxol.Terminal.Emulator.Server" lib/ --include="*.ex" | cut -d: -f1 | sort -u | while read -r file; do
    update_refs "$file" \
        "Raxol.Terminal.Emulator.Server" \
        "Raxol.Terminal.Emulator.EmulatorServer"
done

echo ""
echo "Fixing server references complete!"
echo "==================================="