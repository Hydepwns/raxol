defmodule Raxol.Components.TabBar do
  # Removed: use Raxol.Component
  require Raxol.View

  # alias Raxol.Components.FocusManager # Removed - Unused
  alias Raxol.View

  @moduledoc """
  A tab bar component for navigating between different sections of a UI.

  ## Examples

  ```elixir
  alias Raxol.Components.TabBar

  # In your view function
  def view(model) do
    tabs = [
      %{id: :dashboard, label: "Dashboard"},
      %{id: :settings, label: "Settings"},
      %{id: :help, label: "Help"}
    ]

    view do
      panel do
        TabBar.render(tabs, model.active_tab, &handle_tab_change/2)

        # Content based on active tab
        case model.active_tab do
          :dashboard -> dashboard_view(model)
          :settings -> settings_view(model)
          :help -> help_view(model)
        end
      end
    end
  end

  # Handler function
  def handle_tab_change(model, tab_id) do
    %{model | active_tab: tab_id}
  end

  @behaviour Raxol.ComponentBehaviour

  @doc \"""
  Renders a tab bar with the given tabs, highlighting the active tab.

  ## Parameters

  * `tabs` - A list of tab maps, each containing `:id` and `:label` keys
  * `active_tab` - The ID of the currently active tab
  * `on_change` - A function that takes the model and a tab ID and returns an updated model
  * `opts` - Options for customizing the tab bar appearance

  ## Options

  * `:focus_key` - Key for focusing the tab bar (default: "tab_bar")
  * `:style` - Style for the tab bar (default: %{})
  * `:tab_style` - Style for individual tabs (default: %{})
  * `:active_tab_style` - Style for the active tab (default: %{fg: :white, bg: :blue})

  ## Returns

  A view element representing the tab bar.

  ## Example

  ```elixir
  TabBar.render(
    [
      %{id: :tab1, label: "First Tab"},
      %{id: :tab2, label: "Second Tab"}
    ],
    :tab1,
    &handle_tab_change/2,
    active_tab_style: %{fg: :white, bg: :green}
  )
  ```
  """
  def render(tabs, active_tab, on_change, opts \\ []) do
    focus_key = Keyword.get(opts, :focus_key, "tab_bar")
    style = Keyword.get(opts, :style, %{})
    tab_style = Keyword.get(opts, :tab_style, %{})

    active_tab_style =
      Keyword.get(opts, :active_tab_style, %{fg: :white, bg: :blue})

    View.row([style: style, id: focus_key], fn ->
      Enum.map(tabs, fn %{id: id, label: label} = tab ->
        is_active = id == active_tab

        # Compute final style for this tab
        final_style =
          if is_active do
            Map.merge(tab_style, active_tab_style)
          else
            tab_style
          end

        # Get additional tab properties if provided
        tooltip = Map.get(tab, :tooltip, "")

        # Create the tab with proper focus key
        tab_focus_key = "#{focus_key}_#{id}"

        View.button(
          [
            id: tab_focus_key,
            style: final_style,
            on_click: fn -> on_change.(id) end,
            tooltip: tooltip
          ],
          label
        )
      end)
    end)
  end

  @doc """
  Creates a tabbed interface with content.

  This is a higher-level component that combines the tab bar with
  content areas for each tab.

  ## Parameters

  * `tabs` - A list of tab maps, each containing `:id`, `:label`, and `:content` keys
  * `active_tab` - The ID of the currently active tab
  * `on_change` - A function that takes the model and a tab ID and returns an updated model
  * `opts` - Options for customizing the tabbed interface

  ## Options

  * `:focus_key` - Key for focusing the tabbed interface (default: "tabbed_view")
  * `:style` - Style for the container (default: %{})
  * `:tab_bar_style` - Style for the tab bar (default: %{})
  * `:tab_style` - Style for individual tabs (default: %{})
  * `:active_tab_style` - Style for the active tab (default: %{fg: :white, bg: :blue})
  * `:content_style` - Style for the content area (default: %{})

  ## Returns

  A view element representing the complete tabbed interface.

  ## Example

  ```elixir
  TabBar.tabbed_view(
    [
      %{id: :tab1, label: "First Tab", content: fn -> View.text("First tab content") end},
      %{id: :tab2, label: "Second Tab", content: fn -> View.text("Second tab content") end}
    ],
    :tab1,
    &handle_tab_change/2
  )
  ```
  """
  def tabbed_view(tabs, active_tab, on_change, opts \\ []) do
    focus_key = Keyword.get(opts, :focus_key, "tabbed_view")
    style = Keyword.get(opts, :style, %{})
    tab_bar_style = Keyword.get(opts, :tab_bar_style, %{})
    tab_style = Keyword.get(opts, :tab_style, %{})

    active_tab_style =
      Keyword.get(opts, :active_tab_style, %{fg: :white, bg: :blue})

    content_style = Keyword.get(opts, :content_style, %{})

    View.row([style: style, id: focus_key], fn ->
      View.row([style: tab_bar_style], fn ->
        render(tabs, active_tab, on_change,
          focus_key: focus_key,
          style: tab_bar_style,
          tab_style: tab_style,
          active_tab_style: active_tab_style
        )
      end)

      View.row([style: content_style], fn ->
        # Find and render the content for the active tab
        active_tab_content =
          case Enum.find(tabs, fn %{id: id} -> id == active_tab end) do
            %{content: content_fn} when is_function(content_fn, 0) ->
              content_fn.()

            %{content: content} ->
              # Assume content is already a View element/map
              content

            _ ->
              View.text("Content not found for tab: #{active_tab}")
          end

        # Return the content to be rendered in the row
        active_tab_content
      end)
    end)
  end
end
