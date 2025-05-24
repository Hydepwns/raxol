# Component Showcase Example (Moved to lib/raxol/examples/)
#
# This example demonstrates various Raxol components, layouts, and features.

defmodule Raxol.Examples.ComponentShowcase do
  use Raxol.UI.Components.Base.Component
  require Logger
  require Raxol.View.Elements
  import Raxol.View.Elements

  @impl Raxol.UI.Components.Base.Component
  def init(_props) do
    initial_assigns = %{
      active_tab: :components,
      progress: 0,
      input_value: "",
      checkbox_value: false,
      theme_id: :default,
      multi_line_value:
        "Initial text for\nMultiLineInput component.\n\nIt supports multiple lines!",
      table_data: [
        %{id: 1, name: "Alice", role: "Admin", status: "Active"},
        %{id: 2, name: "Bob", role: "User", status: "Inactive"},
        %{id: 3, name: "Charlie", role: "User", status: "Active"},
        %{id: 4, name: "David", role: "Moderator", status: "Active"}
      ],
      select_list_options: [
        "Option A",
        "Option B",
        "Option C",
        "Longer Option D"
      ],
      selected_option: nil,
      is_loading: false,
      is_modal_open: false
    }

    initial_assigns
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event("increment_progress", _params, state) do
    new_progress = min(state.progress + 10, 100)
    new_state = Map.put(state, :progress, new_progress)
    {new_state, []}
  end

  def handle_event("reset_progress", _params, state) do
    new_state = Map.put(state, :progress, 0)
    {new_state, []}
  end

  def handle_event("update_input", %{"value" => value}, state) do
    new_state = Map.put(state, :input_value, value)
    {new_state, []}
  end

  def handle_event("toggle_checkbox", %{"checked" => checked}, state) do
    new_state = Map.put(state, :checkbox_value, checked)
    {new_state, []}
  end

  def handle_event("update_multi_line", %{"value" => value}, state) do
    new_state = Map.put(state, :multi_line_value, value)
    {new_state, []}
  end

  def handle_event("select_option", %{"value" => option}, state) do
    new_state = Map.put(state, :selected_option, option)
    {new_state, []}
  end

  def handle_event("toggle_loading", _params, state) do
    new_state = Map.put(state, :is_loading, !state.is_loading)
    {new_state, []}
  end

  def handle_event("open_modal", _params, state) do
    new_state = Map.put(state, :is_modal_open, true)
    {new_state, []}
  end

  def handle_event("close_modal", _params, state) do
    new_state = Map.put(state, :is_modal_open, false)
    {new_state, []}
  end

  def handle_event("change_tab", %{"tab" => tab_str}, state) do
    tab = String.to_existing_atom(tab_str)
    new_state = Map.put(state, :active_tab, tab)
    {new_state, []}
  end

  def handle_event("change_theme", %{"theme" => theme_str}, state) do
    theme_id = String.to_existing_atom(theme_str)
    new_state = Map.put(state, :theme_id, theme_id)
    {new_state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def render(assigns, _context) do
    theme = get_theme_preview_colors(assigns.theme_id)

    [
      if assigns.is_modal_open do
        %{
          type: Raxol.UI.Components.Modal,
          id: "my_modal",
          assigns: %{
            title: "My Modal Title",
            width: 40,
            height: 10,
            events: [close: :close_modal]
          },
          children: [
            column padding: 1, gap: 1 do
              label("This is the content of the modal.")

              %{
                type: Raxol.UI.Components.Input.Button,
                id: :modal_close_button,
                assigns: %{
                  label: "Close Me",
                  on_click: :close_modal,
                  preset: :secondary
                }
              }
            end
          ]
        }
      end,
      column do
        panel title: "Raxol Component Showcase", border: :single do
          row align: :center, justify: :space_around, padding: {{0, 1}} do
            %{
              type: Raxol.UI.Components.Input.Button,
              id: :tab_components,
              assigns: %{
                label: "Components",
                style: style_for_tab(:components, assigns.active_tab, theme),
                on_click: {:change_tab, %{"tab" => :components}}
              }
            }

            %{
              type: Raxol.UI.Components.Input.Button,
              id: :tab_layout,
              assigns: %{
                label: "Layout",
                style: style_for_tab(:layout, assigns.active_tab, theme),
                on_click: {:change_tab, %{"tab" => :layout}}
              }
            }

            %{
              type: Raxol.UI.Components.Input.Button,
              id: :tab_theming,
              assigns: %{
                label: "Theming",
                style: style_for_tab(:theming, assigns.active_tab, theme),
                on_click: {:change_tab, %{"tab" => :theming}}
              }
            }
          end
        end

        panel height: :fill, border: :none do
          case assigns.active_tab do
            :components -> render_components_tab(assigns, theme)
            :layout -> render_layout_tab(assigns, theme)
            :theming -> render_theming_tab(assigns, theme)
          end
        end

        panel border: :single do
          row align: :center, padding: {{0, 1}} do
            label(content: "Press Ctrl+C to exit")
          end
        end

        column margin_top: 1 do
          label(content: "Modal:", style: [:bold])
          button(label: "Open Modal", on_click: :open_modal)
        end
      end
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp style_for_tab(tab_id, active_tab, theme) do
    if tab_id == active_tab do
      [bg: theme.accent_bg, fg: theme.accent_fg]
    else
      []
    end
  end

  defp render_components_tab(assigns, theme) do
    column padding: 1, gap: 1 do
      label(
        content: "Component System Showcase",
        style: [[:fg, theme.accent_fg], :bold]
      )

      row gap: 2 do
        column size: :auto do
          label(content: "Buttons:", style: [:bold])

          %{
            type: Raxol.UI.Components.Input.Button,
            id: :button_primary,
            assigns: %{label: "Primary", preset: :primary}
          }

          %{
            type: Raxol.UI.Components.Input.Button,
            id: :button_secondary,
            assigns: %{label: "Secondary", preset: :secondary}
          }

          %{
            type: Raxol.UI.Components.Input.Button,
            id: :button_danger,
            assigns: %{label: "Danger", preset: :danger}
          }
        end

        column size: :auto do
          label(content: "Progress:", style: [:bold])

          %{
            type: Raxol.UI.Components.Display.Progress,
            id: :progress_bar,
            assigns: %{value: assigns.progress, width: 20}
          }

          row gap: 1 do
            %{
              type: Raxol.UI.Components.Input.Button,
              id: :button_progress_inc,
              assigns: %{label: "+", on_click: :increment_progress}
            }

            %{
              type: Raxol.UI.Components.Input.Button,
              id: :button_progress_reset,
              assigns: %{label: "Reset", on_click: :reset_progress}
            }
          end
        end

        column size: :auto do
          label(content: "Spinner:", style: [:bold])

          row gap: 1, align: :center do
            if assigns.is_loading do
              %{
                type: Raxol.UI.Components.Display.Spinner,
                id: :spinner_loading,
                assigns: %{label: "Loading..."}
              }
            end

            %{
              type: Raxol.UI.Components.Input.Button,
              id: :button_spinner_toggle,
              assigns: %{label: "Toggle", on_click: :toggle_loading}
            }
          end
        end
      end

      row gap: 2, margin_top: 1 do
        column size: :auto do
          label(content: "Text Input:", style: [:bold])

          %{
            type: Raxol.UI.Components.Input.TextInput,
            id: :my_input,
            assigns: %{
              value: assigns.input_value,
              width: 30,
              events: [change: :update_input]
            }
          }

          label(content: "Current Value: #{assigns.input_value}")
        end

        column size: :auto do
          label(content: "Checkbox:", style: [:bold])

          %{
            type: Raxol.UI.Components.Input.Checkbox,
            id: :my_checkbox,
            assigns: %{
              label: "Enable Feature",
              checked: assigns.checkbox_value,
              events: [toggle: :toggle_checkbox]
            }
          }

          label(content: "Checked: #{assigns.checkbox_value}")
        end
      end

      column gap: 1, margin_top: 1 do
        label(content: "Multi-Line Input:", style: [:bold])

        %{
          type: Raxol.UI.Components.Input.MultiLineInput,
          id: :my_multi_line,
          assigns: %{
            value: assigns.multi_line_value,
            width: 40,
            height: 5,
            events: [change: :update_multi_line]
          }
        }
      end

      column gap: 1, margin_top: 1 do
        label(content: "Table:", style: [:bold])

        %{
          type: Raxol.UI.Components.Display.Table,
          id: :my_table,
          assigns: %{
            headers: ["ID", "Name", "Role", "Status"],
            data: assigns.table_data,
            columns: [:id, :name, :role, :status],
            width: 60
          }
        }
      end

      column gap: 1, margin_top: 1 do
        label(content: "Select List:", style: [:bold])

        %{
          type: Raxol.UI.Components.Input.SelectList,
          id: :my_select_list,
          assigns: %{
            options: assigns.select_list_options,
            selected: assigns.selected_option,
            width: 30,
            max_height: 5,
            events: [select: :select_option]
          }
        }

        label(content: "Selected: #{inspect(assigns.selected_option)}")
      end
    end
  end

  defp render_layout_tab(_assigns, theme) do
    column padding: 1 do
      label(
        content: "Layout System Showcase (Coming Soon)",
        style: [[:fg, theme.accent_fg], :bold]
      )

      label(content: "Examples of row, column, grid, panel, etc.")
    end
  end

  defp render_theming_tab(_assigns, theme) do
    column padding: 1 do
      label(
        content: "Theming Showcase (Coming Soon)",
        style: [[:fg, theme.accent_fg], :bold]
      )

      label(content: "Demonstrate different themes and custom styling.")
    end
  end

  defp get_theme_preview_colors(:default) do
    %{
      accent_bg: :blue,
      accent_fg: :white,
      default_bg: :default,
      default_fg: :default
    }
  end

  defp get_theme_preview_colors(:dark) do
    %{
      accent_bg: :cyan,
      accent_fg: :black,
      default_bg: :black,
      default_fg: :white
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(message, state) do
    # NOTE: Implement message handling for this component if needed in the future.
    Logger.warning(
      "Unhandled update message in ComponentShowcase: #{inspect(message)}",
      []
    )

    state
  end
end
