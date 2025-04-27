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
  use Raxol.App
  alias Raxol.UI.Components.Input.{Button, TextField, Checkbox}
  alias Raxol.UI.Components.Display.Progress

  @impl true
  def init(_) do
    %{
      active_tab: :components,
      progress: 0,
      input_value: "",
      checkbox_value: false,
      theme: :dark
    }
  end

  @impl true
  def update(model, msg) do
    case msg do
      :increment_progress ->
        new_progress = min(model.progress + 10, 100)
        {%{model | progress: new_progress}, []}

      :reset_progress ->
        {%{model | progress: 0}, []}

      {:update_input, value} ->
        {%{model | input_value: value}, []}

      {:toggle_checkbox} ->
        {%{model | checkbox_value: !model.checkbox_value}, []}

      {:change_tab, tab} ->
        {%{model | active_tab: tab}, []}

      {:change_theme, theme} ->
        {%{model | theme: theme}, []}
    end
  end

  @impl true
  def render(model) do
    # Apply the selected theme
    theme = case model.theme do
      :dark -> %{bg: :black, fg: :white, accent: :blue, panel_bg: :dark_gray}
      :light -> %{bg: :white, fg: :black, accent: :blue, panel_bg: :light_gray}
      :colorful -> %{bg: :black, fg: :white, accent: :green, panel_bg: :dark_blue}
    end

    # Main layout
    column do
      # Header with tabs
      panel title: "Raxol Architecture Demo", border: :single, fg: theme.accent do
        row style: %{align: :center, justify: :center, padding: 1} do
          button label: "Components",
                 variant: if(model.active_tab == :components, do: :primary, else: :secondary),
                 on_click: {:change_tab, :components}

          button label: "Layout",
                 variant: if(model.active_tab == :layout, do: :primary, else: :secondary),
                 on_click: {:change_tab, :layout}

          button label: "Theming",
                 variant: if(model.active_tab == :theming, do: :primary, else: :secondary),
                 on_click: {:change_tab, :theming}
        end
      end

      # Content area
      panel height: 15, fg: theme.fg, bg: theme.panel_bg do
        case model.active_tab do
          :components -> render_components_tab(model, theme)
          :layout -> render_layout_tab(model, theme)
          :theming -> render_theming_tab(model, theme)
        end
      end

      # Footer
      panel border: :single, fg: theme.accent do
        row style: %{align: :center, padding: 1} do
          text content: "Press Ctrl+C to exit"
        end
      end
    end
  end

  # Components tab
  defp render_components_tab(model, theme) do
    column style: %{padding: 1, gap: 1} do
      text content: "Component System Showcase",
           style: %{fg: theme.accent, bold: true}

      row style: %{gap: 2} do
        column size: 1 do
          text content: "Buttons:", style: %{bold: true}
          button label: "Primary", variant: :primary
          button label: "Secondary", variant: :secondary
          button label: "Danger", variant: :danger
        end

        column size: 1 do
          text content: "Progress:", style: %{bold: true}
          Progress.render(%{
            value: model.progress,
            max: 100,
            label: "#{model.progress}%",
            style: %{width: 20}
          })
          row style: %{gap: 1} do
            button label: "Increment", on_click: :increment_progress
            button label: "Reset", on_click: :reset_progress, variant: :secondary
          end
        end
      end

      row style: %{gap: 2, margin_top: 1} do
        column size: 1 do
          text content: "Text Input:", style: %{bold: true}
          TextField.render(%{
            value: model.input_value,
            placeholder: "Enter text here...",
            on_change: {:update_input},
            style: %{width: 30}
          })
        end

        column size: 1 do
          text content: "Checkbox:", style: %{bold: true}
          row do
            Checkbox.render(%{
              checked: model.checkbox_value,
              on_change: {:toggle_checkbox}
            })
            text content: " Enable feature"
          end
        end
      end
    end
  end

  # Layout tab
  defp render_layout_tab(model, theme) do
    column style: %{padding: 1} do
      text content: "Layout System Showcase",
           style: %{fg: theme.accent, bold: true}

      # Grid layout example
      panel title: "Grid Layout", border: :single, style: %{margin_top: 1} do
        grid columns: 3, style: %{gap: 1, padding: 1} do
          for i <- 1..9 do
            box bg: theme.accent, style: %{padding: 1, align: :center} do
              text content: "#{i}", style: %{bold: true}
            end
          end
        end
      end

      # Flex layout example
      panel title: "Flex Layout", border: :single, style: %{margin_top: 1} do
        row style: %{gap: 1, padding: 1} do
          box size: 1, bg: theme.accent, style: %{padding: 1, align: :center} do
            text content: "1", style: %{bold: true}
          end
          box size: 2, bg: theme.accent, style: %{padding: 1, align: :center} do
            text content: "2", style: %{bold: true}
          end
          box size: 1, bg: theme.accent, style: %{padding: 1, align: :center} do
            text content: "1", style: %{bold: true}
          end
        end
      end
    end
  end

  # Theming tab
  defp render_theming_tab(model, theme) do
    column style: %{padding: 1, gap: 1} do
      text content: "Theming System Showcase",
           style: %{fg: theme.accent, bold: true}

      text content: "Select a theme:"

      row style: %{gap: 2, margin_top: 1} do
        button label: "Dark Theme",
               variant: if(model.theme == :dark, do: :primary, else: :secondary),
               on_click: {:change_theme, :dark}

        button label: "Light Theme",
               variant: if(model.theme == :light, do: :primary, else: :secondary),
               on_click: {:change_theme, :light}

        button label: "Colorful Theme",
               variant: if(model.theme == :colorful, do: :primary, else: :secondary),
               on_click: {:change_theme, :colorful}
      end

      # Theme preview
      panel title: "Theme Preview", border: :single, style: %{margin_top: 2} do
        column style: %{padding: 1, gap: 1} do
          row style: %{gap: 1} do
            box bg: theme.bg, style: %{padding: 1, width: 10, align: :center} do
              text content: "Background", style: %{fg: theme.fg}
            end

            box bg: theme.fg, style: %{padding: 1, width: 10, align: :center} do
              text content: "Foreground", style: %{fg: theme.bg}
            end

            box bg: theme.accent, style: %{padding: 1, width: 10, align: :center} do
              text content: "Accent", style: %{fg: :white}
            end

            box bg: theme.panel_bg, style: %{padding: 1, width: 10, align: :center} do
              text content: "Panel", style: %{fg: theme.fg}
            end
          end
        end
      end
    end
  end
end

# Start the application
# Raxol.run(ArchitectureDemo, debug: true)
Raxol.Core.Runtime.start_application(ArchitectureDemo, debug: true) # Keep debug option if needed by runtime
