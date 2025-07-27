defmodule Raxol.View.Components do
  @moduledoc """
  Provides component functions for Raxol views.

  This module contains functions for creating various UI components
  that can be used in Raxol views.
  """

  @doc """
  Creates a text component with options for content, style, foreground, and background colors.

  ## Options
  - `:content` - The text content to display
  - `:style` - Style options for the text (font, size, etc.)
  - `:fg` - Foreground color
  - `:bg` - Background color

  ## Example
      text("Hello World", style: [bold: true], fg: :blue)
  """
  def text(content, opts \\ []) do
    %{
      type: :text,
      content: content,
      attrs: ensure_style(ensure_id(opts)),
      position: Keyword.get(opts, :position, {0, 0}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  @doc """
  Creates a button component with options for label, click action, style, and disabled state.

  ## Options
  - `:label` - The button text
  - `:on_click` - Function to call when clicked
  - `:style` - Style options for the button
  - `:disabled` - Whether the button is disabled

  ## Example
      button("Submit", on_click: &handle_submit/0, style: [bg: :blue])
  """
  def button(label, opts \\ []) do
    %{
      type: :button,
      label: label,
      attrs: ensure_style(ensure_id(opts)),
      position: Keyword.get(opts, :position, {0, 0}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  @doc """
  Creates a text input component with options for value, placeholder, change action, and style.

  ## Options
  - `:value` - Current input value
  - `:placeholder` - Placeholder text
  - `:on_change` - Function to call when value changes
  - `:style` - Style options for the input

  ## Example
      text_input(value: name, placeholder: "Enter your name", on_change: &handle_name_change/1)
  """
  def text_input(opts \\ []) do
    %{
      type: :text_input,
      attrs: ensure_style(ensure_id(opts)),
      position: Keyword.get(opts, :position, {0, 0}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  @doc """
  Creates a space component with options for width and height.

  ## Options
  - `:width` - Width of the space in characters
  - `:height` - Height of the space in lines
  - `:style` - Style options for the space

  ## Example
      space(width: 2)
      space(width: 1, height: 2)
  """
  def space(opts \\ []) do
    %{
      type: :spacer,
      attrs: ensure_style(ensure_id(opts)),
      position: Keyword.get(opts, :position, {0, 0}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  @doc """
  Creates a label component with options for text, width, and style.

  ## Options
  - `:width` - Width of the label in characters
  - `:style` - Style options for the label
  - `:align` - Text alignment (:left, :center, :right)

  ## Example
      label("Username:", width: 10)
      label("Password:", width: 10, align: :right)
  """
  def label(text, opts \\ []) do
    %{
      type: :label,
      content: text,
      attrs: ensure_style(ensure_id(opts)),
      position: Keyword.get(opts, :position, {0, 0}),
      style: Keyword.get(opts, :style, %{})
    }
  end

  defp ensure_id(opts) do
    if Keyword.has_key?(opts, :id),
      do: opts,
      else: Keyword.put(opts, :id, :test_id)
  end

  defp ensure_style(opts) do
    if Keyword.has_key?(opts, :style),
      do: opts,
      else: Keyword.put(opts, :style, %{})
  end
end
