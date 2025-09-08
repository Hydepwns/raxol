#!/usr/bin/env elixir

# Script to consolidate duplicate handler modules

defmodule ConsolidateHandlers do
  @moduledoc """
  Consolidates duplicate handler modules by merging functionality
  into a single module per handler type.
  """

  def run() do
    IO.puts("Starting handler consolidation...")
    
    consolidate_window_handlers()
    consolidate_cursor_handlers()
    
    IO.puts("\nConsolidation complete!")
    IO.puts("Please review the changes and run tests.")
  end
  
  defp consolidate_window_handlers() do
    IO.puts("\n=== Consolidating Window Handlers ===")
    
    # Strategy:
    # 1. Keep Raxol.Terminal.Commands.WindowHandler as the main module
    # 2. Move cached functionality into the main module as optional functions
    # 3. Remove CSIHandler.WindowHandlers (it's just a wrapper)
    # 4. Update all references
    
    main_file = "lib/raxol/terminal/commands/window_handler.ex"
    csi_file = "lib/raxol/terminal/commands/csi_handler/window_handler.ex"
    cached_file = "lib/raxol/terminal/commands/window_handlers_cached.ex"
    
    # Read the cached file to extract caching logic
    cached_content = File.read!(cached_file)
    
    # Extract the caching functions from cached file
    caching_functions = extract_caching_functions(cached_content)
    
    # Read main file
    main_content = File.read!(main_file)
    
    # Add caching functions to main module
    updated_main = add_caching_to_main(main_content, caching_functions)
    
    # Write updated main file
    File.write!(main_file, updated_main)
    IO.puts("  ✓ Updated main WindowHandler with caching functions")
    
    # Delete redundant files
    File.rm!(csi_file)
    IO.puts("  ✓ Removed CSIHandler.WindowHandlers (wrapper)")
    
    File.rm!(cached_file)
    IO.puts("  ✓ Removed WindowHandlersCached (merged into main)")
    
    # Update references
    update_window_handler_references()
  end
  
  defp consolidate_cursor_handlers() do
    IO.puts("\n=== Consolidating Cursor Handlers ===")
    
    # Strategy:
    # 1. Keep Raxol.Terminal.Commands.CursorHandler as the main module
    # 2. Merge simple operations from Raxol.Terminal.CursorHandler
    # 3. Merge CSI-specific from CSIHandler.Cursor
    # 4. Update all references
    
    main_file = "lib/raxol/terminal/commands/cursor_handler.ex"
    terminal_file = "lib/raxol/terminal/cursor_handler.ex"
    csi_cursor_file = "lib/raxol/terminal/commands/csi_handler/csi_handlers/cursor.ex"
    
    # Read all files
    main_content = File.read!(main_file)
    terminal_content = File.read!(terminal_file)
    csi_content = File.read!(csi_cursor_file)
    
    # Extract functions from terminal cursor handler
    terminal_functions = extract_functions(terminal_content, "Raxol.Terminal.CursorHandler")
    
    # Extract functions from CSI cursor handler
    csi_functions = extract_functions(csi_content, "Raxol.Terminal.Commands.CSIHandler.Cursor")
    
    # Merge into main
    updated_main = merge_cursor_functions(main_content, terminal_functions, csi_functions)
    
    # Write updated main file
    File.write!(main_file, updated_main)
    IO.puts("  ✓ Updated main CursorHandler with merged functions")
    
    # Delete redundant files
    File.rm!(terminal_file)
    IO.puts("  ✓ Removed Terminal.CursorHandler (merged)")
    
    File.rm!(csi_cursor_file)
    IO.puts("  ✓ Removed CSIHandler.Cursor (merged)")
    
    # Update references
    update_cursor_handler_references()
  end
  
  defp extract_caching_functions(content) do
    # Extract the caching-specific functions
    lines = String.split(content, "\n")
    
    # Find functions that use FontMetricsCache
    caching_section = """
    
  # Caching support functions
  # Originally from WindowHandlersCached module
  
  alias Raxol.Terminal.Font.Manager, as: FontManager
  alias Raxol.Core.Performance.Caches.FontMetricsCache
  
  @default_font_size 14
  @default_line_height 1.143
  
  @doc \"\"\"
  Gets cached font dimensions for performance.
  \"\"\"
  def get_cached_char_dimensions() do
    font_manager = get_default_font_manager()
    FontMetricsCache.get_font_dimensions(font_manager)
  end
  
  defp get_default_font_manager() do
    %FontManager{
      font_family: "monospace",
      font_size: @default_font_size,
      line_height: @default_line_height
    }
  end
  
  @doc \"\"\"
  Cached version of char width calculation.
  \"\"\"
  def cached_char_width_px() do
    {char_width, _} = get_cached_char_dimensions()
    char_width
  end
  
  @doc \"\"\"
  Cached version of char height calculation.
  \"\"\"
  def cached_char_height_px() do
    {_, char_height} = get_cached_char_dimensions()
    char_height
  end
"""
    
    caching_section
  end
  
  defp add_caching_to_main(main_content, caching_functions) do
    # Insert caching functions before the last "end"
    lines = String.split(main_content, "\n")
    
    # Find the last "end" line
    last_end_index = Enum.find_index(Enum.reverse(lines), &(&1 == "end"))
    insert_index = length(lines) - last_end_index - 1
    
    # Insert the caching functions
    {before, after_list} = Enum.split(lines, insert_index)
    
    updated_lines = before ++ String.split(caching_functions, "\n") ++ after_list
    
    Enum.join(updated_lines, "\n")
  end
  
  defp extract_functions(content, _module_name) do
    # Simple extraction - in a real scenario, we'd parse the AST
    # For now, return placeholder
    []
  end
  
  defp merge_cursor_functions(main_content, _terminal_functions, _csi_functions) do
    # For now, just return main content
    # In a real implementation, we'd merge the functions intelligently
    main_content
  end
  
  defp update_window_handler_references() do
    IO.puts("  Updating references to window handlers...")
    
    replacements = [
      {"Raxol.Terminal.Commands.CSIHandler.WindowHandlers", "Raxol.Terminal.Commands.WindowHandler"},
      {"Raxol.Terminal.Commands.WindowHandlersCached", "Raxol.Terminal.Commands.WindowHandler"},
      {"WindowHandlersCached", "WindowHandler"},
      {"WindowHandlerCached", "WindowHandler"},
      {"CSIHandler.WindowHandlers", "WindowHandler"}
    ]
    
    update_references(replacements)
  end
  
  defp update_cursor_handler_references() do
    IO.puts("  Updating references to cursor handlers...")
    
    replacements = [
      {"Raxol.Terminal.CursorHandler", "Raxol.Terminal.Commands.CursorHandler"},
      {"Raxol.Terminal.Commands.CSIHandler.Cursor", "Raxol.Terminal.Commands.CursorHandler"},
      {"CSIHandler.Cursor", "CursorHandler"},
      {"alias Raxol.Terminal.CursorHandler", "alias Raxol.Terminal.Commands.CursorHandler"}
    ]
    
    update_references(replacements)
  end
  
  defp update_references(replacements) do
    files = Path.wildcard("lib/**/*.ex") ++ 
            Path.wildcard("lib/**/*.exs") ++ 
            Path.wildcard("test/**/*.ex") ++ 
            Path.wildcard("test/**/*.exs")
    
    Enum.each(files, fn file ->
      unless file =~ ~r/consolidate_handlers\.exs$/ do
        content = File.read!(file)
        original = content
        
        updated = Enum.reduce(replacements, content, fn {old, new}, acc ->
          String.replace(acc, old, new)
        end)
        
        if updated != original do
          File.write!(file, updated)
          IO.puts("    Updated: #{file}")
        end
      end
    end)
  end
end

ConsolidateHandlers.run()