defmodule Raxol.Components.HintDisplay do
  use Raxol.Component
  alias Raxol.View.Components
  alias Raxol.View.Layout
  alias Raxol.Core.UXRefinement
  # alias Raxol.View # Unused
  # Keep require for to_element?
  require Raxol.View
  # alias Raxol.Core.Events.Event # Unused
  import Raxol.View.Elements, only: [panel: 2]

  @moduledoc """
  A component for displaying hints and tooltips.

  This component works with the `Raxol.Core.UXRefinement` module to display
  registered hints for components in the UI.

  ## Features

  * Multiple hint styles (minimal, standard, detailed)
  * Keyboard shortcut highlighting
  * Multi-level hints (basic, detailed, examples)
  * Automatic transitioning between hint levels
  * Support for HTML-like markup in hints

  ## Usage

  ```elixir
  # In your view
  def render(model, _opts) do
    column do
      # Your other components
      row do
        text_input(id: "search_input", placeholder: "Search...")
      end

      # Place the hint display at the bottom of the UI
      HintDisplay.render(model.focused_component)
    end
  end
  ```
  """

  @doc """
  Render a hint display for the currently focused component.

  ## Options

  * `:style` - Style of the hint display (`:minimal`, `:standard`, `:detailed`) (default: `:standard`)
  * `:position` - Position of the hint display (`:bottom`, `:top`, `:float`) (default: `:bottom`)
  * `:always_show` - Always show the hint display, even when no hints are available (default: `false`)
  * `:max_width` - Maximum width of the hint display (default: `nil` - full width)
  * `:help_level` - Level of detail to show (`:basic`, `:detailed`, `:examples`) (default: `:basic`)
  * `:highlight_shortcuts` - Highlight keyboard shortcuts in the hint text (default: `true`)

  ## Examples

      iex> HintDisplay.render("search_input")
      # Renders a hint display for the search_input component

      iex> HintDisplay.render(model.focused_component, style: :minimal, position: :float)
      # Renders a minimal floating hint display
  """
  @impl true
  def render(state) do
    dsl_result =
      if state.visible and state.current_hint do
        render_hint_panel(state)
      else
        # Render nothing if not visible or no hint
        nil
      end

    # Convert result (nil or panel map) to Element or nil
    if dsl_result do
      Raxol.View.to_element(dsl_result)
    else
      nil
    end
  end

  @doc """
  Register a keyboard shortcut for display in hints.

  This allows highlighting keyboard shortcuts in the hint display.

  ## Parameters

  * `shortcut_text` - Text representation of the shortcut (e.g., "Ctrl+F")
  * `description` - Brief description of what the shortcut does

  ## Examples

      iex> HintDisplay.register_shortcut("Ctrl+F", "Search")
      :ok
  """
  def register_shortcut(shortcut_text, description) do
    shortcuts = Process.get(:hint_display_shortcuts) || %{}
    updated_shortcuts = Map.put(shortcuts, shortcut_text, description)
    Process.put(:hint_display_shortcuts, updated_shortcuts)
    :ok
  end

  @doc """
  Cycle through help levels for the current component.

  This allows users to see more detailed help when needed.

  ## Examples

      iex> HintDisplay.cycle_help_level()
      :ok
  """
  def cycle_help_level do
    current_level = Process.get(:hint_display_help_level) || :basic

    next_level =
      case current_level do
        :basic -> :detailed
        :detailed -> :examples
        :examples -> :basic
      end

    Process.put(:hint_display_help_level, next_level)

    # Dispatch event to update hint display
    # In a real system, this would trigger an update to the UI
    :ok
  end

  @doc """
  Cleans up resources used by the HintDisplay.
  (Placeholder implementation)
  """
  def cleanup() do
    # TODO: Implement cleanup logic if needed (e.g., clearing process dict)
    Process.delete(:hint_display_shortcuts)
    Process.delete(:hint_display_help_level)
    :ok
  end

  # Private functions

  defp render_hint_panel(state) do
    style = state.style
    position = state.position
    always_show = state.always_show
    max_width = state.max_width
    help_level = state.help_level
    highlight_shortcuts = state.highlight_shortcuts

    hint_info = UXRefinement.get_component_hint(state.current_hint, help_level)

    if hint_info || always_show do
      render_hint_display(
        hint_info,
        style,
        position,
        max_width,
        highlight_shortcuts
      )
    else
      # Return empty element when no hint and not always_show
      nil
    end
  end

  defp render_hint_display(
         hint_info,
         style,
         position,
         max_width,
         highlight_shortcuts
       ) do
    content =
      case hint_info do
        nil -> "No hints available for this component"
        %{text: text} -> text
        text when is_binary(text) -> text
      end

    # Process shortcuts in content if highlighting is enabled
    processed_content =
      if highlight_shortcuts do
        highlight_shortcuts_in_text(content)
      else
        content
      end

    # Get keyboard shortcuts if available in hint info
    shortcuts =
      if hint_info && Map.has_key?(hint_info, :shortcuts) &&
           hint_info.shortcuts != nil do
        hint_info.shortcuts
      else
        []
      end

    # Define view elements
    title_view = render_title(hint_info)
    hints_view = render_hints(processed_content, style, highlight_shortcuts)
    footer_view = render_footer(shortcuts, style)

    container_attrs = [
      padding: 1,
      background: :black,
      color: {:rgb, 180, 180, 180},
      border: [color: :blue, type: :light],
      width: max_width
    ]

    container_attrs =
      case position do
        :bottom ->
          Keyword.merge(container_attrs,
            bottom: 0,
            left: 0,
            height: calculate_height(style, shortcuts)
          )

        :top ->
          Keyword.merge(container_attrs,
            top: 0,
            left: 0,
            height: calculate_height(style, shortcuts)
          )

        :float ->
          Keyword.merge(container_attrs, center: true)
      end

    # Apply container style and layout
    # Use the panel macro directly (imported via `use Raxol.Component` -> `use Raxol.View`)
    panel container_attrs do
      # Combine title, hints, and footer
      [title_view, hints_view, footer_view]
      |> Enum.reject(&is_nil/1)
    end
  end

  defp calculate_height(style, shortcuts) do
    base_height =
      case style do
        :minimal -> 3
        :standard -> 3
        :detailed -> 4
      end

    # Add height for shortcuts
    if shortcuts && length(shortcuts) > 0 && style != :minimal do
      # +1 to account for the header
      base_height + div(length(shortcuts) + 1, 2)
    else
      base_height
    end
  end

  # Renders the title section
  defp render_title(hint_info) do
    title =
      if hint_info && Map.has_key?(hint_info, :title) do
        hint_info.title
      else
        nil
      end

    if title do
      Components.text(title, style: [bold: true])
    else
      nil
    end
  end

  # Renders the main hint text
  defp render_hints(content, style, highlight_shortcuts) do
    processed_content =
      if highlight_shortcuts do
        highlight_shortcuts_in_text(content)
      else
        content
      end

    case style do
      # Minimal doesn't show main content
      :minimal -> nil
      _ -> Components.text(processed_content)
    end
  end

  # Renders the footer section (shortcuts)
  defp render_footer(shortcuts, style) do
    if style != :minimal && length(shortcuts) > 0 do
      # Capture the result of the row function
      row_result =
        Layout.row([padding_top: 1],
          do: fn ->
            # Capture the result of render_shortcuts
            shortcuts_result = render_shortcuts()
            # Return the shortcuts_result
            shortcuts_result
          end
        )

      # Return the row_result
      row_result
    else
      nil
    end
  end

  defp render_shortcuts() do
    # Capture the result of the column function
    column_result =
      Layout.column([],
        do: fn ->
          row1 =
            Layout.row([],
              do: fn ->
                text_result =
                  Components.text("Keyboard Shortcuts:", style: [bold: true])

                [text_result]
              end
            )

          row2 =
            Layout.row([],
              do: fn ->
                text_result = Components.text("Tab: Next field")
                [text_result]
              end
            )

          row3 =
            Layout.row([],
              do: fn ->
                text_result = Components.text("Shift+Tab: Previous field")
                [text_result]
              end
            )

          row4 =
            Layout.row([],
              do: fn ->
                text_result = Components.text("Enter: Submit")
                [text_result]
              end
            )

          row5 =
            Layout.row([],
              do: fn ->
                text_result = Components.text("Esc: Cancel")
                [text_result]
              end
            )

          # Explicitly return the list of rows
          [row1, row2, row3, row4, row5]
        end
      )

    # Return the column_result
    column_result
  end

  defp highlight_shortcuts_in_text(text) do
    # Get registered shortcuts
    shortcuts = Process.get(:hint_display_shortcuts) || %{}
    shortcut_keys = Map.keys(shortcuts)

    # Find and highlight shortcuts in text
    Enum.reduce(shortcut_keys, text, fn shortcut, acc ->
      if String.contains?(acc, shortcut) do
        String.replace(acc, shortcut, "<b>#{shortcut}</b>")
      else
        acc
      end
    end)
    |> format_markup()
  end

  defp format_markup(text) do
    # Simple parsing of markup tags
    # In a real implementation, this would be more robust
    cond do
      String.contains?(text, "<b>") ->
        parts = String.split(text, ~r{<b>(.*?)</b>}, include_captures: true)

        Enum.map(parts, fn part ->
          case Regex.run(~r{<b>(.*?)</b>}, part) do
            [_, content] -> {:bold, content}
            _ -> part
          end
        end)
        |> List.flatten()

      true ->
        text
    end
  end

  @impl true
  def init(opts) do
    # Initialize the help level
    help_level =
      if is_map(opts), do: Map.get(opts, :help_level, :basic), else: :basic

    Process.put(
      :hint_display_help_level,
      help_level
    )

    # Create state map with defaults for any input type
    state = %{
      visible: true,
      style: :standard,
      position: :bottom,
      always_show: false,
      max_width: nil,
      help_level: help_level,
      highlight_shortcuts: true,
      current_hint: nil
    }

    # Override defaults with provided options if they exist and are a map
    if is_map(opts) do
      state
      |> Map.put(:visible, Map.get(opts, :visible, true))
      |> Map.put(:style, Map.get(opts, :style, :standard))
      |> Map.put(:position, Map.get(opts, :position, :bottom))
      |> Map.put(:always_show, Map.get(opts, :always_show, false))
      |> Map.put(:max_width, Map.get(opts, :max_width, nil))
      |> Map.put(
        :highlight_shortcuts,
        Map.get(opts, :highlight_shortcuts, true)
      )
      |> Map.put(:current_hint, Map.get(opts, :current_hint, nil))
    else
      state
    end
  end

  @impl true
  def update(model, msg) do
    case msg do
      {:toggle_visibility} ->
        %{model | visible: !model.visible}

      {:set_style, style} ->
        %{model | style: style}

      {:set_position, position} ->
        %{model | position: position}

      {:set_help_level, level} when level in [:basic, :detailed, :examples] ->
        Process.put(:hint_display_help_level, level)
        %{model | help_level: level}

      {:cycle_help_level} ->
        next_level =
          case model.help_level do
            :basic -> :detailed
            :detailed -> :examples
            :examples -> :basic
          end

        Process.put(:hint_display_help_level, next_level)
        %{model | help_level: next_level}

      {:set_current_hint, hint_id} ->
        %{model | current_hint: hint_id}

      # Return model unchanged for any other message type
      _ ->
        model
    end
  end

  @doc """
  Subscribe to relevant events for the hint display.
  """
  def subscriptions(_model) do
    # Subscribe to focus change events to update hints
    [{:focus_change, :global}]
  end

  @impl true
  def unmount(state) do
    # Clean up any Process dictionary entries
    Process.delete(:hint_display_shortcuts)
    Process.delete(:hint_display_help_level)
    state
  end
end
