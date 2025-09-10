#!/bin/bash

# Phase 4: Fix all remaining module references after Phase 3 renames
# This script fixes the 141 compilation warnings

echo "Phase 4: Fixing Remaining Module References"
echo "==========================================="
echo ""

# Function to fix aliases in a file
fix_alias() {
    local file=$1
    local old_alias=$2
    local new_alias=$3
    
    if [ -f "$file" ]; then
        echo "  Fixing: $(basename $file)"
        # Fix alias statements
        sed -i '' "s/alias $old_alias/alias $new_alias/g" "$file" 2>/dev/null || true
        # Fix direct references with dot notation
        sed -i '' "s/${old_alias}\\./${new_alias}./g" "$file" 2>/dev/null || true
    fi
}

echo "Step 1: Fixing UI.State.Management.Server references (71 occurrences)"
echo "----------------------------------------------------------------------"
# These files need the alias fixed
fix_alias "lib/raxol/ui/state/hooks_functional.ex" \
    "Raxol.UI.State.Management.Server" \
    "Raxol.UI.State.Management.StateManagementServer, as: Server"

fix_alias "lib/raxol/ui/state/hooks_refactored.ex" \
    "Raxol.UI.State.Management.Server" \
    "Raxol.UI.State.Management.StateManagementServer, as: Server"

# Fix direct references in all files
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.UI\.State\.Management\.Server/Raxol.UI.State.Management.StateManagementServer/g' {} \; 2>/dev/null

echo ""
echo "Step 2: Fixing Animation.Gestures.Server references (21 occurrences)"
echo "--------------------------------------------------------------------"
fix_alias "lib/raxol/animation/gestures.ex" \
    "Raxol.Animation.Gestures.Server" \
    "Raxol.Animation.Gestures.GestureServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Animation\.Gestures\.Server/Raxol.Animation.Gestures.GestureServer/g' {} \; 2>/dev/null

echo ""
echo "Step 3: Fixing Security.UserContext.Server references (14 occurrences)"
echo "----------------------------------------------------------------------"
fix_alias "lib/raxol/security/user_context.ex" \
    "Raxol.Security.UserContext.Server" \
    "Raxol.Security.UserContext.ContextServer, as: Server"

fix_alias "lib/raxol/security/encryption/key_manager.ex" \
    "Raxol.Security.UserContext.Server" \
    "Raxol.Security.UserContext.ContextServer"

fix_alias "lib/raxol/security/encryption/encryption_config.ex" \
    "Raxol.Security.UserContext.Server" \
    "Raxol.Security.UserContext.ContextServer"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Security\.UserContext\.Server/Raxol.Security.UserContext.ContextServer/g' {} \; 2>/dev/null

echo ""
echo "Step 4: Fixing AI.PerformanceOptimization.Server references (11 occurrences)"
echo "---------------------------------------------------------------------------"
fix_alias "lib/raxol/ai/performance_optimization.ex" \
    "Raxol.AI.PerformanceOptimization.Server" \
    "Raxol.AI.PerformanceOptimization.OptimizationServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.AI\.PerformanceOptimization\.Server/Raxol.AI.PerformanceOptimization.OptimizationServer/g' {} \; 2>/dev/null

echo ""
echo "Step 5: Fixing Cloud.Monitoring.Server references (9 occurrences)"
echo "-----------------------------------------------------------------"
fix_alias "lib/raxol/cloud/monitoring.ex" \
    "Raxol.Cloud.Monitoring.Server" \
    "Raxol.Cloud.Monitoring.MonitoringServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Cloud\.Monitoring\.Server/Raxol.Cloud.Monitoring.MonitoringServer/g' {} \; 2>/dev/null

echo ""
echo "Step 6: Fixing Svelte.ComponentState.Server references (7 occurrences)"
echo "----------------------------------------------------------------------"
fix_alias "lib/raxol/svelte/component_state.ex" \
    "Raxol.Svelte.ComponentState.Server" \
    "Raxol.Svelte.ComponentState.SvelteStateServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Svelte\.ComponentState\.Server/Raxol.Svelte.ComponentState.SvelteStateServer/g' {} \; 2>/dev/null

echo ""
echo "Step 7: Fixing Core.Events.EventManager.Server references (4 occurrences)"
echo "-------------------------------------------------------------------------"
# This one is tricky - the Server is actually in a subfolder
fix_alias "lib/raxol/core/events/event_manager.ex" \
    "Raxol.Core.Events.EventManager.Server" \
    "Raxol.Core.Events.EventManager.EventManagerServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Core\.Events\.EventManager\.Server/Raxol.Core.Events.EventManager.EventManagerServer/g' {} \; 2>/dev/null

echo ""
echo "Step 8: Fixing Cloud.EdgeComputing.Server references (3 occurrences)"
echo "--------------------------------------------------------------------"
fix_alias "lib/raxol/cloud/edge_computing.ex" \
    "Raxol.Cloud.EdgeComputing.Server" \
    "Raxol.Cloud.EdgeComputing.EdgeServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Cloud\.EdgeComputing\.Server/Raxol.Cloud.EdgeComputing.EdgeServer/g' {} \; 2>/dev/null

echo ""
echo "Step 9: Fixing Terminal.Emulator.Server references"
echo "--------------------------------------------------"
fix_alias "lib/raxol/terminal/emulator.ex" \
    "Raxol.Terminal.Emulator.Server" \
    "Raxol.Terminal.Emulator.EmulatorServer, as: Server"

find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Terminal\.Emulator\.Server/Raxol.Terminal.Emulator.EmulatorServer/g' {} \; 2>/dev/null

echo ""
echo "Step 10: Fixing remaining State references"
echo "------------------------------------------"
# Terminal.Cursor.State -> CursorState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Terminal\.Cursor\.State/Raxol.Terminal.Cursor.CursorState/g' {} \; 2>/dev/null

# Terminal.Buffer.State -> BufferState  
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Terminal\.Buffer\.State/Raxol.Terminal.Buffer.BufferState/g' {} \; 2>/dev/null

# Terminal.Emulator.State -> EmulatorState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Terminal\.Emulator\.State/Raxol.Terminal.Emulator.EmulatorState/g' {} \; 2>/dev/null

# Terminal.Parser.State -> ParserState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Terminal\.Parser\.State/Raxol.Terminal.Parser.ParserState/g' {} \; 2>/dev/null

# Core.Terminal.State -> TerminalState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.Core\.Terminal\.State/Raxol.Core.Terminal.TerminalState/g' {} \; 2>/dev/null

# UI.Components.Modal.State -> ModalState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.UI\.Components\.Modal\.State/Raxol.UI.Components.Modal.ModalState/g' {} \; 2>/dev/null

# System.Updater.State -> UpdaterState
find lib -name "*.ex" -exec sed -i '' \
    's/Raxol\.System\.Updater\.State/Raxol.System.Updater.UpdaterState/g' {} \; 2>/dev/null

echo ""
echo "Phase 4 Complete!"
echo "================="
echo ""
echo "Next steps:"
echo "1. Run 'TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile' to verify"
echo "2. Check for any remaining warnings"
echo "3. Run the full test suite"
echo ""
echo "Expected result: 0 compilation warnings (down from 141)"