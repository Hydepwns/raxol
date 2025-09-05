defmodule Raxol.UI.Components.Progress.Bar do
  @moduledoc """
  Handles bar progress components.
  """

  require Raxol.View.Elements

  @spec render_bar(map()) :: any()
  def render_bar(state) do
    # Based on original bar/bar_with_label logic
    percentage = state.value / state.max
    filled_width = round(state.width * percentage)
    empty_width = state.width - filled_width

    bar_content =
      String.duplicate("█", filled_width) <> String.duplicate("░", empty_width)

    content = [
      Raxol.View.Elements.label(content: bar_content)
    ]

    content =
      case state.label do
        nil -> content
        label -> [Raxol.View.Elements.label(content: label) | content]
      end

    # Use row or column based on desired layout
    Raxol.View.Elements.row id: Map.get(state, :id, nil), style: state.style do
      content
    end
  end

  @spec bar_with_label(float(), String.t(), keyword()) :: any()
  @doc """
  Renders a progress bar with a label and optional percentage display.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `label` - Text label to display
  * `opts` - Options for customizing the progress bar

  ## Options

  All options from `bar/2` plus:
  * `:show_percentage` - Whether to show percentage (default: true)
  * `:percentage_style` - Style for the percentage text (default: %{})
  * `:label_style` - Style for the label text (default: %{})
  * `:position` - Position of the label/percentage (:above, :below, :right, default: :above)

  ## Returns

  A view element representing the progress bar with label.

  ## Example

  ```elixir
  Progress.Bar.bar_with_label(
    0.35,
    "Loading assets...",
    show_percentage: true,
    position: :below,
    filled_style: %{bg: :cyan}
  )
  ```
  """
  def bar_with_label(value, label, opts \\ []) do
    # Extract additional options
    show_percentage = Keyword.get(opts, :show_percentage, true)
    percentage_style = Keyword.get(opts, :percentage_style, %{})
    label_style = Keyword.get(opts, :label_style, %{})
    position = Keyword.get(opts, :position, :above)
    id = Keyword.get(opts, :id, "progress_bar_with_label")

    # Generate percentage text
    percentage_text =
      case show_percentage do
        true -> "#{round(value * 100)}%"
        false -> nil
      end

    # Create the progress bar with label based on position
    case position do
      :above ->
        render_above_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      :below ->
        render_below_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      :right ->
        render_right_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      _ ->
        render_above_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )
    end
  end

  @spec bar(float(), keyword()) :: any()
  @doc """
  Renders a simple progress bar with configurable appearance.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `opts` - Options for customizing the progress bar

  ## Options

  * `:id` - Unique identifier for the progress bar (default: "progress_bar")
  * `:width` - Width of the progress bar in characters (default: 20)
  * `:style` - Style for the progress bar container
  * `:filled_style` - Style for the filled portion of the bar (default: %{bg: :blue})
  * `:empty_style` - Style for the empty portion of the bar (default: %{bg: :black})
  * `:chars` - Characters to use for different parts of the bar
    * `:filled` - Character for filled sections (default: " ")
    * `:empty` - Character for empty sections (default: " ")

  ## Returns

  A view element representing the progress bar.

  ## Example

  ```elixir
  Progress.Bar.bar(
    0.75,
    width: 30,
    filled_style: %{bg: :green},
    chars: %{filled: "█", empty: "░"}
  )
  ```
  """
  def bar(value, opts \\ []) do
    # Ensure value is within bounds
    value = max(0.0, min(1.0, value))

    # Extract options with defaults
    id = Keyword.get(opts, :id, "progress_bar")
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style, %{})
    filled_style = Keyword.get(opts, :filled_style, %{bg: :blue})
    empty_style = Keyword.get(opts, :empty_style, %{bg: :black})

    chars = Keyword.get(opts, :chars, %{})
    filled_char = Map.get(chars, :filled, " ")
    empty_char = Map.get(chars, :empty, " ")

    # Calculate filled and empty widths
    filled_width = round(value * width)
    empty_width = width - filled_width

    # Generate filled and empty portions
    filled_portion = String.duplicate(filled_char, filled_width)
    empty_portion = String.duplicate(empty_char, empty_width)

    # Create the progress bar
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        create_bar_elements(
          filled_width,
          filled_portion,
          filled_style,
          empty_width,
          empty_portion,
          empty_style
        )
      end
    )
  end

  # Helper functions
  defp render_above_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    Raxol.View.Elements.column id: id do
      [
        Raxol.View.Elements.row style: %{justify: :space_between} do
          render_label_and_percentage(
            label,
            label_style,
            percentage_text,
            percentage_style
          )
        end,
        bar(value, opts)
      ]
    end
  end

  defp render_below_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    Raxol.View.Elements.column id: id do
      [
        bar(value, opts),
        Raxol.View.Elements.row style: %{justify: :space_between} do
          render_label_and_percentage(
            label,
            label_style,
            percentage_text,
            percentage_style
          )
        end
      ]
    end
  end

  defp render_right_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    adjusted_width =
      Keyword.get(opts, :width, 20) -
        String.length(label) -
        case percentage_text do
          nil -> 0
          text -> String.length(text) + 1
        end

    Raxol.View.Elements.row id: id do
      [
        bar(value, Keyword.put(opts, :width, adjusted_width)),
        Raxol.View.Elements.label(content: " #{label}", style: label_style),
        case percentage_text do
          nil ->
            nil

          text ->
            Raxol.View.Elements.label(
              content: " #{text}",
              style: percentage_style
            )
        end
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  defp render_label_and_percentage(
         label,
         label_style,
         percentage_text,
         percentage_style
       ) do
    label_text = Raxol.View.Elements.label(content: label, style: label_style)

    percentage_element =
      case percentage_text do
        nil ->
          nil

        text ->
          Raxol.View.Elements.label(
            content: text,
            style: percentage_style
          )
      end

    elements = [label_text]

    case percentage_element do
      nil -> elements
      element -> elements ++ [element]
    end
  end

  defp create_bar_elements(
         filled_width,
         filled_portion,
         filled_style,
         empty_width,
         empty_portion,
         empty_style
       ) do
    elements = []

    elements =
      case filled_width do
        w when w > 0 ->
          filled_text =
            Raxol.View.Elements.label(
              content: filled_portion,
              style: filled_style
            )

          [filled_text | elements]

        _ ->
          elements
      end

    elements =
      case empty_width do
        w when w > 0 ->
          empty_text =
            Raxol.View.Elements.label(
              content: empty_portion,
              style: empty_style
            )

          [empty_text | elements]

        _ ->
          elements
      end

    # Return elements in correct order (reverse accumulation)
    Enum.reverse(elements)
  end
end
