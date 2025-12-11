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
  def compile_heex_for_terminal(template, assigns) do
    # Basic HEEx template compilation for terminal rendering
    # 1. Parse the HEEx template for basic variable interpolation
    # 2. Convert HTML-like elements to terminal buffer operations
    # 3. Handle terminal-specific attributes and styling

    processed_template = interpolate_assigns(template, assigns)
    convert_html_to_terminal(processed_template)
  end

  # Basic template variable interpolation
  defp interpolate_assigns(template, assigns) do
    Enum.reduce(assigns, template, fn {key, value}, acc ->
      # Replace <%= @key %> patterns with actual values
      pattern = "<%= @#{key} %>"
      String.replace(acc, pattern, to_string(value))
    end)
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
