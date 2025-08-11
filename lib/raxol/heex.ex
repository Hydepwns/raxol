defmodule Raxol.HEEx do
  @moduledoc """
  HEEx template integration for Raxol.

  Allows using Phoenix HEEx templates directly in terminal applications,
  with terminal-specific components and styling.

  ## Example

      defmodule MyHEExApp do
        use Raxol.HEEx
        
        def render(assigns) do
          ~H\"\"\"
          <.terminal_box padding={2} border="single">
            <.terminal_text color="green" bold>
              Hello, <%= @name %>!
            </.terminal_text>
            
            <.terminal_button phx-click="click_me" class="primary">
              Click me!
            </.terminal_button>
          </.terminal_box>
          \"\"\"
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Phoenix.Component
      import Raxol.HEEx

      # Make terminal-specific components available
      import Raxol.HEEx.Components
    end
  end

  @doc """
  Compile HEEx templates for terminal rendering.

  This function takes standard HEEx templates and converts them
  to terminal buffer operations.
  """
  def compile_heex_for_terminal(template, _assigns) do
    # In a real implementation, this would:
    # 1. Parse the HEEx template
    # 2. Convert HTML-like elements to terminal buffer operations
    # 3. Handle terminal-specific attributes and styling

    # For now, return a placeholder since Phoenix.Component.render_string doesn't exist
    # TODO: Implement proper HEEx template compilation with assigns
    convert_html_to_terminal(template)
  end

  defp convert_html_to_terminal(html) do
    # Convert HTML to terminal sequences
    # This is a simplified version - real implementation would:
    # - Parse HTML tags
    # - Convert to ANSI escape sequences
    # - Handle terminal-specific layout

    html
    # Remove HTML tags for now
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
  end
end
