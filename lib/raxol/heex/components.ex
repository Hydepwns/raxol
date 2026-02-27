defmodule Raxol.HEEx.Components do
  @moduledoc """
  Terminal-specific Phoenix function components for HEEx templates.

  These components render terminal UI elements within HEEx templates,
  providing a familiar Phoenix component syntax for terminal applications.

  ## Usage

      defmodule MyApp do
        use Raxol.HEEx

        def render(assigns) do
          ~H\"\"\"
          <.terminal_box padding={2} border="single">
            <.terminal_text color="green" bold>Hello!</.terminal_text>
          </.terminal_box>
          \"\"\"
        end
      end

  ## Available Components

  - `terminal_box/1` - Container with border and padding
  - `terminal_text/1` - Styled text element
  - `terminal_button/1` - Clickable button
  - `terminal_row/1` - Horizontal layout container
  - `terminal_column/1` - Vertical layout container
  - `terminal_input/1` - Text input field
  - `terminal_progress/1` - Progress bar
  - `terminal_divider/1` - Horizontal divider line
  """

  use Phoenix.Component

  require Logger

  alias Raxol.Style
  alias Raxol.Style.Borders

  # ============================================================================
  # Container Components
  # ============================================================================

  @doc """
  Renders a box container with optional border and padding.

  ## Attributes

  - `padding` - Integer padding inside the box (default: 0)
  - `border` - Border style: "single", "double", "rounded", "none" (default: "none")
  - `color` - Text color (default: :default)
  - `background` - Background color (default: :default)
  - `width` - Fixed width (default: auto)
  - `height` - Fixed height (default: auto)

  ## Slots

  - `inner_block` - Required. The content to render inside the box.

  ## Examples

      <.terminal_box border="single" padding={1}>
        Content here
      </.terminal_box>

      <.terminal_box border="double" color="blue" background="white">
        Styled box
      </.terminal_box>
  """
  attr :padding, :integer, default: 0
  attr :border, :string, default: "none"
  attr :color, :any, default: :default
  attr :background, :any, default: :default
  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :id, :string, default: nil

  slot(:inner_block, required: true)

  def terminal_box(assigns) do
    border_style = parse_border_style(assigns.border)

    style =
      Style.new(%{
        border: border_style,
        padding: assigns.padding,
        color: parse_color(assigns.color),
        background: parse_color(assigns.background),
        width: assigns.width,
        height: assigns.height
      })

    assigns = assign(assigns, :style, style)

    ~H"""
    <div
      data-terminal-component="box"
      data-style={encode_style(@style)}
      id={@id}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a horizontal row container for layout.

  ## Attributes

  - `gap` - Space between children (default: 0)
  - `justify` - Horizontal alignment: "start", "center", "end", "between" (default: "start")
  - `align` - Vertical alignment: "start", "center", "end" (default: "start")

  ## Slots

  - `inner_block` - Required. The content to render in the row.

  ## Examples

      <.terminal_row gap={2} justify="between">
        <.terminal_text>Left</.terminal_text>
        <.terminal_text>Right</.terminal_text>
      </.terminal_row>
  """
  attr :gap, :integer, default: 0
  attr :justify, :string, default: "start"
  attr :align, :string, default: "start"
  attr :id, :string, default: nil

  slot(:inner_block, required: true)

  def terminal_row(assigns) do
    ~H"""
    <div
      data-terminal-component="row"
      data-gap={@gap}
      data-justify={@justify}
      data-align={@align}
      id={@id}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a vertical column container for layout.

  ## Attributes

  - `gap` - Space between children (default: 0)
  - `align` - Horizontal alignment: "start", "center", "end" (default: "start")

  ## Slots

  - `inner_block` - Required. The content to render in the column.

  ## Examples

      <.terminal_column gap={1}>
        <.terminal_text>Line 1</.terminal_text>
        <.terminal_text>Line 2</.terminal_text>
      </.terminal_column>
  """
  attr :gap, :integer, default: 0
  attr :align, :string, default: "start"
  attr :id, :string, default: nil

  slot(:inner_block, required: true)

  def terminal_column(assigns) do
    ~H"""
    <div
      data-terminal-component="column"
      data-gap={@gap}
      data-align={@align}
      id={@id}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  # ============================================================================
  # Text Components
  # ============================================================================

  @doc """
  Renders styled text.

  ## Attributes

  - `color` - Text color (default: :default)
  - `background` - Background color (default: :default)
  - `bold` - Bold text (default: false)
  - `italic` - Italic text (default: false)
  - `underline` - Underlined text (default: false)
  - `strikethrough` - Strikethrough text (default: false)
  - `dim` - Dimmed text (default: false)

  ## Slots

  - `inner_block` - Required. The text content.

  ## Examples

      <.terminal_text color="green" bold>Success!</.terminal_text>
      <.terminal_text color="red" underline>Error</.terminal_text>
  """
  attr :color, :any, default: :default
  attr :background, :any, default: :default
  attr :bold, :boolean, default: false
  attr :italic, :boolean, default: false
  attr :underline, :boolean, default: false
  attr :strikethrough, :boolean, default: false
  attr :dim, :boolean, default: false
  attr :id, :string, default: nil

  slot(:inner_block, required: true)

  def terminal_text(assigns) do
    decorations = build_text_decorations(assigns)

    style =
      Style.new(%{
        color: parse_color(assigns.color),
        background: parse_color(assigns.background),
        text_decoration: decorations
      })

    assigns = assign(assigns, :style, style)

    ~H"""
    <span
      data-terminal-component="text"
      data-style={encode_style(@style)}
      id={@id}
    >
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  # ============================================================================
  # Interactive Components
  # ============================================================================

  @doc """
  Renders a clickable button.

  ## Attributes

  - `disabled` - Whether the button is disabled (default: false)
  - `role` - Button style: "primary", "secondary", "danger", "success" (default: "primary")
  - `phx-click` - Phoenix click event name

  ## Slots

  - `inner_block` - Required. The button label.

  ## Examples

      <.terminal_button phx-click="submit" role="primary">Submit</.terminal_button>
      <.terminal_button disabled>Disabled</.terminal_button>
  """
  attr :disabled, :boolean, default: false
  attr :role, :string, default: "primary"
  attr :id, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  slot(:inner_block, required: true)

  def terminal_button(assigns) do
    ~H"""
    <button
      data-terminal-component="button"
      data-role={@role}
      disabled={@disabled}
      id={@id}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a text input field.

  ## Attributes

  - `value` - Current input value (default: "")
  - `placeholder` - Placeholder text (default: "")
  - `disabled` - Whether input is disabled (default: false)
  - `type` - Input type: "text", "password" (default: "text")
  - `phx-change` - Phoenix change event name
  - `phx-blur` - Phoenix blur event name

  ## Examples

      <.terminal_input value={@query} phx-change="search" placeholder="Search..." />
      <.terminal_input type="password" phx-change="set_password" />
  """
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :type, :string, default: "text"
  attr :id, :string, default: nil
  attr :rest, :global, include: ~w(phx-change phx-blur phx-focus name)

  def terminal_input(assigns) do
    ~H"""
    <input
      data-terminal-component="input"
      type={@type}
      value={@value}
      placeholder={@placeholder}
      disabled={@disabled}
      id={@id}
      {@rest}
    />
    """
  end

  # ============================================================================
  # Display Components
  # ============================================================================

  @doc """
  Renders a progress bar.

  ## Attributes

  - `value` - Current progress (0-100, default: 0)
  - `max` - Maximum value (default: 100)
  - `width` - Bar width in characters (default: 20)
  - `color` - Bar color (default: :green)
  - `show_percentage` - Show percentage text (default: true)
  - `filled_char` - Character for filled portion (default: "=")
  - `empty_char` - Character for empty portion (default: "-")

  ## Examples

      <.terminal_progress value={75} />
      <.terminal_progress value={@progress} color="blue" width={30} />
  """
  attr :value, :integer, default: 0
  attr :max, :integer, default: 100
  attr :width, :integer, default: 20
  attr :color, :any, default: :green
  attr :show_percentage, :boolean, default: true
  attr :filled_char, :string, default: "="
  attr :empty_char, :string, default: "-"
  attr :id, :string, default: nil

  def terminal_progress(assigns) do
    percentage = min(100, max(0, round(assigns.value / assigns.max * 100)))
    filled_count = round(assigns.width * percentage / 100)
    empty_count = assigns.width - filled_count

    filled = String.duplicate(assigns.filled_char, filled_count)
    empty = String.duplicate(assigns.empty_char, empty_count)

    assigns =
      assigns
      |> assign(:percentage, percentage)
      |> assign(:filled, filled)
      |> assign(:empty, empty)

    ~H"""
    <div data-terminal-component="progress" id={@id}>
      <span data-color={@color}>[<%= @filled %></span><span><%= @empty %>]</span>
      <%= if @show_percentage do %>
        <span><%= @percentage %>%</span>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a horizontal divider line.

  ## Attributes

  - `char` - Character to use for the divider (default: "-")
  - `width` - Width of the divider (default: 40)
  - `color` - Divider color (default: :default)

  ## Examples

      <.terminal_divider />
      <.terminal_divider char="=" width={60} color="blue" />
  """
  attr :char, :string, default: "-"
  attr :width, :integer, default: 40
  attr :color, :any, default: :default
  attr :id, :string, default: nil

  def terminal_divider(assigns) do
    line = String.duplicate(assigns.char, assigns.width)
    assigns = assign(assigns, :line, line)

    ~H"""
    <div data-terminal-component="divider" data-color={@color} id={@id}>
      <%= @line %>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp parse_border_style(style) do
    case style do
      "single" -> Borders.new(%{style: :solid, width: 1})
      "double" -> Borders.new(%{style: :double, width: 1})
      "rounded" -> Borders.new(%{style: :rounded, width: 1})
      "none" -> Borders.new(%{style: :none, width: 0})
      _ -> Borders.new()
    end
  end

  defp parse_color(color) when is_atom(color), do: color

  defp parse_color(color) when is_binary(color),
    do: String.to_existing_atom(color)

  defp parse_color(_color), do: :default

  defp build_text_decorations(assigns) do
    []
    |> maybe_add_decoration(assigns.bold, :bold)
    |> maybe_add_decoration(assigns.italic, :italic)
    |> maybe_add_decoration(assigns.underline, :underline)
    |> maybe_add_decoration(assigns.strikethrough, :strikethrough)
  end

  defp maybe_add_decoration(list, true, decoration), do: [decoration | list]
  defp maybe_add_decoration(list, false, _decoration), do: list

  defp encode_style(%Style{} = style) do
    style
    |> Map.from_struct()
    |> Jason.encode!()
  rescue
    e ->
      Logger.warning("Failed to encode style: #{Exception.message(e)}")
      "{}"
  end

  defp encode_style(_), do: "{}"
end
