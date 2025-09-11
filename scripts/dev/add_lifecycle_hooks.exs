#!/usr/bin/env elixir

# Script to add missing lifecycle hooks to components

defmodule LifecycleAdder do
  @components_to_fix [
    "lib/raxol/ui/components/dashboard/dashboard.ex",
    "lib/raxol/ui/components/dashboard/widget_container.ex",
    "lib/raxol/ui/components/dashboard/widgets/info_widget.ex",
    "lib/raxol/ui/components/dashboard/widgets/text_input_widget.ex",
    "lib/raxol/ui/components/focus_ring.ex",
    "lib/raxol/ui/components/hint_display.ex",
    "lib/raxol/ui/components/input/single_line_input.ex",
    "lib/raxol/ui/components/markdown_renderer.ex",
    "lib/raxol/ui/components/modal.ex",
    "lib/raxol/ui/components/progress/component.ex",
    "lib/raxol/ui/components/progress/progress_bar.ex",
    "lib/raxol/ui/components/selection/dropdown.ex",
    "lib/raxol/ui/components/selection/list.ex",
    "lib/raxol/ui/components/terminal.ex"
  ]
  
  @lifecycle_hooks """
  
  @doc \"\"\"
  Mount hook - called when component is mounted.
  Returns the state and any commands to execute.
  \"\"\"
  @spec mount(map()) :: {map(), list()}
  def mount(state), do: {state, []}

  @doc \"\"\"
  Unmount hook - called when component is unmounted.
  Returns the final state.
  \"\"\"
  @spec unmount(map()) :: map()
  def unmount(state), do: state
  """
  
  def add_hooks do
    Enum.each(@components_to_fix, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        
        # Check if hooks already exist
        has_mount = String.contains?(content, "def mount(")
        has_unmount = String.contains?(content, "def unmount(")
        
        if !has_mount || !has_unmount do
          # Find the last function definition (likely handle_event)
          # and add the hooks after it
          new_content = if Regex.match?(~r/def handle_event.*?\n(?:\s+.*?\n)*?\s+end/s, content) do
            # Find the last handle_event function
            content
            |> String.replace(~r/(def handle_event.*?\n(?:\s+.*?\n)*?\s+end)(\nend\s*$)/s, 
                            "\\1#{@lifecycle_hooks}\\2")
          else
            # If no handle_event, add before the final 'end'
            String.replace(content, ~r/(\nend\s*)$/s, "#{@lifecycle_hooks}\\1")
          end
          
          File.write!(file, new_content)
          IO.puts("✓ Added hooks to #{Path.basename(file)}")
        else
          IO.puts("⚬ Skipped #{Path.basename(file)} (already has hooks)")
        end
      else
        IO.puts("✗ File not found: #{file}")
      end
    end)
  end
end

LifecycleAdder.add_hooks()