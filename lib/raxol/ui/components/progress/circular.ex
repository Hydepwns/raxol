defmodule Raxol.UI.Components.Progress.Circular do
  @moduledoc """
  Handles circular progress components.
  """

  require Raxol.View.Elements

  @spec render_circular(map()) :: any()
  def render_circular(state) do
    # Based on original circular logic - complex, needs state + drawing
    Raxol.View.Elements.label(
      content: "( O )",
      id: Map.get(state, :id, nil),
      style: state.style
    )
  end

  @spec circular(float(), keyword()) :: any()
  @doc """
  Renders a circular progress indicator.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `opts` - Options for customizing the progress indicator

  ## Options

  * `:id` - Unique identifier for the indicator (default: "circular_progress")
  * `:style` - Style for the indicator
  * `:show_percentage` - Whether to show percentage inside (default: true)
  * `:percentage_style` - Style for the percentage text

  ## Returns

  A view element representing the circular progress indicator.

  ## Example

  ```elixir
  Progress.Circular.circular(
    0.65,
    style: %{fg: :green}
  )
  ```
  """
  def circular(value, opts \\ []) do
    # Ensure value is within bounds
    value = max(0.0, min(1.0, value))

    # Extract options with defaults
    id = Keyword.get(opts, :id, "circular_progress")
    style = Keyword.get(opts, :style, %{fg: :blue})
    show_percentage = Keyword.get(opts, :show_percentage, true)
    percentage_style = Keyword.get(opts, :percentage_style, %{})

    # Calculate which character to show based on progress
    # Using quarter block characters to represent progress
    # ◴◵◶◷ or ◐◓◑◒ or ◔◕●○
    chars = ["○", "◔", "◑", "◕", "●"]
    char_index = round(value * (length(chars) - 1))
    progress_char = Enum.at(chars, char_index)

    # Generate percentage text
    percentage_text =
      if show_percentage do
        "#{round(value * 100)}%"
      else
        ""
      end

    # Create the circular progress indicator
    Raxol.View.Elements.row([id: id],
      do: fn ->
        # Create progress char element
        char_element =
          Raxol.View.Elements.label(content: progress_char, style: style)

        # Create percentage element if needed
        elements = [char_element]

        elements =
          if show_percentage do
            percentage_element =
              Raxol.View.Elements.label(
                content: percentage_text,
                style: percentage_style
              )

            elements ++ [percentage_element]
          else
            elements
          end

        # Return the elements
        elements
      end
    )
  end
end
