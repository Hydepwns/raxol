#!/bin/bash

echo "Fixing all renamed module references from Phase 3..."
echo "===================================================="

# Fix EdgeComputing.Server references in edge_computing_core.ex
echo "Fixing EdgeComputing references..."
sed -i '' 's/Raxol\.Cloud\.EdgeComputing\.Server\./Raxol.Cloud.EdgeComputing.EdgeServer./g' lib/raxol/cloud/edge_computing/edge_computing_core.ex

# Fix UI.State.Management.Server references in store.ex
echo "Fixing UI State Management references in store.ex..."
sed -i '' 's/alias Raxol\.UI\.State\.Management\.Server/alias Raxol.UI.State.Management.StateManagementServer, as: Server/g' lib/raxol/ui/state/store.ex

# Fix UserContext.Server references that are still wrong
echo "Fixing remaining UserContext references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Security\.UserContext\.Server\./Raxol.Security.UserContext.ContextServer./g' {} \;

# Fix hooks files
echo "Fixing hooks files..."
sed -i '' 's/Raxol\.UI\.State\.Management\.Server/Raxol.UI.State.Management.StateManagementServer/g' lib/raxol/ui/state/hooks.ex

# Fix Terminal.Cursor.State references to CursorState
echo "Fixing Terminal Cursor State references..."
sed -i '' 's/alias Raxol\.Terminal\.Cursor\.State/alias Raxol.Terminal.Cursor.CursorState, as: State/g' lib/raxol/terminal/cursor/cursor_manager.ex

# Fix Terminal.Emulator.State references to EmulatorState
echo "Fixing Terminal Emulator State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Emulator\.State/Raxol.Terminal.Emulator.EmulatorState/g' {} \;

# Fix Terminal.Buffer.State references to BufferState  
echo "Fixing Terminal Buffer State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Buffer\.State/Raxol.Terminal.Buffer.BufferState/g' {} \;

# Fix Core.Terminal.State references to TerminalState
echo "Fixing Core Terminal State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Core\.Terminal\.State/Raxol.Core.Terminal.TerminalState/g' {} \;

# Fix UI Modal State references
echo "Fixing UI Modal State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.UI\.Components\.Modal\.State/Raxol.UI.Components.Modal.ModalState/g' {} \;

# Fix UI Pipeline State references
echo "Fixing UI Pipeline State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.UI\.Rendering\.Pipeline\.State/Raxol.UI.Rendering.Pipeline.PipelineState/g' {} \;

# Fix Playground State references
echo "Fixing Playground State references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Playground\.State/Raxol.Playground.PlaygroundState/g' {} \;

# Fix Terminal Config references
echo "Fixing Terminal Config references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Config/Raxol.Terminal.TerminalConfig/g' {} \;

# Fix Cloud Config references
echo "Fixing Cloud Config references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Cloud\.Config/Raxol.Cloud.CloudConfig/g' {} \;

# Fix Core Supervisor references
echo "Fixing Core Supervisor references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Core\.Supervisor/Raxol.Core.CoreSupervisor/g' {} \;

# Fix Runtime Supervisor references
echo "Fixing Runtime Supervisor references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Runtime\.Supervisor/Raxol.Runtime.RuntimeSupervisor/g' {} \;

# Fix Terminal Supervisor references
echo "Fixing Terminal Supervisor references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Supervisor/Raxol.Terminal.TerminalSupervisor/g' {} \;

# Fix Terminal Core references
echo "Fixing Terminal Core references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Core/Raxol.Terminal.TerminalCore/g' {} \;

# Fix Renderer references
echo "Fixing Renderer references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Renderer/Raxol.Terminal.TerminalRenderer/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.UI\.Renderer/Raxol.UI.UiRenderer/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.React\.Renderer/Raxol.React.ReactRenderer/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Svelte\.Renderer/Raxol.Svelte.SvelteRenderer/g' {} \;

# Fix Handler references
echo "Fixing Handler references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.ANSI\.CharacterSets\.Handler/Raxol.Terminal.ANSI.CharacterSets.CharacterSetsHandler/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.ANSI\.Handler/Raxol.Terminal.ANSI.EscapeHandler/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Commands\.Handler/Raxol.Terminal.Commands.OscHandler/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Mouse\.Handler/Raxol.Terminal.Mouse.MouseHandler/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Core\.Runtime\.Events\.Handler/Raxol.Core.Runtime.Events.EventsHandler/g' {} \;

# Fix Types references
echo "Fixing Types references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Input\.Types/Raxol.Terminal.Input.InputTypes/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Capabilities\.Types/Raxol.Terminal.Capabilities.CapabilitiesTypes/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Charset\.Types/Raxol.Terminal.Charset.CharsetTypes/g' {} \;
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Core\.Renderer\.View\.Types/Raxol.Core.Renderer.View.ViewTypes/g' {} \;

# Fix Validation references
echo "Fixing Validation references..."
find lib -name "*.ex" -exec sed -i '' 's/Raxol\.Terminal\.Validation/Raxol.Terminal.TerminalValidation/g' {} \;

echo ""
echo "All renamed module references have been updated!"
echo "================================================"
echo ""
echo "Next step: Run 'mix compile' to verify all references are fixed"