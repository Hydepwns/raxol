# Raxol Terminal v2.4.0 - API Reference

## Modules

- [:termbox2_nif](:termbox2_nif.md): Termbox2 NIF for Elixir - A terminal UI library.

- [Command.Manager](Command.Manager.md): Stub module for backward compatibility.

- [ElixirMake.Downloader](ElixirMake.Downloader.md): The behaviour for downloader modules.

- [ElixirMake.Precompiler](ElixirMake.Precompiler.md): The behaviour for precompiler modules.

- [Raxol.Terminal.ANSI](Raxol.Terminal.ANSI.md): This module serves as a documentation reference for the ANSI terminal functionality.
- [Raxol.Terminal.ANSI.Behaviours](Raxol.Terminal.ANSI.Behaviours.md): Consolidated ANSI behaviours for terminal functionality.
Consolidates: SixelGraphics.Behaviour, TerminalStateBehaviour, TextFormattingBehaviour.

- [Raxol.Terminal.ANSI.Behaviours.KittyGraphics](Raxol.Terminal.ANSI.Behaviours.KittyGraphics.md): Behaviour for Kitty graphics protocol support.
- [Raxol.Terminal.ANSI.Behaviours.SixelGraphics](Raxol.Terminal.ANSI.Behaviours.SixelGraphics.md): Behaviour for Sixel graphics support.

- [Raxol.Terminal.ANSI.Behaviours.TerminalState](Raxol.Terminal.ANSI.Behaviours.TerminalState.md): Behaviour for managing terminal state saving and restoring.

- [Raxol.Terminal.ANSI.Behaviours.TextFormatting](Raxol.Terminal.ANSI.Behaviours.TextFormatting.md): Defines the behaviour for text formatting in the terminal.
This includes handling text attributes, colors, and special text modes.

- [Raxol.Terminal.ANSI.Benchmark](Raxol.Terminal.ANSI.Benchmark.md): Provides benchmarking capabilities for the ANSI handling system.
Measures performance of parsing and processing ANSI sequences.

- [Raxol.Terminal.ANSI.CachedParser](Raxol.Terminal.ANSI.CachedParser.md): Optimized ANSI parser with caching for common sequences.
- [Raxol.Terminal.ANSI.CharacterSets](Raxol.Terminal.ANSI.CharacterSets.md): Consolidated character set management for the terminal emulator.
Combines: Handler, StateManager, Translator, and core CharacterSets functionality.
Supports G0, G1, G2, G3 character sets and their switching operations.
- [Raxol.Terminal.ANSI.CharacterSets.ASCII](Raxol.Terminal.ANSI.CharacterSets.ASCII.md): US ASCII character set identifier.

- [Raxol.Terminal.ANSI.CharacterSets.CharsetData](Raxol.Terminal.ANSI.CharacterSets.CharsetData.md): Translation maps for all supported character sets.
- [Raxol.Terminal.ANSI.CharacterSets.DEC](Raxol.Terminal.ANSI.CharacterSets.DEC.md): DEC Special Graphics character set identifier.

- [Raxol.Terminal.ANSI.CharacterSets.Handler](Raxol.Terminal.ANSI.CharacterSets.Handler.md): Handles character set control sequences and state changes.

- [Raxol.Terminal.ANSI.CharacterSets.StateManager](Raxol.Terminal.ANSI.CharacterSets.StateManager.md): Manages character set state and operations.

- [Raxol.Terminal.ANSI.CharacterSets.Translator](Raxol.Terminal.ANSI.CharacterSets.Translator.md): Handles character set translations and mappings.
Delegates per-charset data lookups to CharsetData.

- [Raxol.Terminal.ANSI.CharacterSets.UK](Raxol.Terminal.ANSI.CharacterSets.UK.md): UK character set identifier.

- [Raxol.Terminal.ANSI.CharacterTranslations](Raxol.Terminal.ANSI.CharacterTranslations.md): Provides character translation tables for different character sets.
Maps characters between different character sets according to ANSI standards.

- [Raxol.Terminal.ANSI.DeviceStatus](Raxol.Terminal.ANSI.DeviceStatus.md): Handles terminal state queries and device status reports.
This includes cursor position reports, device status reports,
and terminal identification queries.

- [Raxol.Terminal.ANSI.ExtendedSequences](Raxol.Terminal.ANSI.ExtendedSequences.md): Handles extended ANSI sequences and provides improved integration with the screen buffer.
Functional Programming Version - All try/catch blocks replaced with with statements.
- [Raxol.Terminal.ANSI.InputParser](Raxol.Terminal.ANSI.InputParser.md): Parses raw ANSI terminal input bytes into Raxol Event structs.
- [Raxol.Terminal.ANSI.KittyAnimation](Raxol.Terminal.ANSI.KittyAnimation.md): Animation support for the Kitty graphics protocol.
- [Raxol.Terminal.ANSI.KittyGraphics](Raxol.Terminal.ANSI.KittyGraphics.md): Complete Kitty graphics protocol support for terminal rendering.
- [Raxol.Terminal.ANSI.KittyParser](Raxol.Terminal.ANSI.KittyParser.md): Handles the parsing logic for Kitty graphics protocol sequences.
- [Raxol.Terminal.ANSI.KittyParser.ParserState](Raxol.Terminal.ANSI.KittyParser.ParserState.md): Represents the state during parsing of a Kitty graphics data stream.
Tracks control parameters, chunked data, and image buffers.

- [Raxol.Terminal.ANSI.Monitor](Raxol.Terminal.ANSI.Monitor.md): Provides monitoring capabilities for the ANSI handling system.
Tracks performance metrics, errors, and sequence statistics.

- [Raxol.Terminal.ANSI.Mouse](Raxol.Terminal.ANSI.Mouse.md): Consolidated mouse handling for the terminal emulator.
Combines MouseEvents and MouseTracking functionality.
Supports various mouse tracking modes and event reporting.

- [Raxol.Terminal.ANSI.Mouse.Events](Raxol.Terminal.ANSI.Mouse.Events.md): Handles mouse event reporting for the terminal emulator.

- [Raxol.Terminal.ANSI.Mouse.Tracking](Raxol.Terminal.ANSI.Mouse.Tracking.md): Handles mouse tracking and focus tracking for the terminal.

- [Raxol.Terminal.ANSI.Parser](Raxol.Terminal.ANSI.Parser.md): ANSI escape sequence parser for terminal emulation.
- [Raxol.Terminal.ANSI.PngDecoder](Raxol.Terminal.ANSI.PngDecoder.md): Pure Elixir PNG decoder using `:zlib`.
- [Raxol.Terminal.ANSI.SGR](Raxol.Terminal.ANSI.SGR.md): Consolidated SGR (Select Graphic Rendition) handling for ANSI escape sequences.
Combines: SGR formatting, SGRHandler, and SGRProcessor functionality.

- [Raxol.Terminal.ANSI.SGR.Formatter](Raxol.Terminal.ANSI.SGR.Formatter.md): SGR parameter formatting for the Raxol Terminal ANSI TextFormatting module.
Handles SGR parameter parsing, formatting, and attribute handling.

- [Raxol.Terminal.ANSI.SGR.Handler](Raxol.Terminal.ANSI.SGR.Handler.md): Handles parsing of SGR (Select Graphic Rendition) ANSI escape sequences.
Translates SGR codes into updates on a TextFormatting style map.

- [Raxol.Terminal.ANSI.SGR.Processor](Raxol.Terminal.ANSI.SGR.Processor.md): Optimized SGR (Select Graphic Rendition) processor for ANSI escape sequences.
Uses compile-time optimizations and pattern matching for maximum performance.

- [Raxol.Terminal.ANSI.SGRProcessor](Raxol.Terminal.ANSI.SGRProcessor.md): Processes SGR (Select Graphic Rendition) ANSI escape sequences.
- [Raxol.Terminal.ANSI.SequenceHandler](Raxol.Terminal.ANSI.SequenceHandler.md): Handles parsing and processing of ANSI escape sequences.
This module extracts the ANSI sequence parsing logic from the main emulator.

- [Raxol.Terminal.ANSI.Sequences.Colors](Raxol.Terminal.ANSI.Sequences.Colors.md): ANSI Color Sequence Handler.
- [Raxol.Terminal.ANSI.Sequences.Cursor](Raxol.Terminal.ANSI.Sequences.Cursor.md): ANSI Cursor Sequence Handler.
- [Raxol.Terminal.ANSI.Sequences.Modes](Raxol.Terminal.ANSI.Sequences.Modes.md): ANSI Terminal Modes Sequence Handler.
- [Raxol.Terminal.ANSI.SixelDithering](Raxol.Terminal.ANSI.SixelDithering.md): Dithering algorithms for Sixel image color quantization.
- [Raxol.Terminal.ANSI.SixelGraphics](Raxol.Terminal.ANSI.SixelGraphics.md): Complete Sixel graphics support for terminal rendering.
- [Raxol.Terminal.ANSI.SixelPalette](Raxol.Terminal.ANSI.SixelPalette.md): Handles Sixel color palette management.
- [Raxol.Terminal.ANSI.SixelParser](Raxol.Terminal.ANSI.SixelParser.md): Handles the parsing logic for Sixel graphics data streams within a DCS sequence.

- [Raxol.Terminal.ANSI.SixelParser.ParserState](Raxol.Terminal.ANSI.SixelParser.ParserState.md): Represents the state during the parsing of a Sixel graphics data stream.
Tracks position, color, palette, and pixel buffer information.

- [Raxol.Terminal.ANSI.SixelRenderer](Raxol.Terminal.ANSI.SixelRenderer.md): Handles rendering Sixel graphics data from a pixel buffer.

- [Raxol.Terminal.ANSI.StateMachine](Raxol.Terminal.ANSI.StateMachine.md): A state machine for parsing ANSI escape sequences.
This module provides a more efficient alternative to regex-based parsing.

- [Raxol.Terminal.ANSI.TerminalState](Raxol.Terminal.ANSI.TerminalState.md): Manages terminal state operations for ANSI escape sequences.

- [Raxol.Terminal.ANSI.TextFormatting](Raxol.Terminal.ANSI.TextFormatting.md): Consolidated text formatting module for the terminal emulator.
Combines Core, Attributes, and Colors functionality.
Handles advanced text formatting features including double-width/height,
text attributes, and color management.

- [Raxol.Terminal.ANSI.TextFormatting.Attributes](Raxol.Terminal.ANSI.TextFormatting.Attributes.md): Text attribute handling for ANSI text formatting.

- [Raxol.Terminal.ANSI.TextFormatting.Colors](Raxol.Terminal.ANSI.TextFormatting.Colors.md): Color handling utilities for ANSI text formatting.

- [Raxol.Terminal.ANSI.TextFormatting.Core](Raxol.Terminal.ANSI.TextFormatting.Core.md): Core text formatting functionality.

- [Raxol.Terminal.ANSI.TextFormatting.SGR](Raxol.Terminal.ANSI.TextFormatting.SGR.md): SGR parameter formatting and parsing for text styles.

- [Raxol.Terminal.ANSI.Utils](Raxol.Terminal.ANSI.Utils.md): Consolidated ANSI utilities for terminal functionality.
Combines: SixelPatternMap, AnsiProcessor, SequenceParser, AnsiParser, and Emitter.

- [Raxol.Terminal.ANSI.Utils.AnsiParser](Raxol.Terminal.ANSI.Utils.AnsiParser.md): Provides comprehensive parsing for ANSI escape sequences.
Determines the type of sequence and extracts its parameters.

- [Raxol.Terminal.ANSI.Utils.AnsiProcessor](Raxol.Terminal.ANSI.Utils.AnsiProcessor.md): Processes ANSI escape sequences for terminal control.

- [Raxol.Terminal.ANSI.Utils.Emitter](Raxol.Terminal.ANSI.Utils.Emitter.md): ANSI escape sequence generation module.
- [Raxol.Terminal.ANSI.Utils.SequenceParser](Raxol.Terminal.ANSI.Utils.SequenceParser.md): Helper module for parsing ANSI escape sequences.
- [Raxol.Terminal.ANSI.Utils.SixelPatternMap](Raxol.Terminal.ANSI.Utils.SixelPatternMap.md): Provides a mapping from Sixel characters to their 6-bit pixel patterns.

- [Raxol.Terminal.ANSI.Window](Raxol.Terminal.ANSI.Window.md): Consolidated window handling for the terminal emulator.
Combines WindowEvents and WindowManipulation functionality.
Supports window events, resizing, positioning, and state management.

- [Raxol.Terminal.ANSI.Window.Events](Raxol.Terminal.ANSI.Window.Events.md): Handles window events for terminal control.

- [Raxol.Terminal.ANSI.Window.Manipulation](Raxol.Terminal.ANSI.Window.Manipulation.md): Handles window manipulation sequences for terminal control.

- [Raxol.Terminal.AdvancedFeatures](Raxol.Terminal.AdvancedFeatures.md): Implements advanced terminal features for modern terminal emulators.
- [Raxol.Terminal.Buffer](Raxol.Terminal.Buffer.md): Manages the terminal buffer state and operations.

- [Raxol.Terminal.Buffer.BufferManager](Raxol.Terminal.Buffer.BufferManager.md): Buffer manager for terminal operations.
- [Raxol.Terminal.Buffer.BufferServer](Raxol.Terminal.Buffer.BufferServer.md): Buffer server stub for test compatibility.
- [Raxol.Terminal.Buffer.Cell](Raxol.Terminal.Buffer.Cell.md): Manages terminal cell operations and attributes.

- [Raxol.Terminal.Buffer.CharEditor](Raxol.Terminal.Buffer.CharEditor.md): Manages terminal character editing operations.

- [Raxol.Terminal.Buffer.Charset](Raxol.Terminal.Buffer.Charset.md): Manages character set state and operations for the screen buffer.
This module handles character set designations, G-sets, and single shifts.

- [Raxol.Terminal.Buffer.ConcurrentBuffer](Raxol.Terminal.Buffer.ConcurrentBuffer.md): A thread-safe buffer implementation using GenServer for concurrent access.
Provides synchronous operations to ensure data integrity when multiple
processes are reading/writing to the buffer simultaneously.

- [Raxol.Terminal.Buffer.Content](Raxol.Terminal.Buffer.Content.md): Compatibility adapter for buffer content operations.
Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.

- [Raxol.Terminal.Buffer.Cursor](Raxol.Terminal.Buffer.Cursor.md): Manages cursor state and operations for the screen buffer.
This module handles cursor position, visibility, style, and blink state.

- [Raxol.Terminal.Buffer.DamageTracker](Raxol.Terminal.Buffer.DamageTracker.md): Tracks damage regions in a terminal buffer for efficient rendering.
Damage regions indicate areas that have changed and need to be redrawn.

- [Raxol.Terminal.Buffer.Eraser](Raxol.Terminal.Buffer.Eraser.md): Compatibility adapter for buffer erasing operations.
Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.

- [Raxol.Terminal.Buffer.Formatting](Raxol.Terminal.Buffer.Formatting.md): Manages text formatting state and operations for the screen buffer.
This module handles text attributes, colors, and style management.

- [Raxol.Terminal.Buffer.LineEditor](Raxol.Terminal.Buffer.LineEditor.md): Provides functionality for line editing operations in the terminal buffer.

- [Raxol.Terminal.Buffer.LineOperations](Raxol.Terminal.Buffer.LineOperations.md): Provides line-level operations for the screen buffer.
This module handles operations like inserting, deleting, and manipulating lines.

- [Raxol.Terminal.Buffer.LineOperations.CharOperations](Raxol.Terminal.Buffer.LineOperations.CharOperations.md): Character-level operations for buffer lines.
Handles character insertion, deletion, and manipulation within lines.

- [Raxol.Terminal.Buffer.LineOperations.Deletion](Raxol.Terminal.Buffer.LineOperations.Deletion.md): Line deletion operations for terminal buffers.
Handles deletion of single and multiple lines, with support for scroll regions.

- [Raxol.Terminal.Buffer.LineOperations.Insertion](Raxol.Terminal.Buffer.LineOperations.Insertion.md): Line insertion operations for terminal buffers.
Handles insertion of single and multiple lines with style support.

- [Raxol.Terminal.Buffer.LineOperations.Management](Raxol.Terminal.Buffer.LineOperations.Management.md): Line management operations for terminal buffers.
Handles line creation, retrieval, and manipulation.

- [Raxol.Terminal.Buffer.LineOperations.Utils](Raxol.Terminal.Buffer.LineOperations.Utils.md): Shared utility functions for line operations.
Extracted to eliminate code duplication between Deletion and Insertion modules.

- [Raxol.Terminal.Buffer.Operations](Raxol.Terminal.Buffer.Operations.md): Compatibility adapter for consolidated buffer operations.
Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.

- [Raxol.Terminal.Buffer.Paste](Raxol.Terminal.Buffer.Paste.md): Handles text pasting operations for terminal buffers.

- [Raxol.Terminal.Buffer.Queries](Raxol.Terminal.Buffer.Queries.md): Handles buffer state querying operations.
This module provides functions for querying the state of the screen buffer,
including dimensions, content, and selection state.

- [Raxol.Terminal.Buffer.SafeManager](Raxol.Terminal.Buffer.SafeManager.md): Safe buffer manager that handles buffer operations with error recovery.
- [Raxol.Terminal.Buffer.Scroll](Raxol.Terminal.Buffer.Scroll.md): Terminal scroll buffer module.
- [Raxol.Terminal.Buffer.ScrollRegion](Raxol.Terminal.Buffer.ScrollRegion.md): Handles scroll region operations for the screen buffer.
This module manages the scroll region boundaries and provides functions
for scrolling content within the defined region.
- [Raxol.Terminal.Buffer.Scrollback](Raxol.Terminal.Buffer.Scrollback.md): Handles scrollback buffer operations for the screen buffer.
This module manages the history of lines that have scrolled off the screen,
including adding, retrieving, and clearing scrollback content.

- [Raxol.Terminal.Buffer.Scroller](Raxol.Terminal.Buffer.Scroller.md): Handles scrolling operations for the terminal buffer.

- [Raxol.Terminal.Buffer.Selection](Raxol.Terminal.Buffer.Selection.md): Manages text selection operations for the terminal.
This module handles all selection-related operations including:
- Starting and updating selections
- Getting selected text
- Checking if positions are within selections
- Managing selection boundaries
- Extracting text from regions

- [Raxol.Terminal.Buffer.TextFormatting](Raxol.Terminal.Buffer.TextFormatting.md): Manages terminal text formatting operations.

- [Raxol.Terminal.Buffer.Writer](Raxol.Terminal.Buffer.Writer.md): Handles writing characters and strings to the Raxol.Terminal.ScreenBuffer.
Responsible for character width, bidirectional text segmentation, and cell creation.

- [Raxol.Terminal.Cache.EvictionHelpers](Raxol.Terminal.Cache.EvictionHelpers.md): Helper functions for cache eviction strategies.
Provides shared implementations for LRU, LFU, and FIFO eviction policies.

- [Raxol.Terminal.Cache.System](Raxol.Terminal.Cache.System.md): Unified caching system for the Raxol terminal emulator.
This module provides a centralized caching mechanism that consolidates all caching
operations across the terminal system, including:
- Buffer caching
- Animation caching
- Scroll caching
- Clipboard caching
- General purpose caching

- [Raxol.Terminal.Capabilities.Manager](Raxol.Terminal.Capabilities.Manager.md): Manages terminal capabilities including detection, negotiation, and caching.

- [Raxol.Terminal.Capabilities.Types](Raxol.Terminal.Capabilities.Types.md): Defines types and structures for terminal capabilities management.

- [Raxol.Terminal.Cell](Raxol.Terminal.Cell.md): Terminal character cell module.
- [Raxol.Terminal.CellCached](Raxol.Terminal.CellCached.md): Cached version of Cell operations for performance optimization.
- [Raxol.Terminal.CharacterHandling](Raxol.Terminal.CharacterHandling.md): Handles wide character and bidirectional text support for the terminal emulator.
- [Raxol.Terminal.CharacterSets](Raxol.Terminal.CharacterSets.md): Manages character sets for the terminal emulator.

- [Raxol.Terminal.Charset.Manager](Raxol.Terminal.Charset.Manager.md): Manages terminal character sets and encoding operations.

- [Raxol.Terminal.Charset.Maps](Raxol.Terminal.Charset.Maps.md): Provides character mapping functions for different character sets.

- [Raxol.Terminal.Charset.Operations](Raxol.Terminal.Charset.Operations.md): Provides operations for managing character sets and their state.

- [Raxol.Terminal.Charset.Types](Raxol.Terminal.Charset.Types.md): Defines types used across the charset modules.

- [Raxol.Terminal.CharsetManager](Raxol.Terminal.CharsetManager.md): Manages the terminal character sets.

- [Raxol.Terminal.Clipboard](Raxol.Terminal.Clipboard.md): Provides a high-level interface for clipboard operations.
- [Raxol.Terminal.Clipboard.Format](Raxol.Terminal.Clipboard.Format.md): Handles clipboard content formatting and filtering.

- [Raxol.Terminal.Clipboard.History](Raxol.Terminal.Clipboard.History.md): Manages clipboard history for the terminal.

- [Raxol.Terminal.Clipboard.Manager](Raxol.Terminal.Clipboard.Manager.md): Manages clipboard operations for the terminal, including copying and pasting text.

- [Raxol.Terminal.Clipboard.Store](Raxol.Terminal.Clipboard.Store.md): Manages clipboard content storage and retrieval.

- [Raxol.Terminal.Clipboard.Sync](Raxol.Terminal.Clipboard.Sync.md): Handles clipboard synchronization between different terminal instances.

- [Raxol.Terminal.ClipboardBehaviour](Raxol.Terminal.ClipboardBehaviour.md): Defines the behaviour for clipboard operations in the terminal.
- [Raxol.Terminal.Color.Manager](Raxol.Terminal.Color.Manager.md): Manages terminal colors and color operations.

- [Raxol.Terminal.Color.TrueColor](Raxol.Terminal.Color.TrueColor.md): True color (24-bit RGB) support for Raxol terminal applications.
- [Raxol.Terminal.Color.TrueColor.AnsiCodes](Raxol.Terminal.Color.TrueColor.AnsiCodes.md): Low-level ANSI color code helpers: 256-color and 16-color mapping,
hex string parsing, and hex formatting.

- [Raxol.Terminal.Color.TrueColor.Conversion](Raxol.Terminal.Color.TrueColor.Conversion.md): Color space math for TrueColor: RGB/HSL/HSV/XYZ/Lab conversions
and luminance calculations.

- [Raxol.Terminal.Color.TrueColor.Detection](Raxol.Terminal.Color.TrueColor.Detection.md): Terminal color capability detection via environment variables.

- [Raxol.Terminal.Color.TrueColor.Palette](Raxol.Terminal.Color.TrueColor.Palette.md): Named color constants and lookup for TrueColor.

- [Raxol.Terminal.Colors](Raxol.Terminal.Colors.md): Manages terminal colors and color-related operations.

- [Raxol.Terminal.Commands.CSIHandler](Raxol.Terminal.Commands.CSIHandler.md): Handlers for CSI (Control Sequence Introducer) commands.
This is a simplified version that delegates to the available handler modules.

- [Raxol.Terminal.Commands.CSIHandler.Cursor](Raxol.Terminal.Commands.CSIHandler.Cursor.md): Handles cursor-related CSI sequences.

- [Raxol.Terminal.Commands.CSIHandler.CursorMovementHandler](Raxol.Terminal.Commands.CSIHandler.CursorMovementHandler.md): Handles cursor movement operations for CSI sequences.
- [Raxol.Terminal.Commands.CSIHandler.ModeHandlers](Raxol.Terminal.Commands.CSIHandler.ModeHandlers.md): Handles CSI mode commands (Set Mode/Reset Mode).

- [Raxol.Terminal.Commands.CSIHandler.Screen](Raxol.Terminal.Commands.CSIHandler.Screen.md): Handles screen-related CSI sequences.

- [Raxol.Terminal.Commands.CSIHandler.ScreenHandlers](Raxol.Terminal.Commands.CSIHandler.ScreenHandlers.md): Screen handling utilities for CSI commands.

- [Raxol.Terminal.Commands.Command](Raxol.Terminal.Commands.Command.md): Defines the structure for terminal commands.

- [Raxol.Terminal.Commands.CommandServer](Raxol.Terminal.Commands.CommandServer.md): Unified command handler that consolidates all terminal command processing.
- [Raxol.Terminal.Commands.CommandsParser](Raxol.Terminal.Commands.CommandsParser.md): Handles parsing of command parameters in terminal sequences.
- [Raxol.Terminal.Commands.CursorHandler](Raxol.Terminal.Commands.CursorHandler.md): Handles cursor movement related CSI commands.
- [Raxol.Terminal.Commands.CursorUtils](Raxol.Terminal.Commands.CursorUtils.md): Shared utility functions for cursor handling commands.
Eliminates code duplication between CursorHandler and CSIHandler.

- [Raxol.Terminal.Commands.DeviceHandler](Raxol.Terminal.Commands.DeviceHandler.md): Handles device-specific terminal commands like Device Attributes (DA) and Device Status Report (DSR).
This module provides direct implementations.

- [Raxol.Terminal.Commands.Editor](Raxol.Terminal.Commands.Editor.md): Handles editor-related terminal commands.

- [Raxol.Terminal.Commands.EraseHandler](Raxol.Terminal.Commands.EraseHandler.md): Handles terminal erase commands like Erase in Display (ED) and Erase in Line (EL).
This module provides simple fallback implementations.

- [Raxol.Terminal.Commands.Manager](Raxol.Terminal.Commands.Manager.md): Manages terminal command processing and execution.
This module is responsible for handling command parsing, validation, and execution.

- [Raxol.Terminal.Commands.OSCHandler](Raxol.Terminal.Commands.OSCHandler.md): Consolidated OSC (Operating System Command) handler for terminal control sequences.
Combines all OSC handler functionality including window, clipboard, color, and selection operations.

- [Raxol.Terminal.Commands.OSCHandler.Clipboard](Raxol.Terminal.Commands.OSCHandler.Clipboard.md): Handles clipboard-related OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.Color](Raxol.Terminal.Commands.OSCHandler.Color.md): Handles color-related OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.ColorPalette](Raxol.Terminal.Commands.OSCHandler.ColorPalette.md): Handles color palette OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.ColorParser](Raxol.Terminal.Commands.OSCHandler.ColorParser.md): Parses color specifications from OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.FontParser](Raxol.Terminal.Commands.OSCHandler.FontParser.md): Parses font specifications from OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.HyperlinkParser](Raxol.Terminal.Commands.OSCHandler.HyperlinkParser.md): Parses hyperlink specifications from OSC 8 commands.

- [Raxol.Terminal.Commands.OSCHandler.Selection](Raxol.Terminal.Commands.OSCHandler.Selection.md): Handles selection-related OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.SelectionParser](Raxol.Terminal.Commands.OSCHandler.SelectionParser.md): Parses selection specifications from OSC commands.

- [Raxol.Terminal.Commands.OSCHandler.Window](Raxol.Terminal.Commands.OSCHandler.Window.md): Handles window-related OSC commands.

- [Raxol.Terminal.Commands.Processor](Raxol.Terminal.Commands.Processor.md): Handles command processing for the terminal emulator.
This module is responsible for parsing, validating, and executing terminal commands.

- [Raxol.Terminal.Commands.Screen](Raxol.Terminal.Commands.Screen.md): Handles screen manipulation commands in the terminal.
- [Raxol.Terminal.Commands.Scrolling](Raxol.Terminal.Commands.Scrolling.md): Handles scrolling operations for the terminal screen buffer.

- [Raxol.Terminal.Commands.WindowHandler](Raxol.Terminal.Commands.WindowHandler.md): Handles window-related commands and operations for the terminal.

- [Raxol.Terminal.Config](Raxol.Terminal.Config.md): Handles terminal settings and behavior, including:
- Terminal dimensions
- Color settings
- Input handling
- Terminal state management
- Configuration validation
- Configuration persistence

- [Raxol.Terminal.Config.AnimationCache](Raxol.Terminal.Config.AnimationCache.md): Manages caching for terminal animations using the unified caching system.

- [Raxol.Terminal.Config.Application](Raxol.Terminal.Config.Application.md): Terminal configuration application.
- [Raxol.Terminal.Config.Capabilities](Raxol.Terminal.Config.Capabilities.md): Terminal capability detection and management.
- [Raxol.Terminal.Config.ConfigValidator](Raxol.Terminal.Config.ConfigValidator.md): Validates terminal configuration settings.

- [Raxol.Terminal.Config.Defaults](Raxol.Terminal.Config.Defaults.md): Default terminal configuration values.
- [Raxol.Terminal.Config.EnvironmentAdapterBehaviour](Raxol.Terminal.Config.EnvironmentAdapterBehaviour.md): Defines the behaviour for terminal environment configuration.
- [Raxol.Terminal.Config.Manager](Raxol.Terminal.Config.Manager.md): Manages terminal configuration including settings, preferences, and environment variables.
This module is responsible for handling configuration operations and state.

- [Raxol.Terminal.Config.Persistence](Raxol.Terminal.Config.Persistence.md): Handles persistence and migration of terminal configurations.

- [Raxol.Terminal.Config.Profiles](Raxol.Terminal.Config.Profiles.md): Terminal configuration profile management.
- [Raxol.Terminal.Config.Schema](Raxol.Terminal.Config.Schema.md): Schema definitions for terminal configuration.
- [Raxol.Terminal.Config.Utils](Raxol.Terminal.Config.Utils.md): Utility functions for handling terminal configuration maps.

- [Raxol.Terminal.Config.Validation](Raxol.Terminal.Config.Validation.md): Validation logic for terminal configuration.
- [Raxol.Terminal.ControlCodes](Raxol.Terminal.ControlCodes.md): Handles C0 control codes and simple ESC sequences.
- [Raxol.Terminal.Cursor](Raxol.Terminal.Cursor.md): Provides cursor manipulation functions for the terminal emulator.
This module handles operations like moving the cursor, setting its visibility,
and managing cursor state.

- [Raxol.Terminal.Cursor.Callbacks](Raxol.Terminal.Cursor.Callbacks.md): Handles GenServer callbacks for the cursor manager.
Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.

- [Raxol.Terminal.Cursor.CursorState](Raxol.Terminal.Cursor.CursorState.md): Handles cursor state management operations for the terminal cursor.
Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.

- [Raxol.Terminal.Cursor.Manager](Raxol.Terminal.Cursor.Manager.md): Manages cursor state and operations in the terminal.
Handles cursor position, visibility, style, and blinking state.

- [Raxol.Terminal.Cursor.Movement](Raxol.Terminal.Cursor.Movement.md): Handles cursor movement operations for the terminal cursor.
Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.

- [Raxol.Terminal.Cursor.Style](Raxol.Terminal.Cursor.Style.md): Handles cursor style and visibility control for the terminal emulator.
- [Raxol.Terminal.Device.Status](Raxol.Terminal.Device.Status.md): Handles device status reporting and attributes for the terminal emulator.

- [Raxol.Terminal.Display.AsciiArt](Raxol.Terminal.Display.AsciiArt.md): ASCII art rendering system for the Raxol terminal emulator.
- [Raxol.Terminal.Driver](Raxol.Terminal.Driver.md): Handles raw terminal input/output and event generation.
- [Raxol.Terminal.Driver.Behaviour](Raxol.Terminal.Driver.Behaviour.md): Behaviour specification for terminal drivers.
- [Raxol.Terminal.Driver.Dispatch](Raxol.Terminal.Driver.Dispatch.md): Event dispatching helpers for Driver: sends events to the dispatcher
and handles initial resize notification.

- [Raxol.Terminal.Driver.EventTranslator](Raxol.Terminal.Driver.EventTranslator.md): Translates termbox NIF events into Raxol.Core.Events.Event structs.

- [Raxol.Terminal.Driver.InputBuffer](Raxol.Terminal.Driver.InputBuffer.md): Input buffer management for Driver: accumulates bytes, detects incomplete
escape sequences, and flushes complete sequences for parsing.

- [Raxol.Terminal.Driver.TermboxLifecycle](Raxol.Terminal.Driver.TermboxLifecycle.md): Termbox NIF initialization, shutdown, and recovery helpers.

- [Raxol.Terminal.Driver.TerminalSize](Raxol.Terminal.Driver.TerminalSize.md): Terminal size detection: termbox, stty, and fallback strategies.

- [Raxol.Terminal.Emulator](Raxol.Terminal.Emulator.md): Enterprise-grade terminal emulator with VT100/ANSI support and high-performance parsing.
- [Raxol.Terminal.Emulator.ANSIHandler](Raxol.Terminal.Emulator.ANSIHandler.md): Handles ANSI sequence processing for the terminal emulator.
- [Raxol.Terminal.Emulator.Adapter](Raxol.Terminal.Emulator.Adapter.md): Adapter module to make EmulatorLite compatible with existing code that
expects the full Emulator struct.
- [Raxol.Terminal.Emulator.Buffer](Raxol.Terminal.Emulator.Buffer.md): Provides buffer management functionality for the terminal emulator.

- [Raxol.Terminal.Emulator.BufferOperations](Raxol.Terminal.Emulator.BufferOperations.md): Buffer operation functions extracted from the main emulator module.
Handles active buffer management and buffer switching operations.

- [Raxol.Terminal.Emulator.CommandHandler](Raxol.Terminal.Emulator.CommandHandler.md): Handles CSI/ESC/SGR/OSC and related command logic for the terminal emulator.
Extracted from the main emulator module for clarity and maintainability.

- [Raxol.Terminal.Emulator.Constructors](Raxol.Terminal.Emulator.Constructors.md): Handles emulator constructor functions.
This module extracts the constructor logic from the main emulator.

- [Raxol.Terminal.Emulator.Coordinator](Raxol.Terminal.Emulator.Coordinator.md): Coordinates complex operations that require interaction between multiple
terminal subsystems. This module handles the orchestration logic that
was previously embedded in the main Emulator module.

- [Raxol.Terminal.Emulator.Core](Raxol.Terminal.Emulator.Core.md): Handles core emulator functionality including input processing and scrolling.
- [Raxol.Terminal.Emulator.CursorOperations](Raxol.Terminal.Emulator.CursorOperations.md): Cursor operation functions extracted from the main emulator module.
Handles cursor movement, positioning, and blink operations.

- [Raxol.Terminal.Emulator.Dimensions](Raxol.Terminal.Emulator.Dimensions.md): Dimension and resize operation functions extracted from the main emulator module.
Handles terminal resizing and dimension getters.

- [Raxol.Terminal.Emulator.EmulatorServer](Raxol.Terminal.Emulator.EmulatorServer.md): GenServer implementation for the Terminal Emulator.
- [Raxol.Terminal.Emulator.EmulatorState](Raxol.Terminal.Emulator.EmulatorState.md): Handles state management for the terminal emulator.
Provides functions for managing terminal state, modes, and character sets.

- [Raxol.Terminal.Emulator.Factory](Raxol.Terminal.Emulator.Factory.md): Emulator construction helpers: creates full (GenServer) and basic (struct-only) emulators.

- [Raxol.Terminal.Emulator.Helpers](Raxol.Terminal.Emulator.Helpers.md): Utility and helper functions for the terminal emulator.
Extracted from the main emulator module for clarity and reuse.

- [Raxol.Terminal.Emulator.Input](Raxol.Terminal.Emulator.Input.md): Handles input processing for the terminal emulator.
Provides functions for key event handling, command history, and input parsing.

- [Raxol.Terminal.Emulator.ModeOperations](Raxol.Terminal.Emulator.ModeOperations.md): Mode operation functions extracted from the main emulator module.
Handles terminal mode setting and resetting operations.

- [Raxol.Terminal.Emulator.OptimizedInputProcessor](Raxol.Terminal.Emulator.OptimizedInputProcessor.md): Optimized input processing for the terminal emulator.
- [Raxol.Terminal.Emulator.Output](Raxol.Terminal.Emulator.Output.md): Handles output processing for the terminal emulator.
Provides functions for output buffering, processing, and formatting.

- [Raxol.Terminal.Emulator.Reset](Raxol.Terminal.Emulator.Reset.md): Handles emulator reset and cleanup functions.
This module extracts the reset logic from the main emulator.

- [Raxol.Terminal.Emulator.SafeEmulator](Raxol.Terminal.Emulator.SafeEmulator.md): Enhanced terminal emulator with comprehensive error handling.
Refactored to use functional error handling patterns instead of try/catch.

- [Raxol.Terminal.Emulator.ScreenOperations](Raxol.Terminal.Emulator.ScreenOperations.md): Screen operation functions extracted from the main emulator module.
Handles screen clearing and line clearing operations.

- [Raxol.Terminal.Emulator.ScrollOperations](Raxol.Terminal.Emulator.ScrollOperations.md): Scroll operation functions extracted from the main emulator module.
Handles scroll region management and scroll positioning.

- [Raxol.Terminal.Emulator.Struct](Raxol.Terminal.Emulator.Struct.md): Provides terminal emulator structure and related functionality.

- [Raxol.Terminal.Emulator.Style](Raxol.Terminal.Emulator.Style.md): Handles text styling and formatting for the terminal emulator.
Provides functions for managing character attributes, colors, and text formatting.

- [Raxol.Terminal.Emulator.Style.Behaviour](Raxol.Terminal.Emulator.Style.Behaviour.md): Defines the behaviour for terminal emulator style management.
This includes handling text attributes, colors, and text formatting.

- [Raxol.Terminal.Emulator.Telemetry](Raxol.Terminal.Emulator.Telemetry.md): Telemetry instrumentation for the terminal emulator.
- [Raxol.Terminal.Emulator.TextOperations](Raxol.Terminal.Emulator.TextOperations.md): Text operation functions extracted from the main emulator module.
Handles text writing with charset translation and cursor updates.

- [Raxol.Terminal.EmulatorBehaviour](Raxol.Terminal.EmulatorBehaviour.md): Defines the behaviour for the core Terminal Emulator.
- [Raxol.Terminal.EmulatorFactory](Raxol.Terminal.EmulatorFactory.md): Factory module for creating terminal emulator instances.
This module is responsible for initializing and configuring new emulator instances.

- [Raxol.Terminal.EmulatorLite](Raxol.Terminal.EmulatorLite.md): Lightweight terminal emulator for performance-critical paths.
- [Raxol.Terminal.Escape.Parsers.BaseParser](Raxol.Terminal.Escape.Parsers.BaseParser.md): Base parser utilities for escape sequence parsers.
- [Raxol.Terminal.Escape.Parsers.CSIParser](Raxol.Terminal.Escape.Parsers.CSIParser.md): Parser for CSI (Control Sequence Introducer) escape sequences.
- [Raxol.Terminal.Escape.Parsers.CSIParserCached](Raxol.Terminal.Escape.Parsers.CSIParserCached.md): Cached version of CSI parser for performance optimization.
- [Raxol.Terminal.Escape.Parsers.SCSParser](Raxol.Terminal.Escape.Parsers.SCSParser.md): Parser for SCS (Select Character Set) escape sequences.
- [Raxol.Terminal.EscapeSequence](Raxol.Terminal.EscapeSequence.md): Handles parsing of ANSI escape sequences and other control sequences.
- [Raxol.Terminal.Event](Raxol.Terminal.Event.md): Defines the structure for terminal events.

- [Raxol.Terminal.Event.Handler](Raxol.Terminal.Event.Handler.md): Handles terminal events including input events, state changes, and notifications.
This module is responsible for processing and dispatching events to appropriate handlers.

- [Raxol.Terminal.EventHandler](Raxol.Terminal.EventHandler.md): Handles various terminal events including mouse, keyboard, and focus events.
This module is responsible for processing and responding to user interactions.

- [Raxol.Terminal.EventProcessor](Raxol.Terminal.EventProcessor.md): Optimized event processing pipeline for terminal events.
- [Raxol.Terminal.Events](Raxol.Terminal.Events.md): Global event management for terminal interactions.
- [Raxol.Terminal.Events.Handler](Raxol.Terminal.Events.Handler.md): Handles terminal events and dispatches them to appropriate handlers.

- [Raxol.Terminal.Extension.ExtensionManager](Raxol.Terminal.Extension.ExtensionManager.md): Manages terminal extensions, including loading, unloading, and executing extension commands.

- [Raxol.Terminal.Extension.ExtensionServer](Raxol.Terminal.Extension.ExtensionServer.md): Unified extension management GenServer that provides a single interface for loading,
unloading, and managing terminal extensions.

- [Raxol.Terminal.Font.Manager](Raxol.Terminal.Font.Manager.md): Manages font operations and settings for the terminal, including font family,
size, weight, and style.

- [Raxol.Terminal.Format](Raxol.Terminal.Format.md): Unified terminal text formatting and styling operations.
- [Raxol.Terminal.HistoryBuffer](Raxol.Terminal.HistoryBuffer.md): Manages terminal command history buffer operations.
This module handles the storage and retrieval of command history.

- [Raxol.Terminal.HistoryManager](Raxol.Terminal.HistoryManager.md): Manages terminal command history operations including history storage, retrieval, and navigation.
This module is responsible for handling all history-related operations in the terminal.

- [Raxol.Terminal.IO.IOServer](Raxol.Terminal.IO.IOServer.md): Unified input/output system for the terminal emulator.
- [Raxol.Terminal.IOTerminal](Raxol.Terminal.IOTerminal.md): Pure Elixir terminal I/O using OTP 28+ raw mode and IO.ANSI.
- [Raxol.Terminal.Image](Raxol.Terminal.Image.md): Unified facade for terminal inline image display.
- [Raxol.Terminal.ImageCache](Raxol.Terminal.ImageCache.md): ETS-backed cache for decoded and encoded terminal images.
- [Raxol.Terminal.Input](Raxol.Terminal.Input.md): Handles input processing for the terminal.

- [Raxol.Terminal.Input.Buffer](Raxol.Terminal.Input.Buffer.md): Manages input buffering for the terminal emulator.

- [Raxol.Terminal.Input.CharacterProcessor](Raxol.Terminal.Input.CharacterProcessor.md): Handles character processing, translation, and writing to the terminal buffer.

- [Raxol.Terminal.Input.ClipboardHandler](Raxol.Terminal.Input.ClipboardHandler.md): Handles clipboard operations for the terminal emulator.
- [Raxol.Terminal.Input.ControlSequenceHandler](Raxol.Terminal.Input.ControlSequenceHandler.md): Handles various control sequences for the terminal emulator.
Includes CSI, OSC, DCS, PM, and APC sequence handling.
- [Raxol.Terminal.Input.CoreHandler](Raxol.Terminal.Input.CoreHandler.md): Core input handling functionality for the terminal emulator.
Manages the main input buffer and cursor state.

- [Raxol.Terminal.Input.Event](Raxol.Terminal.Input.Event.md): Defines the base event struct and common types for input events.

- [Raxol.Terminal.Input.Event.KeyEvent](Raxol.Terminal.Input.Event.KeyEvent.md): Represents a keyboard input event.

- [Raxol.Terminal.Input.Event.MouseEvent](Raxol.Terminal.Input.Event.MouseEvent.md): Represents a mouse input event.

- [Raxol.Terminal.Input.FileDropHandler](Raxol.Terminal.Input.FileDropHandler.md): Handles file drag-and-drop operations for the terminal emulator.
- [Raxol.Terminal.Input.InputBuffer](Raxol.Terminal.Input.InputBuffer.md): A simple data structure for managing input buffer state.
- [Raxol.Terminal.Input.InputBufferUtils](Raxol.Terminal.Input.InputBufferUtils.md): Utility functions for Raxol.Terminal.Input.InputBuffer.

- [Raxol.Terminal.Input.InputHandler](Raxol.Terminal.Input.InputHandler.md): Handles input processing for the terminal emulator.
- [Raxol.Terminal.Input.InputProcessor](Raxol.Terminal.Input.InputProcessor.md): Processes input events for the terminal emulator.

- [Raxol.Terminal.Input.Manager](Raxol.Terminal.Input.Manager.md): Manages terminal input processing including character input, key events, and input mode handling.
This module is responsible for processing all input events and converting them into appropriate
terminal actions.

- [Raxol.Terminal.Input.MouseHandler](Raxol.Terminal.Input.MouseHandler.md): Comprehensive mouse event handling for terminal applications.
- [Raxol.Terminal.Input.SpecialKeys](Raxol.Terminal.Input.SpecialKeys.md): Handles special key combinations and their escape sequences.
- [Raxol.Terminal.Input.TextProcessor](Raxol.Terminal.Input.TextProcessor.md): Handles text input processing for the terminal emulator.
This module extracts the text input handling logic from the main emulator.

- [Raxol.Terminal.Input.Types](Raxol.Terminal.Input.Types.md): Defines shared types for the Raxol terminal input subsystem.

- [Raxol.Terminal.InputHandler](Raxol.Terminal.InputHandler.md): Main input handler module that coordinates between different input handling components.

- [Raxol.Terminal.Integration](Raxol.Terminal.Integration.md): Coordinates terminal integration components and provides a unified interface
for terminal operations.
- [Raxol.Terminal.Integration.Buffer](Raxol.Terminal.Integration.Buffer.md): Handles buffer and cursor management for the terminal.

- [Raxol.Terminal.Integration.CellRenderer](Raxol.Terminal.Integration.CellRenderer.md): Renders a list of cells to the terminal.

- [Raxol.Terminal.Integration.Config](Raxol.Terminal.Integration.Config.md): Manages configuration for the terminal integration.

- [Raxol.Terminal.Integration.Main](Raxol.Terminal.Integration.Main.md): Main integration module that provides a GenServer-based interface for terminal integration.

- [Raxol.Terminal.Integration.Renderer](Raxol.Terminal.Integration.Renderer.md): Handles terminal output rendering and display management using Termbox2.

- [Raxol.Terminal.Integration.State](Raxol.Terminal.Integration.State.md): Manages the state of the integrated terminal system.

- [Raxol.Terminal.MemoryManager](Raxol.Terminal.MemoryManager.md): Manages memory usage and limits for the terminal emulator.

- [Raxol.Terminal.Metrics.MetricsServer](Raxol.Terminal.Metrics.MetricsServer.md): ETS-backed metrics collection and export module.
- [Raxol.Terminal.ModeHandler](Raxol.Terminal.ModeHandler.md): Handles terminal mode management functions.
This module extracts the mode handling logic from the main emulator.

- [Raxol.Terminal.ModeManager](Raxol.Terminal.ModeManager.md): Manages terminal modes (DEC Private Modes, Standard Modes) and their effects.
- [Raxol.Terminal.ModeManager.SavedState](Raxol.Terminal.ModeManager.SavedState.md): Handles saved state operations for the mode manager.
This includes saving and restoring cursor positions, screen states, and other terminal modes.

- [Raxol.Terminal.ModeState](Raxol.Terminal.ModeState.md): Manages terminal mode state and transitions.
- [Raxol.Terminal.Modes](Raxol.Terminal.Modes.md): Handles terminal modes and state transitions for the terminal emulator.
- [Raxol.Terminal.Modes.Handlers.DECPrivateHandler](Raxol.Terminal.Modes.Handlers.DECPrivateHandler.md): Handles DEC Private mode operations and their side effects.
Manages the implementation of DEC private mode changes and their effects on the terminal.

- [Raxol.Terminal.Modes.Handlers.MouseHandler](Raxol.Terminal.Modes.Handlers.MouseHandler.md): Handles mouse mode operations and their side effects.
Manages different mouse reporting modes and their effects on the terminal.

- [Raxol.Terminal.Modes.Handlers.ScreenBufferHandler](Raxol.Terminal.Modes.Handlers.ScreenBufferHandler.md): Handles screen buffer mode operations and their side effects.
Manages alternate screen buffer switching and related functionality.

- [Raxol.Terminal.Modes.Handlers.StandardHandler](Raxol.Terminal.Modes.Handlers.StandardHandler.md): Handles standard mode operations and their side effects.
Manages standard terminal modes like insert mode and line feed mode.

- [Raxol.Terminal.Modes.Types.ModeTypes](Raxol.Terminal.Modes.Types.ModeTypes.md): Defines types and constants for terminal modes.
Provides a centralized registry of all terminal modes and their properties.

- [Raxol.Terminal.Mouse.Manager](Raxol.Terminal.Mouse.Manager.md): Manages mouse events and tracking in the terminal, including button clicks,
movement, and wheel events.

- [Raxol.Terminal.Mouse.MouseServer](Raxol.Terminal.Mouse.MouseServer.md): Provides unified mouse handling functionality for the terminal emulator.
This module handles mouse events, tracking, and state management.

- [Raxol.Terminal.Operations.CursorOperations](Raxol.Terminal.Operations.CursorOperations.md): Implements cursor-related operations for the terminal emulator.

- [Raxol.Terminal.Operations.ScreenOperations](Raxol.Terminal.Operations.ScreenOperations.md): Implements screen-related operations for the terminal emulator.

- [Raxol.Terminal.Operations.ScrollOperations](Raxol.Terminal.Operations.ScrollOperations.md): Implements scroll-related operations for the terminal emulator.

- [Raxol.Terminal.Operations.SelectionOperations](Raxol.Terminal.Operations.SelectionOperations.md): Implements selection-related operations for the terminal emulator.

- [Raxol.Terminal.Operations.StateOperations](Raxol.Terminal.Operations.StateOperations.md): Implements state-related operations for the terminal emulator.

- [Raxol.Terminal.Operations.TextOperations](Raxol.Terminal.Operations.TextOperations.md): Implements text-related operations for the terminal emulator.

- [Raxol.Terminal.OperationsBehaviour](Raxol.Terminal.OperationsBehaviour.md): Defines the behaviour for core terminal operations.
- [Raxol.Terminal.Output.Manager](Raxol.Terminal.Output.Manager.md): Manages terminal output buffering, event processing, styling, and formatting.
This module handles output events, applies styles and formatting rules, and tracks metrics.

- [Raxol.Terminal.Output.OutputProcessor](Raxol.Terminal.Output.OutputProcessor.md): Processes output events for the terminal emulator.

- [Raxol.Terminal.OutputBuffer](Raxol.Terminal.OutputBuffer.md): Simple output buffer implementation for terminal output.

- [Raxol.Terminal.OutputManager](Raxol.Terminal.OutputManager.md): Manages terminal output operations including writing, flushing, and output buffering.
This module is responsible for handling all output-related operations in the terminal.

- [Raxol.Terminal.Parser.ParserState](Raxol.Terminal.Parser.ParserState.md): Parser state for the terminal emulator.

- [Raxol.Terminal.Parser.State.Manager](Raxol.Terminal.Parser.State.Manager.md): Manages the state of the terminal parser, including escape sequences,
control sequences, and parser modes.

- [Raxol.Terminal.Parser.State.ManagerRefactored](Raxol.Terminal.Parser.State.ManagerRefactored.md): Refactored version of Terminal Parser State Manager using pattern matching
instead of cond statements.
- [Raxol.Terminal.Parser.StateBehaviour](Raxol.Terminal.Parser.StateBehaviour.md): Defines the behaviour for parser states.

- [Raxol.Terminal.Parser.StateManagerBehaviour](Raxol.Terminal.Parser.StateManagerBehaviour.md): Behaviour for terminal parser state management.

- [Raxol.Terminal.Parser.States.CSIEntryState](Raxol.Terminal.Parser.States.CSIEntryState.md): Handles the CSI Entry state in the terminal parser.
This state is entered after receiving an ESC [ sequence.

- [Raxol.Terminal.Parser.States.CSIIntermediateState](Raxol.Terminal.Parser.States.CSIIntermediateState.md): Handles the :csi_intermediate state of the terminal parser.

- [Raxol.Terminal.Parser.States.CSIParamState](Raxol.Terminal.Parser.States.CSIParamState.md): Handles the :csi_param state of the terminal parser.

- [Raxol.Terminal.Parser.States.DCSEntryState](Raxol.Terminal.Parser.States.DCSEntryState.md): Handles the :dcs_entry state of the terminal parser.

- [Raxol.Terminal.Parser.States.DCSPassthroughMaybeSTState](Raxol.Terminal.Parser.States.DCSPassthroughMaybeSTState.md): Handles the :dcs_passthrough_maybe_st state of the terminal parser.

- [Raxol.Terminal.Parser.States.DCSPassthroughState](Raxol.Terminal.Parser.States.DCSPassthroughState.md): Handles the :dcs_passthrough state of the terminal parser.

- [Raxol.Terminal.Parser.States.DesignateCharsetState](Raxol.Terminal.Parser.States.DesignateCharsetState.md): Handles the :designate_charset state of the terminal parser.

- [Raxol.Terminal.Parser.States.EscapeState](Raxol.Terminal.Parser.States.EscapeState.md): Handles the :escape state of the terminal parser.

- [Raxol.Terminal.Parser.States.GroundState](Raxol.Terminal.Parser.States.GroundState.md): Handles parsing in the ground state, the default state of the terminal.

- [Raxol.Terminal.Parser.States.OSCStringMaybeSTState](Raxol.Terminal.Parser.States.OSCStringMaybeSTState.md): Handles the :osc_string_maybe_st state of the terminal parser.

- [Raxol.Terminal.Parser.States.OSCStringState](Raxol.Terminal.Parser.States.OSCStringState.md): Handles the OSC String state in the terminal parser.
This state is entered when an OSC sequence is initiated.

- [Raxol.Terminal.ParserState](Raxol.Terminal.ParserState.md): Alias module for parser state functionality.
This module delegates to the actual implementation in Parser.ParserState.

- [Raxol.Terminal.ParserStateManager](Raxol.Terminal.ParserStateManager.md): Consolidated terminal parser state manager combining simple emulator operations with
comprehensive parser state management.
- [Raxol.Terminal.Plugin.DependencyResolver](Raxol.Terminal.Plugin.DependencyResolver.md): Handles plugin dependency resolution for the terminal emulator.
This module extracts the plugin dependency resolution logic from the main emulator.

- [Raxol.Terminal.Plugin.Manager](Raxol.Terminal.Plugin.Manager.md): Manages terminal plugins with advanced features:
- Plugin loading and unloading
- Plugin lifecycle management
- Plugin API and hooks
- Plugin configuration and state management

- [Raxol.Terminal.Plugin.PluginServer](Raxol.Terminal.Plugin.PluginServer.md): Unified plugin system for the Raxol terminal emulator.
Handles themes, scripting, and extensions.
- [Raxol.Terminal.Registry](Raxol.Terminal.Registry.md): Registry for terminal processes and components.
- [Raxol.Terminal.Renderer](Raxol.Terminal.Renderer.md): Terminal renderer module.
- [Raxol.Terminal.Rendering.Backend](Raxol.Terminal.Rendering.Backend.md): Behaviour definition for terminal rendering backends.
- [Raxol.Terminal.Rendering.CachedStyleRenderer](Raxol.Terminal.Rendering.CachedStyleRenderer.md): High-performance terminal renderer with style string caching.
- [Raxol.Terminal.Rendering.GPUAccelerator](Raxol.Terminal.Rendering.GPUAccelerator.md): GPU-accelerated rendering backend for Raxol terminals using Metal (macOS) and Vulkan.
- [Raxol.Terminal.Rendering.GPURenderer](Raxol.Terminal.Rendering.GPURenderer.md): GPU-accelerated terminal renderer.
- [Raxol.Terminal.Rendering.LigatureRenderer](Raxol.Terminal.Rendering.LigatureRenderer.md): Programming font ligature rendering system for Raxol terminals.
- [Raxol.Terminal.Rendering.OptimizedStyleRenderer](Raxol.Terminal.Rendering.OptimizedStyleRenderer.md): Phase 3 optimized terminal renderer with efficient style handling.
- [Raxol.Terminal.Rendering.RenderServer](Raxol.Terminal.Rendering.RenderServer.md): Provides a unified interface for terminal rendering operations.

- [Raxol.Terminal.Screen](Raxol.Terminal.Screen.md): Provides screen manipulation functions for the terminal emulator.
- [Raxol.Terminal.ScreenBuffer](Raxol.Terminal.ScreenBuffer.md): Manages the terminal's screen buffer state (grid, scrollback, selection).
This module serves as the main interface for terminal buffer operations,
delegating specific operations to specialized modules in Raxol.Terminal.Buffer.*.
- [Raxol.Terminal.ScreenBuffer.Attributes](Raxol.Terminal.ScreenBuffer.Attributes.md): Manages buffer attributes including formatting, charset, and cursor state.
Consolidates: Formatting, TextFormatting, Charset, Cursor functionality.

- [Raxol.Terminal.ScreenBuffer.BehaviourImpl](Raxol.Terminal.ScreenBuffer.BehaviourImpl.md): Implements behaviour callbacks for the terminal screen buffer.
- [Raxol.Terminal.ScreenBuffer.Charset](Raxol.Terminal.ScreenBuffer.Charset.md): Handles character set operations for the screen buffer.

- [Raxol.Terminal.ScreenBuffer.Core](Raxol.Terminal.ScreenBuffer.Core.md): Core functionality for screen buffer creation, initialization, and basic queries.
Consolidates: Initializer, Common, Helpers, and basic state management.

- [Raxol.Terminal.ScreenBuffer.DataAdapter](Raxol.Terminal.ScreenBuffer.DataAdapter.md): Data structure adapter for ScreenBuffer operations.
- [Raxol.Terminal.ScreenBuffer.EraseOperations](Raxol.Terminal.ScreenBuffer.EraseOperations.md): Handles all erase operations for the terminal screen buffer.
- [Raxol.Terminal.ScreenBuffer.Manager](Raxol.Terminal.ScreenBuffer.Manager.md): Manages buffer lifecycle, memory tracking, damage regions, and buffer switching.
Consolidates: Manager, UnifiedManager, SafeManager, EnhancedManager, DamageTracker.

- [Raxol.Terminal.ScreenBuffer.MemoryUtils](Raxol.Terminal.ScreenBuffer.MemoryUtils.md): Handles memory usage calculations for the terminal screen buffer.
- [Raxol.Terminal.ScreenBuffer.Operations](Raxol.Terminal.ScreenBuffer.Operations.md): All buffer mutation operations.
Consolidates: Operations, Ops, OperationsCached, Writer, Updater, CharEditor,
LineOperations, Eraser, Content, Paste functionality.

- [Raxol.Terminal.ScreenBuffer.Operations.Erasing](Raxol.Terminal.ScreenBuffer.Operations.Erasing.md): Erasing operations for the screen buffer.
- [Raxol.Terminal.ScreenBuffer.RegionOperations](Raxol.Terminal.ScreenBuffer.RegionOperations.md): Handles region operations for the terminal screen buffer.
- [Raxol.Terminal.ScreenBuffer.Screen](Raxol.Terminal.ScreenBuffer.Screen.md): Handles screen buffer operations for the terminal emulator.
This module provides functions for managing the screen state, including
clearing, erasing, and marking damaged regions.

- [Raxol.Terminal.ScreenBuffer.ScrollOps](Raxol.Terminal.ScreenBuffer.ScrollOps.md): Scroll operations for ScreenBuffer: region management and scroll up/down.

- [Raxol.Terminal.ScreenBuffer.ScrollRegion](Raxol.Terminal.ScreenBuffer.ScrollRegion.md): Manages scroll region boundaries for the screen buffer.

- [Raxol.Terminal.ScreenBuffer.Selection](Raxol.Terminal.ScreenBuffer.Selection.md): Text selection operations for the screen buffer.
Handles selection creation, updates, text extraction, and clipboard operations.

- [Raxol.Terminal.ScreenBuffer.SharedOperations](Raxol.Terminal.ScreenBuffer.SharedOperations.md): Shared operations for screen buffer modules to eliminate code duplication.
This module contains common functionality used across different screen buffer implementations.

- [Raxol.Terminal.ScreenBufferAdapter](Raxol.Terminal.ScreenBufferAdapter.md): Backward-compatible adapter that maps the old ScreenBuffer API to the new consolidated modules.
This allows existing code to work without changes while we migrate to the consolidated architecture.

- [Raxol.Terminal.ScreenBufferBehaviour](Raxol.Terminal.ScreenBufferBehaviour.md): Defines the behaviour for screen buffer operations in the terminal.
This module specifies the callbacks that must be implemented by any module
that wants to act as a screen buffer.

- [Raxol.Terminal.ScreenManager](Raxol.Terminal.ScreenManager.md): Manages screen buffer operations for the terminal emulator.
This module handles operations related to the main and alternate screen buffers,
including buffer switching, initialization, and state management.

- [Raxol.Terminal.ScreenUpdater](Raxol.Terminal.ScreenUpdater.md): Handles screen update operations for the terminal.
- [Raxol.Terminal.Script.ScriptServer](Raxol.Terminal.Script.ScriptServer.md): Unified scripting system for the Raxol terminal emulator.
Handles script execution, management, and integration with the terminal.
- [Raxol.Terminal.Scroll.Manager](Raxol.Terminal.Scroll.Manager.md): Manages terminal scrolling operations with advanced features.
- [Raxol.Terminal.Scroll.Optimizer](Raxol.Terminal.Scroll.Optimizer.md): Handles scroll optimization for better performance.
Dynamically adjusts batch size based on recent scroll patterns and (optionally) performance metrics.

- [Raxol.Terminal.Scroll.PatternAnalyzer](Raxol.Terminal.Scroll.PatternAnalyzer.md): Shared utilities for analyzing scroll patterns.

- [Raxol.Terminal.Scroll.Predictor](Raxol.Terminal.Scroll.Predictor.md): Handles predictive scrolling operations for the terminal.
Tracks recent scrolls and provides pattern analysis for smarter prediction.

- [Raxol.Terminal.Scroll.ScrollServer](Raxol.Terminal.Scroll.ScrollServer.md): Unified scroll management system for the terminal.
- [Raxol.Terminal.Scroll.Sync](Raxol.Terminal.Scroll.Sync.md): Handles scroll synchronization across terminal splits.
Tracks recent sync events for analytics and smarter sync strategies.

- [Raxol.Terminal.Scrollback.Manager](Raxol.Terminal.Scrollback.Manager.md): Manages terminal scrollback buffer operations.

- [Raxol.Terminal.SearchBuffer](Raxol.Terminal.SearchBuffer.md): Manages search state, options, matches, and history for terminal search operations.

- [Raxol.Terminal.SearchManager](Raxol.Terminal.SearchManager.md): Manages terminal search operations including text search, pattern matching, and search history.
This module is responsible for handling all search-related operations in the terminal.

- [Raxol.Terminal.Selection.Manager](Raxol.Terminal.Selection.Manager.md): Manages text selection operations in the terminal.

- [Raxol.Terminal.Session](Raxol.Terminal.Session.md): Terminal session module.
- [Raxol.Terminal.Session.Serializer](Raxol.Terminal.Session.Serializer.md): Handles serialization and deserialization of terminal session state.
- [Raxol.Terminal.Session.Storage](Raxol.Terminal.Session.Storage.md): Handles persistence of terminal sessions.

- [Raxol.Terminal.SessionManager](Raxol.Terminal.SessionManager.md): Terminal multiplexing system providing tmux-like session management for Raxol.
- [Raxol.Terminal.SessionManager.Cleanup](Raxol.Terminal.SessionManager.Cleanup.md): Session cleanup: expired session removal and resource monitoring.

- [Raxol.Terminal.SessionManager.Client](Raxol.Terminal.SessionManager.Client.md): Client connection to a session.
- [Raxol.Terminal.SessionManager.Helpers](Raxol.Terminal.SessionManager.Helpers.md): Helper functions for SessionManager operations.
- [Raxol.Terminal.SessionManager.Pane](Raxol.Terminal.SessionManager.Pane.md): Terminal pane within a window.
- [Raxol.Terminal.SessionManager.Persistence](Raxol.Terminal.SessionManager.Persistence.md): Session persistence: save/restore sessions to/from disk.

- [Raxol.Terminal.SessionManager.Session](Raxol.Terminal.SessionManager.Session.md): Terminal session structure.
- [Raxol.Terminal.SessionManager.StateQueries](Raxol.Terminal.SessionManager.StateQueries.md): State query helpers for SessionManager: finding panes/windows and building summaries.

- [Raxol.Terminal.SessionManager.Window](Raxol.Terminal.SessionManager.Window.md): Terminal window within a session.
- [Raxol.Terminal.SessionManager.WindowFactory](Raxol.Terminal.SessionManager.WindowFactory.md): Window and pane creation helpers for SessionManager.

- [Raxol.Terminal.Split.SplitManager](Raxol.Terminal.Split.SplitManager.md): Manages terminal split windows and panes.
- [Raxol.Terminal.State](Raxol.Terminal.State.md): Provides state management for the terminal emulator.
This module handles operations like creating new states, saving and restoring states,
and managing state transitions.

- [Raxol.Terminal.State.Manager](Raxol.Terminal.State.Manager.md): State manager for terminal emulator state.
Provides functions for managing modes, attributes, and state stack.
- [Raxol.Terminal.StateManager](Raxol.Terminal.StateManager.md): Manages terminal state transitions and state stack operations.
This module is responsible for maintaining and manipulating the terminal's state.
- [Raxol.Terminal.Style.Manager](Raxol.Terminal.Style.Manager.md): Manages text styling and formatting for the terminal emulator.
This module provides a clean interface for managing text styles, colors, and attributes.

- [Raxol.Terminal.Style.StyleProcessor](Raxol.Terminal.Style.StyleProcessor.md): Handles style management for the terminal emulator.
This module extracts the style handling logic from the main emulator.

- [Raxol.Terminal.StyleBuffer](Raxol.Terminal.StyleBuffer.md): Manages terminal style state and operations.
This module handles text attributes, colors, and formatting for terminal output.

- [Raxol.Terminal.StyleManager](Raxol.Terminal.StyleManager.md): Manages terminal style operations including colors, attributes, and formatting.
This module is responsible for handling all style-related operations in the terminal.

- [Raxol.Terminal.Supervisor](Raxol.Terminal.Supervisor.md): Supervisor for terminal-related processes.

- [Raxol.Terminal.Sync.Component](Raxol.Terminal.Sync.Component.md): Defines the structure for synchronized components.

- [Raxol.Terminal.Sync.Manager](Raxol.Terminal.Sync.Manager.md): Manages synchronization between different terminal components (splits, windows, tabs).
Provides a high-level interface for component synchronization and state management.

- [Raxol.Terminal.Sync.Protocol](Raxol.Terminal.Sync.Protocol.md): Defines the synchronization protocol for terminal components.
Handles message formats, versioning, and conflict resolution strategies.

- [Raxol.Terminal.Sync.SyncServer](Raxol.Terminal.Sync.SyncServer.md): Unified synchronization system for the Raxol terminal emulator.
This module provides centralized synchronization mechanisms for:
- State synchronization between windows
- Event synchronization
- Resource synchronization

- [Raxol.Terminal.Sync.System](Raxol.Terminal.Sync.System.md): Unified synchronization system for the terminal emulator.
Handles synchronization between splits, windows, and tabs with different consistency levels.

- [Raxol.Terminal.Tab.Manager](Raxol.Terminal.Tab.Manager.md): Manages terminal tabs and their associated sessions.
This module handles:
- Creation, deletion, and switching of terminal tabs
- Tab state and configuration management
- Tab stop management for terminal operations

- [Raxol.Terminal.Tab.TabServer](Raxol.Terminal.Tab.TabServer.md): Provides unified tab management functionality for the terminal emulator.
This module handles tab creation, switching, state management, and configuration.

- [Raxol.Terminal.Tab.WindowIntegration](Raxol.Terminal.Tab.WindowIntegration.md): Integration module for managing tabs and their associated windows.

- [Raxol.Terminal.TelemetryLogger](Raxol.Terminal.TelemetryLogger.md): Logs all Raxol.Terminal telemetry events for observability and debugging.
- [Raxol.Terminal.TerminalParser](Raxol.Terminal.TerminalParser.md): Parses raw byte streams into terminal events and commands.
Handles escape sequences (CSI, OSC, DCS, etc.) and plain text.

- [Raxol.Terminal.TerminalUtils](Raxol.Terminal.TerminalUtils.md): Utility functions for terminal operations, providing cross-platform and
consistent handling of terminal capabilities and dimensions.

- [Raxol.Terminal.TextFormatting](Raxol.Terminal.TextFormatting.md): Alias module for Raxol.Terminal.ANSI.TextFormatting.
This module re-exports the functionality from ANSI.TextFormatting to maintain compatibility.

- [Raxol.Terminal.Theme.Manager](Raxol.Terminal.Theme.Manager.md): Manages terminal themes with advanced features:
- Theme loading from files and presets
- Theme customization and modification
- Dynamic theme switching
- Theme persistence and state management
- [Raxol.Terminal.Theme.ThemeServer](Raxol.Terminal.Theme.ThemeServer.md): Unified theme system for the Raxol terminal emulator.
Handles theme management, preview, switching, and customization.

- [Raxol.Terminal.Tooltip](Raxol.Terminal.Tooltip.md): Tooltip display functionality for terminal UI.
- [Raxol.Terminal.Unicode](Raxol.Terminal.Unicode.md): Unicode handling utilities for terminal rendering.
- [Raxol.Terminal.Validation](Raxol.Terminal.Validation.md): Stub module for terminal input validation.
- [Raxol.Terminal.Window](Raxol.Terminal.Window.md): Represents a terminal window with its properties and state.
- [Raxol.Terminal.Window.Manager](Raxol.Terminal.Window.Manager.md): Refactored Window.Manager that delegates to GenServer implementation.
- [Raxol.Terminal.Window.Manager.NavigationOps](Raxol.Terminal.Window.Manager.NavigationOps.md): Pure-functional helpers for spatial navigation and position registration
within the WindowManagerServer state.

- [Raxol.Terminal.Window.Manager.Operations](Raxol.Terminal.Window.Manager.Operations.md): Operations module for window management functionality.
Handles all the complex logic for window creation, updates, and hierarchy management.

- [Raxol.Terminal.Window.Manager.StateOps](Raxol.Terminal.Window.Manager.StateOps.md): Pure functional state operations for the WindowManagerServer.
- [Raxol.Terminal.Window.Manager.WindowManagerServer](Raxol.Terminal.Window.Manager.WindowManagerServer.md): GenServer implementation for terminal window management in Raxol.
- [Raxol.Terminal.Window.Registry](Raxol.Terminal.Window.Registry.md): Registry for managing multiple terminal windows.

- [Raxol.Terminal.Window.WindowServer](Raxol.Terminal.Window.WindowServer.md): A unified window manager for terminal applications.
- [RaxolTerminal](RaxolTerminal.md): Terminal emulation and rendering for Elixir.

## Mix Tasks

- [mix compile.elixir_make](Mix.Tasks.Compile.ElixirMake.md): Runs `make` in the current project.
- [mix elixir_make.checksum](Mix.Tasks.ElixirMake.Checksum.md): A task responsible for downloading the precompiled NIFs for a given module.
- [mix elixir_make.precompile](Mix.Tasks.ElixirMake.Precompile.md): Precompiles the given project for all targets.

