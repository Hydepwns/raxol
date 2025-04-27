#!/usr/bin/env elixir
# Component Showcase Demo
#
# This example demonstrates various Raxol components, layouts, and features.
#
# Run with: mix run examples/showcase/component_showcase.exs

defmodule ComponentShowcase do
  # Use the standard Application behaviour
  use Raxol.Core.Runtime.Application
  # Import View DSL macros and potentially component functions
  import Raxol.View.Elements
  # Alias necessary components
  alias Raxol.UI.Components.Input.SelectList
  alias Raxol.UI.Components.Display.Progress
  alias Raxol.Components.Progress.Spinner # Alias the Spinner from its current location
  alias Raxol.Components.Modal # Alias the Modal from its current location

  @impl true
  def init(_context) do
    # Add :ok tuple to return value
    {:ok,
     %{
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
  end

  @impl true
  def update(message, model) do
    # Add :ok tuple and empty command list to return value
    case message do
      :increment_progress ->
        new_progress = min(model.progress + 10, 100)
        {:ok, %{model | progress: new_progress}, []}

      :reset_progress ->
        {:ok, %{model | progress: 0}, []}

      {:update_input, value} ->
        {:ok, %{model | input_value: value}, []}

      {:toggle_checkbox} ->
        {:ok, %{model | checkbox_value: !model.checkbox_value}, []}

      {:update_multi_line, value} -> # Add handler for MultiLineInput
        {:ok, %{model | multi_line_value: value}, []}

      {:select_option, option} -> # Add handler for SelectList
        {:ok, %{model | selected_option: option}, []}

      {:toggle_loading} -> # Add handler for Spinner
        {:ok, %{model | is_loading: !model.is_loading}, []}

      :open_modal -> # Add handler for Modal
        {:ok, %{model | is_modal_open: true}, []}

      :close_modal -> # Add handler for Modal
        {:ok, %{model | is_modal_open: false}, []}

      {:change_tab, tab} ->
        {:ok, %{model | active_tab: tab}, []}

      {:change_theme, theme_id} ->
        # TODO: Ideally, send a command to change the actual theme
        # For now, just update the state for preview purposes
        {:ok, %{model | theme_id: theme_id}, []}

      _ ->
        # Ignore unknown messages
        {:ok, model, []}
    end
  end

  @impl true
  # Renamed from render/1 to view/1
  def view(model) do
    # TODO: Replace hardcoded themes with ColorSystem calls
    theme = get_theme_preview_colors(model.theme_id)

    # Main layout - Use `view` macro instead of bare `column`
    view do
      # Render Modal conditionally ON TOP of other elements
      if model.is_modal_open do
        Modal.render(%{
          id: :my_modal,
          title: "My Modal Title",
          on_close: :close_modal,
          # Assuming content is passed as view elements
          content: column style: %{padding: 1, gap: 1} do
            text(content: "This is the content of the modal.")
            button(label: "Close Me", on_click: :close_modal, style: [[:preset, :secondary]])
          end,
          style: %{width: 40, height: 10} # Example style
        })
      end

      column do
        # Header with tabs
        panel title: "Raxol Component Showcase", border: :single do
          row style: %{align: :center, justify: :space_around, padding: {0, 1}} do
            button(
              label: "Components",
              # Use theme color
              style: if(model.active_tab == :components, do: [[:bg, {:accent, :bg}], [:fg, {:accent, :fg}]], else: []),
              on_click: {:change_tab, :components}
            )

            button(
              label: "Layout",
              style: if(model.active_tab == :layout, do: [[:bg, {:accent, :bg}], [:fg, {:accent, :fg}]], else: []),
              on_click: {:change_tab, :layout}
            )

            button(
              label: "Theming",
              style: if(model.active_tab == :theming, do: [[:bg, {:accent, :bg}], [:fg, {:accent, :fg}]], else: []),
              on_click: {:change_tab, :theming}
            )
          end
        end

        # Content area
        panel height: :fill, border: :none do # Use :fill for dynamic height
          case model.active_tab do
            :components -> render_components_tab(model, theme)
            :layout -> render_layout_tab(model, theme)
            :theming -> render_theming_tab(model, theme)
          end
        end

        # Footer
        panel border: :single do
          row style: %{align: :center, padding: {0, 1}} do
            text(content: "Press Ctrl+C to exit")
          end
        end

        # Add button to open Modal
        column style: %{margin_top: 1} do
          label(content: "Modal:", style: [:bold])
          button(label: "Open Modal", on_click: :open_modal)
        end
      end
    end
  end

  # --- Tab Rendering Functions ---
  # (Keep existing structure, but will need updates for components/theming)

  # Components tab
  defp render_components_tab(model, theme) do
    column style: %{padding: 1, gap: 1} do
      label(content: "Component System Showcase", style: [[:fg, :accent_fg], :bold])

      # Use macros from View.Elements
      row style: %{gap: 2} do
        column size: :auto do
          label(content: "Buttons:", style: [:bold])
          button(label: "Primary", style: [[:preset, :primary]]) # Assuming style presets
          button(label: "Secondary", style: [[:preset, :secondary]])
          button(label: "Danger", style: [[:preset, :danger]])
        end

        column size: :auto do
          label(content: "Progress:", style: [:bold])
          # Progress is likely a separate component module, keep alias/render for now
          # TODO: Verify Raxol.UI.Components.Display.Progress path and usage
          Progress.render(%{
            value: model.progress,
            max: 100,
            label: "#{model.progress}%",
            style: %{width: 20} # Use map style here for component render
          })
          row style: %{gap: 1} do
            button(label: "Increment", on_click: :increment_progress)
            button(label: "Reset", on_click: :reset_progress, style: [[:preset, :secondary]])
          end
        end
      end

      row style: %{gap: 2, margin_top: 1} do
        column size: :auto do
          label(content: "Text Input:", style: [:bold])
          # Use text_input macro
          text_input(
            id: :my_input, # Add ID if needed by runtime
            value: model.input_value,
            placeholder: "Enter text here...",
            on_change: {:update_input},
            style: [[:width, 30]]
          )
        end

        column size: :auto do
          label(content: "Checkbox:", style: [:bold])
          row style: %{align_items: :center} do
            # Use checkbox macro
            checkbox(
              id: :my_checkbox, # Add ID if needed by runtime
              checked: model.checkbox_value,
              # NOTE: Macro doc shows on_toggle, example used on_change. Assuming on_change.
              on_change: {:toggle_checkbox}
            )
            # Use label macro for associated text
            label(content: " Enable feature")
          end
        end
      end

      # Add MultiLineInput
      column style: %{margin_top: 1} do
        label(content: "Multi-Line Input:", style: [:bold])
        multi_line_input(
          id: :my_multi_line_input, # Add ID if needed by runtime
          value: model.multi_line_value,
          on_change: {:update_multi_line}, # Assuming :update_multi_line is the event name
          style: [[:width, 40], [:height, 5], [:border, :single]] # Basic styling
        )
      end

      # Add Table
      column style: %{margin_top: 1} do
        label(content: "Table:", style: [:bold])
        table(
          id: :my_table, # Add ID if needed by runtime
          data: model.table_data,
          columns: [
            %{header: "ID", key: :id, width: 5},
            %{header: "Name", key: :name, width: 15},
            %{header: "Role", key: :role, width: 15},
            %{header: "Status", key: :status, width: 10}
            # TODO: Add styling/alignment options if available
          ],
          style: [[:width, 50], [:height, 6], [:border, :single]] # Basic styling
        )
      end

      # Add SelectList
      column style: %{margin_top: 1} do
        label(content: "Select List:", style: [:bold])
        # No macro, call render directly
        SelectList.render(%{
          id: :my_select_list, # ID for the component
          options: model.select_list_options,
          selected: model.selected_option,
          on_select: {:select_option}, # Event name when an option is selected
          style: %{width: 25, height: 5} # Basic styling
        })
        # Display the selected option
        text(content: "Selected: #{inspect(model.selected_option)}", style: [[:margin_top, 1]]
      end

      # Add Spinner
      column style: %{margin_top: 1} do
        label(content: "Spinner:", style: [:bold])
        row style: %{gap: 2, align_items: :center} do
          button(label: "Toggle Loading", on_click: :toggle_loading)
          if model.is_loading do
            # No macro, call render directly
            Spinner.render(%{
              # Assuming Spinner takes minimal props, maybe just style?
              # Check Spinner module for actual props if this fails.
              style: %{color: :accent} # Example style
            })
          else
            text(content: "(Not loading)")
          end
        end
      end
    end
  end

  # Layout tab
  defp render_layout_tab(model, _theme) do # Mark theme as unused for now
    column style: %{padding: 1, gap: 1} do
      # Use ColorSystem directly for tab title accent
      label(content: "Layout System Showcase", style: [[:fg, Raxol.Core.ColorSystem.get(:default, :accent_fg)], :bold])

      panel title: "Grid Layout", border: :single, style: [[:margin_top, 1]] do
        grid columns: 3, style: %{gap: 1, padding: 1} do
          for i <- 1..9 do
            # Use ColorSystem directly for grid item background
            box style: [[:bg, Raxol.Core.ColorSystem.get(:default, :accent_bg)], [:padding, 1], [:align, :center]] do
              label(content: "#\{i}", style: [:bold])
            end
          end
        end
      end

      panel title: "Flex Layout (Row)", border: :single, style: [[:margin_top, 1]] do
        row style: %{gap: 1, padding: 1} do
           # Use ColorSystem directly for box background
          box size: 1, style: [[:bg, Raxol.Core.ColorSystem.get(:default, :accent_bg)], [:padding, 1], [:align, :center]] do
            label(content: "1", style: [:bold])
          end
          box size: 2, style: [[:bg, Raxol.Core.ColorSystem.get(:default, :accent_bg)], [:padding, 1], [:align, :center]] do
            label(content: "2", style: [:bold])
          end
          box size: 1, style: [[:bg, Raxol.Core.ColorSystem.get(:default, :accent_bg)], [:padding, 1], [:align, :center]] do
            label(content: "1", style: [:bold])
          end
        end
      end
      # TODO: Add column layout example
    end
  end

  # Theming tab
  defp render_theming_tab(model, _theme) do # Mark theme argument as unused
    # Get the selected theme_id from the model
    theme_id = model.theme_id

    column style: %{padding: 1, gap: 1} do
      # Use ColorSystem for title accent
      label(content: "Theming System Showcase", style: [[:fg, Raxol.Core.ColorSystem.get(theme_id, :accent_fg) || :default], :bold]) # Added fallback

      label(content: "Select a theme (preview only):")

      row style: %{gap: 2, margin_top: 1} do
        # Use ColorSystem for button active state preview
        default_button_style =
          if model.theme_id == :default,
             do: [[:bg, Raxol.Core.ColorSystem.get(:default, :accent) || :default], [:fg, Raxol.Core.ColorSystem.get(:default, :accent_fg) || :default]], # Added fallback
             else: []
        dark_button_style =
           if model.theme_id == :dark,
             do: [[:bg, Raxol.Core.ColorSystem.get(:dark, :accent) || :default], [:fg, Raxol.Core.ColorSystem.get(:dark, :accent_fg) || :default]], # Added fallback
             else: []

        # TODO: Send command to actually change theme if possible
        button(
          label: "Default",
          style: default_button_style,
          on_click: {:change_theme, :default}
        )
        button(
          label: "Dark",
          style: dark_button_style,
          on_click: {:change_theme, :dark}
        )
        # Add more themes if available (e.g., :light, :high_contrast)
      end

      # Theme preview using ColorSystem.get/2
      panel title: "Theme Preview", border: :single, style: [[:margin_top, 2]] do
        column style: %{padding: 1, gap: 1} do
          row style: %{gap: 1} do
            # Get semantic colors for the selected theme
            bg_color = Raxol.Core.ColorSystem.get(theme_id, :background) || :default
            fg_color = Raxol.Core.ColorSystem.get(theme_id, :foreground) || :default
            accent_color = Raxol.Core.ColorSystem.get(theme_id, :accent) || :default
            accent_fg_color = Raxol.Core.ColorSystem.get(theme_id, :accent_fg) || fg_color # Fallback to fg
            panel_bg_color = Raxol.Core.ColorSystem.get(theme_id, :panel_bg) || bg_color # Fallback to bg

            box style: [[:bg, bg_color], [:padding, 1], [:width, 10], [:align, :center]] do
              label(content: "BG", style: [[:fg, fg_color]])
            end
            box style: [[:bg, fg_color], [:padding, 1], [:width, 10], [:align, :center]] do
              label(content: "FG", style: [[:fg, bg_color]])
            end
            box style: [[:bg, accent_color], [:padding, 1], [:width, 10], [:align, :center]] do
              label(content: "Accent", style: [[:fg, accent_fg_color]])
            end
            box style: [[:bg, panel_bg_color], [:padding, 1], [:width, 10], [:align, :center]] do
              label(content: "Panel BG", style: [[:fg, fg_color]])
            end
          end
          label(content: "Note: Colors fetched using ColorSystem.get/2 for theme '#{theme_id}'.", style: [:italic])
        end
      end
    end
  end

  # Helper for theme preview - Replace with ColorSystem later
  # defp get_theme_preview_colors(theme_id) do <-- Remove this function
  #   case theme_id do
  #     :dark ->
  #       %{bg: :black, fg: :white, accent: :blue, panel_bg: {:grey, 30}, fg_on_accent: :white}
  #
  #     :light ->
  #       %{bg: :white, fg: :black, accent: :blue, panel_bg: {:grey, 90}, fg_on_accent: :white}
  #
  #     _ -> # Default
  #       %{bg: :default, fg: :default, accent: :cyan, panel_bg: :default, fg_on_accent: :black}
  #   end
  # end
end

# Start the application
Raxol.Core.Runtime.Lifecycle.start_application(ComponentShowcase)
