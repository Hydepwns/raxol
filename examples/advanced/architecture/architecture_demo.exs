#!/usr/bin/env elixir
# Architecture Showcase Demo
#
# This example demonstrates the reorganized Raxol architecture by showcasing:
# - Component system with various UI elements
# - Layout system for arranging components
# - Theming system for consistent styling
# - Runtime system for application management
# - Plugin system for extending functionality
#
# Run with: mix run examples/showcase/architecture_demo.exs

defmodule ArchitectureDemo do
  # use Raxol.App
  use Raxol.Component
  import Raxol.LiveView, only: [assign: 2, assign: 3]
  # alias Raxol.UI.Components.Input.{Button, TextField, Checkbox}
  # alias Raxol.UI.Components.Display.Progress
  alias Raxol.View.Elements

  # @impl true
  # def init(_) do
  #   %{
  #     active_tab: :components,
  #     progress: 0,
  #     input_value: "",
  #     checkbox_value: false,
  #     theme: :dark
  #   }
  # end
  @impl Raxol.Component
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        active_tab: :components,
        progress: 0,
        input_value: "",
        checkbox_value: false,
        theme: :dark
      )

    {:ok, socket}
  end

  # @impl true
  # def update(model, msg) do
  #   case msg do
  #     :increment_progress ->
  #       new_progress = min(model.progress + 10, 100)
  #       {%{model | progress: new_progress}, []}
  #
  #     :reset_progress ->
  #       {%{model | progress: 0}, []}
  #
  #     {:update_input, value} ->
  #       {%{model | input_value: value}, []}
  #
  #     {:toggle_checkbox} ->
  #       {%{model | checkbox_value: !model.checkbox_value}, []}
  #
  #     {:change_tab, tab} ->
  #       {%{model | active_tab: tab}, []}
  #
  #     {:change_theme, theme} ->
  #       {%{model | theme: theme}, []}
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

  def handle_event("toggle_checkbox", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :checkbox_value, checked)}
  end

  def handle_event("change_tab", %{"tab" => tab_str}, socket) do
    tab = String.to_existing_atom(tab_str)
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("change_theme", %{"theme" => theme_str}, socket) do
    theme = String.to_existing_atom(theme_str)
    {:noreply, assign(socket, :theme, theme)}
  end

  # @impl true
  # def render(model) do
  @impl Raxol.Component
  def render(assigns) do
    # Apply the selected theme
    # theme = case model.theme do
    theme =
      case assigns.theme do
        :dark ->
          %{bg: :black, fg: :white, accent: :blue, panel_bg: :dark_gray}

        :light ->
          %{bg: :white, fg: :black, accent: :blue, panel_bg: :light_gray}

        :colorful ->
          %{bg: :black, fg: :white, accent: :green, panel_bg: :dark_blue}
      end

    # Main layout
    # column do
    ~V"""
    <.column>
      # Header with tabs
      <.panel title="Raxol Architecture Demo" border=:single fg={theme.accent}>
        <.row align=:center justify=:center padding=1>
          <.button
            label="Components"
            variant={if assigns.active_tab == :components, do: :primary, else: :secondary}
            rax-click="change_tab"
            rax-value-tab="components"
          />
          <.button
            label="Layout"
            variant={if assigns.active_tab == :layout, do: :primary, else: :secondary}
            rax-click="change_tab"
            rax-value-tab="layout"
          />
          <.button
            label="Theming"
            variant={if assigns.active_tab == :theming, do: :primary, else: :secondary}
            rax-click="change_tab"
            rax-value-tab="theming"
          />
        </.row>
      </.panel>

      # Content area
      <.panel height=15 fg={theme.fg} bg={theme.panel_bg}>
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
      <.panel border=:single fg={theme.accent}>
        <.row align=:center padding=1>
          <.text>Press Ctrl+C to exit</.text>
        </.row>
      </.panel>
    </.column>
    """

    # end
  end

  # Components tab
  # defp render_components_tab(model, theme) do
  defp render_components_tab(assigns, theme) do
    # column style: %{padding: 1, gap: 1} do
    ~V"""
    <.column padding=1 gap=1>
      <.text style={[[:fg, theme.accent], :bold]}>Component System Showcase</.text>

      <.row gap=2>
        <.column size=1>
          <.text style={[:bold]}>Buttons:</.text>
          <.button label="Primary" variant={:primary} />
          <.button label="Secondary" variant={:secondary} />
          <.button label="Danger" variant={:danger} />
        </.column>

        <.column size=1>
          <.text style={[:bold]}>Progress:</.text>
          <.progress
            value={assigns.progress}
            max={100}
            label="{assigns.progress}%"
            width=20
          />
          <.row gap=1>
            <.button label="Increment" rax-click="increment_progress" />
            <.button label="Reset" rax-click="reset_progress" variant={:secondary} />
          </.row>
        </.column>
      </.row>

      <.row gap=2 margin_top=1>
        <.column size=1>
          <.text style={[:bold]}>Text Input:</.text>
          <.text_input
            value={assigns.input_value}
            placeholder="Enter text here..."
            rax-change="update_input"
            width=30
          />
        </.column>

        <.column size=1>
          <.text style={[:bold]}>Checkbox:</.text>
          <.row>
            <.checkbox
              checked={assigns.checkbox_value}
              rax-change="toggle_checkbox"
            />
            <.text> Enable feature</.text>
          </.row>
        </.column>
      </.row>
    </.column>
    """

    # end
  end

  # Layout tab
  # defp render_layout_tab(model, theme) do
  defp render_layout_tab(assigns, theme) do
    # column style: %{padding: 1} do
    ~V"""
    <.column padding=1>
      <.text style={[[:fg, theme.accent], :bold]}>Layout System Showcase</.text>

      # Grid layout example
      <.panel title="Grid Layout" border=:single margin_top=1>
        <.grid columns=3 gap=1 padding=1>
          {#for i <- 1..9 do}
            <.box bg={theme.accent} padding=1 align=:center>
              <.text style={[:bold]}>{i}</.text>
            </.box>
          {#end}
        </.grid>
      </.panel>

      # Flex layout example
      <.panel title="Flex Layout" border=:single margin_top=1>
        <.row gap=1 padding=1>
          <.box size=1 bg={theme.accent} padding=1 align=:center>
            <.text style={[:bold]}>1</.text>
          </.box>
          <.box size=2 bg={theme.accent} padding=1 align=:center>
            <.text style={[:bold]}>2</.text>
          </.box>
          <.box size=1 bg={theme.accent} padding=1 align=:center>
            <.text style={[:bold]}>1</.text>
          </.box>
        </.row>
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
      <.text style={[[:fg, theme.accent], :bold]}>Theming System Showcase</.text>

      <.text>Select a theme:</.text>

      <.row gap=2 margin_top=1>
        <.button
          label="Dark Theme"
          variant={if assigns.theme == :dark, do: :primary, else: :secondary}
          rax-click="change_theme"
          rax-value-theme="dark"
        />
        <.button
          label="Light Theme"
          variant={if assigns.theme == :light, do: :primary, else: :secondary}
          rax-click="change_theme"
          rax-value-theme="light"
        />
        <.button
          label="Colorful Theme"
          variant={if assigns.theme == :colorful, do: :primary, else: :secondary}
          rax-click="change_theme"
          rax-value-theme="colorful"
        />
      </.row>

      # Theme preview
      <.panel title="Theme Preview" border=:single margin_top=2>
        <.column padding=1 gap=1>
          <.row gap=1>
            <.box bg={theme.bg} padding=1 width=10 align=:center>
              <.text fg={theme.fg}>Background</.text>
            </.box>
            <.box bg={theme.fg} padding=1 width=10 align=:center>
              <.text fg={theme.bg}>Foreground</.text>
            </.box>
            <.box bg={theme.accent} padding=1 width=10 align=:center>
              <.text fg={:white}>Accent</.text> {# Assuming white fg on accent for preview #}
            </.box>
            <.box bg={theme.panel_bg} padding=1 width=10 align=:center>
              <.text fg={theme.fg}>Panel</.text>
            </.box>
          </.row>
        </.column>
      </.panel>
    </.column>
    """

    # end
  end
end

# Start the application
# Raxol.run(ArchitectureDemo, debug: true)
# Raxol.Core.Runtime.start_application(ArchitectureDemo, debug: true) # Keep debug option if needed by runtime
# Consider using Raxol.run(ArchitectureDemo) for the new API
