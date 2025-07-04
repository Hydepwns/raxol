defmodule Raxol.UI.Components.TabBar do
  @moduledoc """
  A tab bar component for Raxol.

  A tab bar component for navigating between different sections of a UI.

  ## Examples

  ```elixir
  alias Raxol.UI.Components.TabBar

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
    require Raxol.View.Elements

    focus_key = Keyword.get(opts, :focus_key, "tab_bar")
    style = Keyword.get(opts, :style, %{})
    tab_style = Keyword.get(opts, :tab_style, %{})

    active_tab_style =
      Keyword.get(opts, :active_tab_style, %{fg: :white, bg: :blue})

    Raxol.View.Elements.row style: style, id: focus_key do
      tab_buttons =
        Enum.map(tabs, fn %{id: id, label: label} = tab ->
          active? = id == active_tab

          # Compute final style for this tab
          final_style =
            if active? do
              Map.merge(tab_style, active_tab_style)
            else
              tab_style
            end

          # Get additional tab properties if provided
          tooltip = Map.get(tab, :tooltip, "")

          # Create the tab with proper focus key
          tab_focus_key = "#{focus_key}_#{id}"

          Raxol.View.Components.button(label,
            id: tab_focus_key,
            style: final_style,
            on_click: fn -> on_change.(id) end,
            tooltip: tooltip
          )
        end)

      # Return the tab buttons
      tab_buttons
    end
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
    require Raxol.View.Elements

    focus_key = Keyword.get(opts, :focus_key, "tabbed_view")
    style = Keyword.get(opts, :style, %{})
    tab_bar_style = Keyword.get(opts, :tab_bar_style, %{})
    tab_style = Keyword.get(opts, :tab_style, %{})

    active_tab_style =
      Keyword.get(opts, :active_tab_style, %{fg: :white, bg: :blue})

    content_style = Keyword.get(opts, :content_style, %{})

    Raxol.View.Elements.row style: style, id: focus_key do
      _tab_bar =
        Raxol.View.Elements.row style: tab_bar_style do
          tab_bar_result =
            render(tabs, active_tab, on_change,
              focus_key: focus_key,
              style: tab_bar_style,
              tab_style: tab_style,
              active_tab_style: active_tab_style
            )

          # Return the tab bar
          tab_bar_result
        end

      _content =
        Raxol.View.Elements.row style: content_style do
          # Find and render the content for the active tab
          active_tab_content =
            case Enum.find(tabs, fn %{id: id} -> id == active_tab end) do
              %{content: content_fn} when is_function(content_fn, 0) ->
                content_fn.()

              _ ->
                # Handle case when tab not found or has no content function
                Raxol.View.Components.text(
                  "Content not found for tab: #{active_tab}"
                )
            end

          # Return content element
          active_tab_content
        end

      # Return tab bar and content in a list
      [tab_bar_result, active_tab_content]
    end
  end
end
