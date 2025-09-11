#!/usr/bin/env elixir

# Script to check which components are missing lifecycle hooks

defmodule LifecycleChecker do
  @required_hooks [:init, :mount, :update, :render, :handle_event, :unmount]
  
  def check_components do
    component_files = Path.wildcard("lib/raxol/ui/components/**/*.ex")
    |> Enum.reject(&String.contains?(&1, "/base/"))
    |> Enum.reject(&String.contains?(&1, "_test.ex"))
    
    results = Enum.map(component_files, fn file ->
      content = File.read!(file)
      
      # Check if it's actually a component (uses Component behaviour)
      if String.contains?(content, "use Raxol.UI.Components.Base.Component") ||
         String.contains?(content, "@behaviour Raxol.UI.Components.Base.Component") do
        
        implemented_hooks = @required_hooks
        |> Enum.filter(fn hook ->
          # Check for def hook_name( pattern
          Regex.match?(~r/def #{hook}\s*\(/, content)
        end)
        
        missing_hooks = @required_hooks -- implemented_hooks
        
        {file, implemented_hooks, missing_hooks}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    # Print results
    IO.puts("=== Component Lifecycle Hook Analysis ===\n")
    
    # Components with missing hooks
    components_with_missing = Enum.filter(results, fn {_, _, missing} -> 
      length(missing) > 0 
    end)
    
    if length(components_with_missing) > 0 do
      IO.puts("Components with missing hooks:")
      Enum.each(components_with_missing, fn {file, implemented, missing} ->
        component_name = Path.basename(file, ".ex")
        IO.puts("\n  #{component_name}:")
        IO.puts("    Implemented: #{inspect(implemented)}")
        IO.puts("    Missing: #{inspect(missing)}")
      end)
    else
      IO.puts("All components have all lifecycle hooks implemented!")
    end
    
    IO.puts("\n=== Summary ===")
    IO.puts("Total components: #{length(results)}")
    IO.puts("Complete: #{length(results) - length(components_with_missing)}")
    IO.puts("Incomplete: #{length(components_with_missing)}")
  end
end

LifecycleChecker.check_components()