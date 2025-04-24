defmodule Raxol.UI.Theming.Selector do
  @moduledoc """
  A component for selecting and applying themes.

  This module provides:
  * A list-based theme selector UI
  * Theme preview capabilities
  * Theme application functionality
  * Theme management integration
  """

  alias Raxol.UI.Components.Base.Component
  alias Raxol.UI.Theming.Theme

  @behaviour Component

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

  @impl Component
  def create(props) do
    # Get all available themes
    themes = Theme.list_themes()
    current_theme_name = Theme.get_current_name()

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

  @impl Component
  def update(component, new_props) do
    updated_props = Map.merge(component.props, normalize_props(new_props))

    %{component | props: updated_props}
  end

  @impl Component
  def handle_event(component, {:key_press, key, _modifiers}, _context) when key in [:up, :down] do
    if component.state.expanded do
      # Only handle up/down when expanded
      themes_count = length(component.state.themes)
      current_index = component.state.selected_index

      # Calculate new index based on direction
      new_index =
        case key do
          :up -> max(0, current_index - 1)
          :down -> min(themes_count - 1, current_index + 1)
        end

      {:ok, %{component | state: %{component.state | selected_index: new_index}}}
    else
      {:ok, component}
    end
  end

  @impl Component
  def handle_event(component, {:key_press, :enter, _modifiers}, _context) do
    if component.state.expanded do
      # When expanded, apply the selected theme
      selected_theme = Enum.at(component.state.themes, component.state.selected_index)

      # Apply the theme
      Theme.apply_theme(selected_theme.name)

      # Call the onSelect callback if provided
      if on_select = component.props[:on_select] do
        on_select.(selected_theme.name)
      end

      # Collapse after selection
      {:ok, %{component | state: %{component.state | expanded: false}}}
    else
      # When collapsed, expand the selector
      {:ok, %{component | state: %{component.state | expanded: true}}}
    end
  end

  @impl Component
  def handle_event(component, {:key_press, :escape, _modifiers}, _context) do
    # Escape key collapses the selector without changing the theme
    if component.state.expanded do
      {:ok, %{component | state: %{component.state | expanded: false}}}
    else
      {:ok, component}
    end
  end

  @impl Component
  def handle_event(component, {:mouse_event, :click, _x, y, _button}, _context) do
    if component.state.expanded do
      # Calculate which theme was clicked based on y position
      # The first line is the header, so subtract 1
      clicked_index = y - 1

      if clicked_index >= 0 && clicked_index < length(component.state.themes) do
        # Update selected index
        updated = %{component | state: %{component.state | selected_index: clicked_index}}

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

  @impl Component
  def handle_event(component, _event, _context) do
    {:ok, component}
  end

  @impl Component
  def render(component, _context) do
    props = component.props
    state = component.state
    width = props.width

    # Get current theme for colors
    current_theme = Theme.get_current()
    colors = current_theme[:selector] || %{
      fg: :white,
      bg: :black,
      border: :blue,
      highlight: :cyan,
      title: :yellow
    }

    # Get the currently selected theme name for display
    selected_theme = Enum.at(state.themes, state.selected_index)
    selected_name = selected_theme.name

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
            x: 2, # Indented
            y: index + 1, # +1 to account for header
            text: theme.name,
            attrs: %{
              fg: if(is_selected, do: colors.highlight, else: colors.fg),
              bg: colors.bg
            }
          }
        end)

      # Calculate box height based on number of themes
      box_height = length(state.themes) + 2 # +1 for header, +1 for bottom border

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
        y: box_height + 1,
        text: "↑/↓: Navigate  Enter: Select  Esc: Cancel",
        attrs: %{
          fg: colors.fg,
          bg: colors.bg
        }
      }

      # Combine all elements
      [instructions, header, box | theme_items]
    else
      # Render collapsed selector as a button
      [
        %{
          type: :text,
          x: 0,
          y: 0,
          text: "Theme: #{selected_name} [▼]",
          attrs: %{
            fg: colors.fg,
            bg: colors.bg
          }
        }
      ]
    end
  end

  # Private helpers

  defp normalize_props(props) do
    props = Map.new(props)

    props
    |> Map.put_new(:width, 30)
    |> Map.put_new(:height, 10)
    |> Map.put_new(:show_preview, false)
    |> Map.put_new(:title, "Select Theme:")
  end
end
