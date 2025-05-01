#!/usr/bin/env elixir
# Component Showcase Demo
#
# This example demonstrates various Raxol components, layouts, and features.
#
# Run with: mix run examples/showcase/component_showcase.exs

defmodule ComponentShowcase do
  # Use the standard Application behaviour
  # use Raxol.Core.Runtime.Application
  use Raxol.Component
  # Import View DSL macros and potentially component functions
  # import Raxol.View.Elements # Not needed with ~V
  # Alias necessary components
  # alias Raxol.UI.Components.Input.SelectList # Use <.select_list>
  # alias Raxol.UI.Components.Display.Progress # Use <.progress>
  # alias Raxol.Components.Progress.Spinner # Use <.spinner>
  # alias Raxol.Components.Modal # Use <.modal>
  alias Raxol.View.Elements # Standard elements like box, row, column, text etc.

  @impl Raxol.Component
  # def init(_context) do
  def mount(_params, _session, socket) do
    # Add :ok tuple to return value
    # {:ok,
    #  %{
       active_tab: :components,
       progress: 0,
       input_value: "",
       checkbox_value: false,
       theme_id: :default, # Use theme ID, e.g., :default, :dark
       multi_line_value: "Initial text for\nMultiLineInput component.\n\nIt supports multiple lines!", # Add state for MultiLineInput
       table_data: [
         %{id: 1, name: "Alice", role: "Admin", status: "Active"},
         %{id: 2, name: "Bob", role: "User", status: "Inactive"},
         %{id: 3, name: "Charlie", role: "User", status: "Active"},
         %{id: 4, name: "David", role: "Moderator", status: "Active"}
       ], # Add state for Table
       select_list_options: ["Option A", "Option B", "Option C", "Longer Option D"],
       selected_option: nil, # Add state for SelectList
       is_loading: false, # Add state for Spinner
       is_modal_open: false # Add state for Modal
     }}
    socket =
      assign(socket,
        active_tab: :components,
        progress: 0,
        input_value: "",
        checkbox_value: false,
        theme_id: :default,
        multi_line_value: "Initial text for\nMultiLineInput component.\n\nIt supports multiple lines!",
        table_data: [
          %{id: 1, name: "Alice", role: "Admin", status: "Active"},
          %{id: 2, name: "Bob", role: "User", status: "Inactive"},
          %{id: 3, name: "Charlie", role: "User", status: "Active"},
          %{id: 4, name: "David", role: "Moderator", status: "Active"}
        ],
        select_list_options: ["Option A", "Option B", "Option C", "Longer Option D"],
        selected_option: nil,
        is_loading: false,
        is_modal_open: false
      )

    {:ok, socket}
  end

  # @impl true
  # def update(message, model) do
  #   # Add :ok tuple and empty command list to return value
  #   case message do
  #     :increment_progress ->
  #       new_progress = min(model.progress + 10, 100)
  #       {:ok, %{model | progress: new_progress}, []}
  #
  #     :reset_progress ->
  #       {:ok, %{model | progress: 0}, []}
  #
  #     {:update_input, value} ->
  #       {:ok, %{model | input_value: value}, []}
  #
  #     {:toggle_checkbox} ->
  #       {:ok, %{model | checkbox_value: !model.checkbox_value}, []}
  #
  #     {:update_multi_line, value} -> # Add handler for MultiLineInput
  #       {:ok, %{model | multi_line_value: value}, []}
  #
  #     {:select_option, option} -> # Add handler for SelectList
  #       {:ok, %{model | selected_option: option}, []}
  #
  #     {:toggle_loading} -> # Add handler for Spinner
  #       {:ok, %{model | is_loading: !model.is_loading}, []}
  #
  #     :open_modal -> # Add handler for Modal
  #       {:ok, %{model | is_modal_open: true}, []}
  #
  #     :close_modal -> # Add handler for Modal
  #       {:ok, %{model | is_modal_open: false}, []}
  #
  #     {:change_tab, tab} ->
  #       {:ok, %{model | active_tab: tab}, []}
  #
  #     {:change_theme, theme_id} ->
  #       # TODO: Ideally, send a command to change the actual theme
  #       # For now, just update the state for preview purposes
  #       {:ok, %{model | theme_id: theme_id}, []}
  #
  #     _ ->
  #       # Ignore unknown messages
  #       {:ok, model, []}
  #   end
  # end

  @impl Raxol.Component
  def handle_event("increment_progress", _params, socket) do
    new_progress = min(socket.assigns.progress + 10, 100)
    {:noreply, assign(socket, :progress, new_progress)}
  end

  def handle_event("reset_progress", _params, socket) do
    {:noreply, assign(socket, :progress, 0)}
  end

  def handle_event("update_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, :input_value, value)}
  end

  # Assuming checkbox sends {"checked" => boolean} or similar, adjust if needed
  def handle_event("toggle_checkbox", %{"checked" => checked}, socket) do
     {:noreply, assign(socket, :checkbox_value, checked)}
  end

  def handle_event("update_multi_line", %{"value" => value}, socket) do
    {:noreply, assign(socket, :multi_line_value, value)}
  end

  def handle_event("select_option", %{"value" => option}, socket) do
    {:noreply, assign(socket, :selected_option, option)}
  end

  def handle_event("toggle_loading", _params, socket) do
    {:noreply, assign(socket, :is_loading, !socket.assigns.is_loading)}
  end

  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :is_modal_open, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :is_modal_open, false)}
  end

  def handle_event("change_tab", %{"tab" => tab_str}, socket) do
    tab = String.to_existing_atom(tab_str)
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # TODO: Implement actual theme changing logic if applicable
  def handle_event("change_theme", %{"theme" => theme_str}, socket) do
    theme_id = String.to_existing_atom(theme_str)
    {:noreply, assign(socket, :theme_id, theme_id)}
  end


  # @impl true
  # Renamed from render/1 to view/1
  # def view(model) do
  @impl Raxol.Component
  def render(assigns) do
    # TODO: Replace hardcoded themes with ColorSystem calls
    theme = get_theme_preview_colors(assigns.theme_id)

    # Main layout - Use `view` macro instead of bare `column`
    # view do
    ~V"""
    # Render Modal conditionally ON TOP of other elements
    {#if assigns.is_modal_open do}
      <.modal
        id="my_modal"
        title="My Modal Title"
        rax-close="close_modal"
        width={40}
        height={10}
      >
        <.column padding=1 gap=1>
          <.text>This is the content of the modal.</.text>
          <.button rax-click="close_modal" preset={:secondary}>Close Me</.button>
        </.column>
      </.modal>
    {#end}

    <.column>
      # Header with tabs
      <.panel title="Raxol Component Showcase" border=:single>
        <.row align=:center justify=:space_around padding={{0, 1}}>
          <.button
            label="Components"
            # Use theme color - requires theme map structure knowledge
            # style={if assigns.active_tab == :components, do: [[:bg, theme.accent_bg], [:fg, theme.accent_fg]], else: []}
            bg={if assigns.active_tab == :components, do: theme.accent_bg}
            fg={if assigns.active_tab == :components, do: theme.accent_fg}
            rax-click="change_tab"
            rax-value-tab="components"
          />
          <.button
            label="Layout"
            bg={if assigns.active_tab == :layout, do: theme.accent_bg}
            fg={if assigns.active_tab == :layout, do: theme.accent_fg}
            rax-click="change_tab"
            rax-value-tab="layout"
          />
          <.button
            label="Theming"
            bg={if assigns.active_tab == :theming, do: theme.accent_bg}
            fg={if assigns.active_tab == :theming, do: theme.accent_fg}
            rax-click="change_tab"
            rax-value-tab="theming"
          />
        </.row>
      </.panel>

      # Content area
      <.panel height=:fill border=:none> {# Use :fill for dynamic height}
        {#case assigns.active_tab do}
          {#:components ->}
            {#render_components_tab(assigns, theme)}
          {#:layout ->}
            {#render_layout_tab(assigns, theme)}
          {#:theming ->}
            {#render_theming_tab(assigns, theme)}
        {#end}
      </.panel>

      # Footer
      <.panel border=:single>
        <.row align=:center padding={{0, 1}}>
          <.text>Press Ctrl+C to exit</.text>
        </.row>
      </.panel>

      # Add button to open Modal
      <.column margin_top=1>
        <.label style={[:bold]}>Modal:</.label>
        <.button rax-click="open_modal">Open Modal</.button>
      </.column>
    </.column>
    """
    # end
  end

  # --- Tab Rendering Functions ---
  # (Keep existing structure, but will need updates for components/theming)

  # Components tab
  # defp render_components_tab(model, theme) do
  defp render_components_tab(assigns, theme) do
    # column style: %{padding: 1, gap: 1} do
    ~V"""
    <.column padding=1 gap=1>
      <.label style={[[:fg, theme.accent_fg], :bold]}>Component System Showcase</.label>

      # Use macros from View.Elements
      <.row gap=2>
        <.column size=:auto>
          <.label style={[:bold]}>Buttons:</.label>
          <.button preset={:primary}>Primary</.button>
          <.button preset={:secondary}>Secondary</.button>
          <.button preset={:danger}>Danger</.button>
        </.column>

        <.column size=:auto>
          <.label style={[:bold]}>Progress:</.label>
          <.progress
            value={assigns.progress}
            max={100}
            label="{assigns.progress}%"
            width=20
          />
          <.row gap=1>
            <.button rax-click="increment_progress">Increment</.button>
            <.button rax-click="reset_progress" preset={:secondary}>Reset</.button>
          </.row>
        </.column>
      </.row>

      <.row gap=2 margin_top=1>
        <.column size=:auto>
          <.label style={[:bold]}>Text Input:</.label>
          <.text_input
            id="my_input"
            value={assigns.input_value}
            placeholder="Enter text here..."
            rax-change="update_input"
            # style={[{:width, 30}]} # Assuming style applies directly
            width=30
          />
        </.column>

        <.column size=:auto>
          <.label style={[:bold]}>Checkbox:</.label>
          <.row align_items=:center>
            <.checkbox
              id="my_checkbox"
              checked={assigns.checkbox_value}
              rax-change="toggle_checkbox" # Sends {"checked": boolean}
            />
            <.label> Enable feature</.label>
          </.row>
        </.column>
      </.row>

      # Add MultiLineInput
      <.column margin_top=1>
        <.label style={[:bold]}>Multi-Line Input:</.label>
        <.multi_line_input
          id="my_multi_line_input"
          value={assigns.multi_line_value}
          rax-change="update_multi_line"
          width=40
          height=5
          border=:single
        />
      </.column>

      # Add Table
      <.column margin_top=1>
        <.label style={[:bold]}>Table:</.label>
        <.table
          id="my_table"
          data={assigns.table_data}
          columns={[
            %{header: "ID", key: :id, width: 5},
            %{header: "Name", key: :name, width: 15},
            %{header: "Role", key: :role, width: 15},
            %{header: "Status", key: :status, width: 10}
          ]}
          width=50
          height=6
          border=:single
        />
      </.column>

      # Add SelectList
      <.column margin_top=1>
        <.label style={[:bold]}>Select List:</.label>
        <.select_list
          id="my_select_list"
          options={assigns.select_list_options}
          selected={assigns.selected_option}
          rax-change="select_option" # Sends {"value": selected_option}
          width=25
          height=4 # Example height, adjust as needed
        />
        <.text margin_top=1>Selected: {assigns.selected_option || "None"}</.text>
      </.column>

      # Add Spinner
      <.column margin_top=1>
        <.label style={[:bold]}>Spinner / Loading Indicator:</.label>
        <.row gap=1 align=:center>
          <.spinner is_loading={assigns.is_loading} />
          <.text>{if assigns.is_loading, do: "Loading...", else: "Idle"}</.text>
          <.button rax-click="toggle_loading">Toggle Loading</.button>
        </.row>
      </.column>
    </.column>
    """
    # end
  end

  # Layout tab
  # defp render_layout_tab(model, theme) do
  defp render_layout_tab(assigns, theme) do
    # column style: %{padding: 1, gap: 1} do
    ~V"""
    <.column padding=1 gap=1>
      <.label style={[[:fg, theme.accent_fg], :bold]}>Layout System Demo</.label>
      <.text>Demonstrates Row, Column, Panel with various alignment and sizing.</.text>

      # Example: Nested Panels & Flexbox-like behavior
      <.panel title="Outer Panel" border=:double width=60 height=20>
        <.column height="100%" gap=1>
          <.row height=3>
            <.panel title="Header" width="100%" border=:single align=:center justify=:center>
              <.text>Fixed Height Header</.text>
            </.panel>
          </.row>
          <.row flex=1 gap=1> {# Fill remaining space}
            <.panel title="Sidebar" width=15 border=:single padding=1>
              <.column gap=1>
                <.text>Item A</.text>
                <.text>Item B</.text>
              </.column>
            </.panel>
            <.panel title="Main Content" flex=1 border=:single padding=1>
              <.text>This content area takes the remaining width.</.text>
            </.panel>
          </.row>
          <.row height=3>
            <.panel title="Footer" width="100%" border=:single align=:center justify=:center>
              <.text>Fixed Height Footer</.text>
            </.panel>
          </.row>
        </.column>
      </.panel>
    </.column>
    """
    # end
  end

  # Theming tab
  # defp render_theming_tab(model, theme) do
  defp render_theming_tab(assigns, theme) do
    # column style: %{padding: 1, gap: 1} do
    ~V"""
    <.column padding=1 gap=1>
      <.label style={[[:fg, theme.accent_fg], :bold]}>Theming Preview</.label>
      <.text>Select a theme to preview colors (preview only).</.text>

      <.row gap=2>
        <.button rax-click="change_theme" rax-value-theme="default">Default Theme</.button>
        <.button rax-click="change_theme" rax-value-theme="dark">Dark Theme</.button>
        <.button rax-click="change_theme" rax-value-theme="solarized">Solarized</.button>
      </.row>

      <.label margin_top=1 style={[:bold]}>Color Palette Preview (Theme: {assigns.theme_id}):</.label>
      <.panel title="Preview Panel" border=:single width=50>
        <.column padding=1 gap=1>
          <.row><.box width=10 height=1 bg={theme.primary_bg} /><.text fg={theme.primary_fg}> Primary BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.secondary_bg} /><.text fg={theme.secondary_fg}> Secondary BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.accent_bg} /><.text fg={theme.accent_fg}> Accent BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.error_bg} /><.text fg={theme.error_fg}> Error BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.warning_bg} /><.text fg={theme.warning_fg}> Warning BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.info_bg} /><.text fg={theme.info_fg}> Info BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.success_bg} /><.text fg={theme.success_fg}> Success BG / FG</.text></.row>
          <.row><.box width=10 height=1 bg={theme.base_bg} /><.text fg={theme.base_fg}> Base BG / FG</.text></.row>
        </.column>
      </.panel>
    </.column>
    """
    # end
  end

  # --- Helper Functions ---

  # TODO: Replace this with actual ColorSystem calls if available
  defp get_theme_preview_colors(:dark) do
    %{
      primary_bg: :blue, primary_fg: :white,
      secondary_bg: :bright_black, secondary_fg: :light_gray,
      accent_bg: :magenta, accent_fg: :white,
      error_bg: :red, error_fg: :white,
      warning_bg: :yellow, warning_fg: :black,
      info_bg: :cyan, info_fg: :black,
      success_bg: :green, success_fg: :white,
      base_bg: :black, base_fg: :white
    }
  end

  defp get_theme_preview_colors(:solarized) do
    # Approximate Solarized Dark colors
    %{
      primary_bg: 0x002b36, primary_fg: 0x839496, # base03, base0
      secondary_bg: 0x073642, secondary_fg: 0x93a1a1, # base02, base1
      accent_bg: 0x268bd2, accent_fg: 0xeee8d5, # blue, base2
      error_bg: 0xdc322f, error_fg: 0xfdf6e3, # red, base3
      warning_bg: 0xb58900, warning_fg: 0x002b36, # yellow, base03
      info_bg: 0x2aa198, info_fg: 0x002b36, # cyan, base03
      success_bg: 0x859900, success_fg: 0x002b36, # green, base03
      base_bg: 0x002b36, base_fg: 0x839496 # base03, base0
    }
  end

  defp get_theme_preview_colors(_) do # Default theme
    %{
      primary_bg: :blue, primary_fg: :white,
      secondary_bg: :light_gray, secondary_fg: :black,
      accent_bg: :cyan, accent_fg: :black,
      error_bg: :red, error_fg: :white,
      warning_bg: :yellow, warning_fg: :black,
      info_bg: :blue, info_fg: :white,
      success_bg: :green, success_fg: :white,
      base_bg: :default, base_fg: :default # Terminal default
    }
  end
end

# Consider how to start this component if needed, e.g., using Raxol.run(ComponentShowcase)
# This might require adjustments based on the final API for running components.
