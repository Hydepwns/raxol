defmodule Raxol.View.Components do
  @moduledoc """
  Basic view components for Raxol UI rendering.

  This module provides fundamental components for building terminal UIs,
  including text, boxes, rows, columns, and other layout elements.
  """

  @doc """
  Creates a text component with the given content.

  ## Options
  - `:content` - The text content to display
  - `:style` - Optional style attributes
  - `:id` - Optional component identifier
  """
  @spec text(keyword() | map()) :: map()
  def text(opts) when is_list(opts) do
    text(Map.new(opts))
  end

  def text(%{content: content} = opts) do
    %{
      type: :text,
      content: content,
      fg: Map.get(opts, :fg),
      bg: Map.get(opts, :bg),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  def text(_opts) do
    %{
      type: :text,
      content: "",
      style: %{}
    }
  end

  @doc """
  Creates a box component.
  """
  @spec box(keyword() | map()) :: map()
  def box(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :box,
      style: Map.get(opts, :style, %{}),
      children: Map.get(opts, :children, []),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a row layout component.
  """
  @spec row(keyword() | map()) :: map()
  def row(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :row,
      style: Map.get(opts, :style, %{}),
      children: Map.get(opts, :children, []),
      id: Map.get(opts, :id),
      gap: Map.get(opts, :gap, 0)
    }
  end

  @doc """
  Creates a column layout component.
  """
  @spec column(keyword() | map()) :: map()
  def column(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :column,
      style: Map.get(opts, :style, %{}),
      children: Map.get(opts, :children, []),
      id: Map.get(opts, :id),
      gap: Map.get(opts, :gap, 0)
    }
  end

  @doc """
  Creates a label component.
  """
  @spec label(keyword() | map()) :: map()
  def label(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :label,
      attrs: [
        content: Map.get(opts, :content, ""),
        style: Map.get(opts, :style, %{})
      ],
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a button component.
  """
  @spec button(keyword() | map()) :: map()
  def button(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :button,
      content: Map.get(opts, :content, "Button"),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_click: Map.get(opts, :on_click)
    }
  end

  @doc """
  Creates an input field component.
  """
  @spec input(keyword() | map()) :: map()
  def input(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :input,
      value: Map.get(opts, :value, ""),
      placeholder: Map.get(opts, :placeholder, ""),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a list component.
  """
  @spec list(keyword() | map()) :: map()
  def list(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :list,
      items: Map.get(opts, :items, []),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      selected: Map.get(opts, :selected)
    }
  end

  @doc """
  Creates a spacer component.
  """
  @spec spacer(keyword() | map()) :: map()
  def spacer(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :spacer,
      size: Map.get(opts, :size, 1),
      direction: Map.get(opts, :direction, :vertical)
    }
  end

  @doc """
  Creates a divider component.
  """
  @spec divider(keyword() | map()) :: map()
  def divider(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :divider,
      style: Map.get(opts, :style, %{}),
      char: Map.get(opts, :char, "-")
    }
  end

  @doc """
  Creates an image component for inline terminal image display.

  ## Options
  - `:src` - File path or raw binary image data (required)
  - `:width` - Width in terminal cells (default: 20)
  - `:height` - Height in terminal cells (default: 10)
  - `:protocol` - Override protocol (:kitty, :iterm2, :sixel)
  - `:preserve_aspect` - Preserve aspect ratio (default: true)
  - `:style` - Optional style attributes
  - `:id` - Optional component identifier
  """
  @spec image(keyword() | map()) :: map()
  def image(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :image,
      src: Map.get(opts, :src),
      width: Map.get(opts, :width, 20),
      height: Map.get(opts, :height, 10),
      protocol: Map.get(opts, :protocol),
      preserve_aspect: Map.get(opts, :preserve_aspect, true),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a progress bar component.
  """
  @spec progress(keyword() | map()) :: map()
  def progress(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :progress,
      value: Map.get(opts, :value, 0),
      max: Map.get(opts, :max, 100),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a modal component.
  """
  @spec modal(keyword() | map()) :: map()
  def modal(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :modal,
      title: Map.get(opts, :title, ""),
      content: Map.get(opts, :content),
      visible: Map.get(opts, :visible, false),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a table component.
  """
  @spec table(keyword() | map()) :: map()
  def table(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :table,
      headers: Map.get(opts, :headers, []),
      rows: Map.get(opts, :rows, []),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a select/dropdown component.
  """
  @spec select(keyword() | map()) :: map()
  def select(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :select,
      options: Map.get(opts, :options, []),
      selected: Map.get(opts, :selected),
      placeholder: Map.get(opts, :placeholder, "Select..."),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a checkbox component.
  """
  @spec checkbox(keyword() | map()) :: map()
  def checkbox(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :checkbox,
      checked: Map.get(opts, :checked, false),
      label: Map.get(opts, :label, ""),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a radio button group component.
  """
  @spec radio_group(keyword() | map()) :: map()
  def radio_group(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :radio_group,
      options: Map.get(opts, :options, []),
      selected: Map.get(opts, :selected),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a textarea component.
  """
  @spec textarea(keyword() | map()) :: map()
  def textarea(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :textarea,
      value: Map.get(opts, :value, ""),
      placeholder: Map.get(opts, :placeholder, ""),
      rows: Map.get(opts, :rows, 5),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a container component with optional scrolling.
  """
  @spec container(keyword() | map()) :: map()
  def container(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :container,
      children: Map.get(opts, :children, []),
      scrollable: Map.get(opts, :scrollable, false),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id)
    }
  end

  @doc """
  Creates a tabs component.
  """
  @spec tabs(keyword() | map()) :: map()
  def tabs(opts \\ []) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    %{
      type: :tabs,
      tabs: Map.get(opts, :tabs, []),
      active: Map.get(opts, :active, 0),
      style: Map.get(opts, :style, %{}),
      id: Map.get(opts, :id),
      on_change: Map.get(opts, :on_change)
    }
  end

  @doc """
  Creates a split pane layout component.

  ## Options

    * `:direction` - `:horizontal` or `:vertical` (default `:horizontal`)
    * `:ratio` - Tuple for space distribution (default `{1, 1}`)
    * `:min_size` - Minimum pane dimension (default `5`)
    * `:id` - Optional identifier
    * `:children` - Child elements (one per pane)
  """
  @spec split_pane(keyword() | map()) :: map()
  def split_pane(opts \\ []) do
    Raxol.UI.Layout.SplitPane.new(opts)
  end

  @doc """
  Helper to wrap content in a styled span.
  """
  @spec span(binary(), keyword()) :: map()
  def span(content, opts \\ []) do
    text(Keyword.merge([content: content], opts))
  end
end
