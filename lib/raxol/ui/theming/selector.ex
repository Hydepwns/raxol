defmodule Raxol.UI.Theming.Selector do
  @moduledoc '''
  A component for selecting and applying themes.

  This module provides:
  * A list-based theme selector UI
  * Theme preview capabilities
  * Theme application functionality
  * Theme management integration
  '''

  use Raxol.UI.Components.Base.Component

  alias Raxol.UI.Theming.Theme
  # alias Raxol.UI.Components.Input.SelectList
  # alias Raxol.Core.Events

  @type props :: %{
          optional(:id) => String.t(),
          optional(:on_select) => (String.t() -> any()),
          optional(:width) => integer(),
          optional(:height) => integer(),
          optional(:show_preview) => boolean(),
          optional(:title) => String.t()
        }

  @type state :: %{
          themes: list(),
          selected_index: integer(),
          expanded: boolean()
        }

  @type t :: %{
          props: props(),
          state: state()
        }

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Get all available themes
    themes = Theme.list_themes()
    current_theme_name = Theme.current().name

    # Find the index of the current theme
    selected_index =
      Enum.find_index(themes, fn theme ->
        theme.name == current_theme_name
      end) || 0

    %{
      props: normalize_props(props),
      state: %{
        themes: themes,
        selected_index: selected_index,
        expanded: false
      }
    }
  end

  @impl true
  def update(component, new_props) do
    updated_props = Map.merge(component.props, normalize_props(new_props))

    %{component | props: updated_props}
  end

  @impl true
  def handle_event(component, {:key_press, key, _modifiers}, _context)
      when key in [:up, :down, :left, :right, :enter, :space] do
    if component.state.expanded do
      # Only handle up/down when expanded
      themes_count = length(component.state.themes)
      current_index = component.state.selected_index

      # Calculate new index based on direction
      new_index =
        case key do
          :up -> max(0, current_index - 1)
          :down -> min(themes_count - 1, current_index + 1)
          :left -> max(0, current_index - 1)
          :right -> min(themes_count - 1, current_index + 1)
          :enter -> current_index
          :space -> current_index
        end

      {:ok,
       %{component | state: %{component.state | selected_index: new_index}}}
    else
      {:ok, component}
    end
  end

  def handle_event(component, {:key_press, :escape, _modifiers}, _context) do
    # Escape key collapses the selector without changing the theme
    if component.state.expanded do
      {:ok, %{component | state: %{component.state | expanded: false}}}
    else
      {:ok, component}
    end
  end

  def handle_event(component, {:mouse_event, :click, _x, y, _button}, _context) do
    if component.state.expanded do
      # Calculate which theme was clicked based on y position
      # The first line is the header, so subtract 1
      clicked_index = y - 1

      if clicked_index >= 0 && clicked_index < length(component.state.themes) do
        # Update selected index
        updated = %{
          component
          | state: %{component.state | selected_index: clicked_index}
        }

        # Apply theme on click
        selected_theme = Enum.at(updated.state.themes, clicked_index)
        Theme.apply_theme(selected_theme.name)

        # Call the onSelect callback if provided
        if on_select = component.props[:on_select] do
          on_select.(selected_theme.name)
        end

        # Collapse after selection
        {:ok, %{updated | state: %{updated.state | expanded: false}}}
      else
        # Click outside theme list area, just collapse
        {:ok, %{component | state: %{component.state | expanded: false}}}
      end
    else
      # When collapsed, expand the selector
      {:ok, %{component | state: %{component.state | expanded: true}}}
    end
  end

  def handle_event(component, _event, _context) do
    {:ok, component}
  end

  @impl true
  def render(component, _context) do
    props = component.props
    state = component.state
    width = props.width

    # Get current theme for colors
    current_theme_struct = Theme.current()
    selected_name = current_theme_struct.name

    colors =
      Map.get(current_theme_struct.styles, :selector) ||
        %{
          # Fallback colors if :selector style is not defined in the theme
          fg: Theme.get_color(current_theme_struct, :foreground) || :white,
          bg: Theme.get_color(current_theme_struct, :background) || :black,
          border: Theme.get_color(current_theme_struct, :primary) || :blue,
          highlight: Theme.get_color(current_theme_struct, :secondary) || :cyan,
          title: Theme.get_color(current_theme_struct, :info) || :yellow
        }

    if state.expanded do
      # Render expanded selector as a list
      header = %{
        type: :text,
        x: 0,
        y: 0,
        text: props.title || "Select Theme:",
        attrs: %{
          fg: colors.title,
          bg: colors.bg
        }
      }

      # Create list items for each theme
      theme_items =
        Enum.with_index(state.themes)
        |> Enum.map(fn {theme, index} ->
          # Highlight the selected item
          is_selected = index == state.selected_index

          %{
            type: :text,
            # Indented
            x: 2,
            # +1 to account for header
            y: index + 1,
            text: theme.name,
            attrs: %{
              fg: if(is_selected, do: colors.highlight, else: colors.fg),
              bg: colors.bg
            }
          }
        end)

      # Calculate box height based on number of themes
      # +1 for header, +1 for bottom border
      box_height = length(state.themes) + 2

      # Create container box
      box = %{
        type: :box,
        width: width,
        height: box_height,
        attrs: %{
          fg: colors.border,
          bg: colors.bg,
          border: %{
            top_left: "┌",
            top_right: "┐",
            bottom_left: "└",
            bottom_right: "┘",
            horizontal: "─",
            vertical: "│"
          }
        }
      }

      # Instructions text
      instructions = %{
        type: :text,
        x: 0,
        # Positioned below the box
        y: box_height,
        text: "↑/↓: Nav  Enter: Select  Esc: Cancel",
        attrs: %{
          fg: colors.fg,
          bg: colors.bg
        }
      }

      # Combine elements for expanded view
      [box, header | theme_items] ++ [instructions]
    else
      # Render collapsed selector (shows current theme)
      text = "Theme: " <> selected_name <> " ▼"

      %{
        type: :text,
        x: 0,
        y: 0,
        text: String.pad_trailing(text, width),
        attrs: %{
          fg: colors.fg,
          bg: colors.bg
        }
      }
    end
  end

  # Private helpers

  defp normalize_props(props) do
    Map.merge(
      %{
        id: nil,
        on_select: fn _ -> nil end,
        # Default width
        width: 20,
        # Default height (usually expands)
        height: 1,
        # Preview not implemented yet
        show_preview: false,
        title: nil
      },
      props
    )
  end
end
