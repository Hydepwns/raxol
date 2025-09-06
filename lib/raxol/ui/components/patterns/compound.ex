defmodule Raxol.UI.Components.Patterns.Compound do
  @moduledoc """
  Compound Components pattern for Raxol UI.

  Compound components are a pattern where components are designed to work together
  as a cohesive unit. They share implicit state and provide a flexible, composable API.

  Think of HTML elements like `<select>` and `<option>`, or `<table>`, `<tr>`, and `<td>`.
  The parent component manages shared state and behavior, while child components
  handle their individual concerns.

  ## Benefits

  - Flexible composition
  - Implicit state sharing
  - Clean separation of concerns
  - Intuitive API design
  - Reusable sub-components

  ## Examples

      # Accordion compound component
      %{
        type: :accordion,
        children: [
          %{
            type: :accordion_item,
            attrs: %{value: "item1"},
            children: [
              %{type: :accordion_trigger, attrs: %{}, children: [text("Section 1")]},
              %{type: :accordion_content, children: [text("Content for section 1")]}
            ]
          },
          %{
            type: :accordion_item,
            attrs: %{value: "item2"},
            children: [
              %{type: :accordion_trigger, children: [text("Section 2")]},
              %{type: :accordion_content, children: [text("Content for section 2")]}
            ]
          }
        ]
      }
      
      # Dropdown compound component
      %{
        type: :dropdown,
        children: [
          %{type: :dropdown_trigger, children: [text("Options")]},
          %{
            type: :dropdown_content,
            children: [
              %{type: :dropdown_item, attrs: %{value: "edit"}, children: [text("Edit")]},
              %{type: :dropdown_item, attrs: %{value: "delete"}, children: [text("Delete")]},
              %{type: :dropdown_separator},
              %{type: :dropdown_item, attrs: %{value: "share"}, children: [text("Share")]}
            ]
          }
        ]
      }
  """

  alias Raxol.UI.State.{Context, Hooks}

  ## Accordion Compound Component

  @doc """
  Accordion root component that manages expanded state and provides context to children.

  ## Props
  - `:type` - :single (only one item open) or :multiple (multiple items can be open)
  - `:default_value` - Default expanded item(s)
  - `:collapsible` - Whether items can be collapsed (for :single type)
  - `:on_value_change` - Callback when expanded items change

  ## Context Provided
  - `:expanded_items` - Set of currently expanded item values
  - `:toggle_item` - Function to toggle an item's expanded state
  - `:accordion_type` - The accordion type (:single or :multiple)
  """
  def accordion do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        accordion_type = Map.get(props, :type, :single)

        default_value =
          Map.get(
            props,
            :default_value,
            case accordion_type do
              :single -> nil
              _ -> []
            end
          )

        collapsible = Map.get(props, :collapsible, true)
        on_value_change = Map.get(props, :on_value_change)
        children = Map.get(props, :children, [])

        # Initialize expanded state
        {expanded_items, set_expanded_items} =
          case accordion_type do
            :single ->
              Hooks.use_state(default_value)

            :multiple ->
              default_set =
                case is_list(default_value) do
                  true -> MapSet.new(default_value)
                  false -> MapSet.new()
                end

              Hooks.use_state(default_set)
          end

        # Toggle item function
        toggle_item =
          Hooks.use_callback(
            fn item_value ->
              case accordion_type do
                :single ->
                  new_value =
                    case expanded_items == item_value do
                      true ->
                        case collapsible do
                          true -> nil
                          false -> item_value
                        end

                      false ->
                        item_value
                    end

                  set_expanded_items.(new_value)

                  case on_value_change do
                    nil -> nil
                    callback -> callback.(new_value)
                  end

                :multiple ->
                  new_set =
                    case MapSet.member?(expanded_items, item_value) do
                      true -> MapSet.delete(expanded_items, item_value)
                      false -> MapSet.put(expanded_items, item_value)
                    end

                  set_expanded_items.(new_set)

                  case on_value_change do
                    nil -> nil
                    callback -> callback.(MapSet.to_list(new_set))
                  end
              end
            end,
            [accordion_type, expanded_items, collapsible, on_value_change]
          )

        # Create accordion context
        accordion_context = %{
          expanded_items: expanded_items,
          toggle_item: toggle_item,
          accordion_type: accordion_type
        }

        # Provide context to children
        Context.create_provider(
          Context.create_context(accordion_context, :accordion_context),
          accordion_context,
          children
        )
      end
    }
  end

  @doc """
  Accordion item that represents a single collapsible section.

  ## Props
  - `:value` - Unique identifier for this item (required)
  - `:disabled` - Whether this item is disabled
  """
  def accordion_item do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        value = Map.get(props, :value)
        disabled = Map.get(props, :disabled, false)
        children = Map.get(props, :children, [])

        case value do
          nil ->
            %{
              type: :text,
              attrs: %{content: "Error: accordion_item requires :value prop"}
            }

          _ ->
            # Get accordion context
            accordion_context = Hooks.use_context(:accordion_context) || %{}

            # Determine if this item is expanded
            is_expanded =
              case Map.get(accordion_context, :accordion_type) do
                :single ->
                  Map.get(accordion_context, :expanded_items) == value

                :multiple ->
                  MapSet.member?(Map.get(accordion_context, :expanded_items, MapSet.new()), value)
              end

            # Create item context
            item_context = %{
              value: value,
              is_expanded: is_expanded,
              disabled: disabled,
              toggle:
                case disabled do
                  true -> fn -> :ok end
                  false -> fn -> Map.get(accordion_context, :toggle_item, fn _ -> nil end).(value) end
                end
            }

            # Provide item context to children
            Context.create_provider(
              Context.create_context(item_context, :accordion_item_context),
              item_context,
              children
            )
        end
      end
    }
  end

  @doc """
  Accordion trigger that toggles the item's expanded state when clicked.
  """
  def accordion_trigger do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        children = Map.get(props, :children, [])

        # Get item context
        item_context = Hooks.use_context(:accordion_item_context) || %{}

        %{
          type: :button,
          attrs: %{
            disabled: Map.get(item_context, :disabled),
            on_click: Map.get(item_context, :toggle),
            aria_expanded: Map.get(item_context, :is_expanded),
            aria_controls: "accordion-content-#{Map.get(item_context, :value)}",
            style: %{
              display: :flex,
              align_items: :center,
              justify_content: :space_between,
              padding: 10,
              background:
                case Map.get(item_context, :is_expanded) do
                  true -> :primary_light
                  false -> :transparent
                end,
              border: :none,
              cursor:
                case Map.get(item_context, :disabled) do
                  true -> :not_allowed
                  _ -> :pointer
                end
            }
          },
          children:
            children ++
              [
                %{
                  type: :text,
                  attrs: %{
                    content:
                      case Map.get(item_context, :is_expanded) do
                        true -> "−"
                        false -> "+"
                      end,
                    style: %{font_weight: :bold}
                  }
                }
              ]
        }
      end
    }
  end

  @doc """
  Accordion content that is shown/hidden based on the item's expanded state.
  """
  def accordion_content do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        children = Map.get(props, :children, [])

        # Get item context
        item_context = Hooks.use_context(:accordion_item_context) || %{}

        render_accordion_content(
          Map.get(item_context, :is_expanded),
          Map.get(item_context, :value),
          children
        )
      end
    }
  end

  ## Dropdown Compound Component

  @doc """
  Dropdown root component that manages open state and provides context.

  ## Props
  - `:open` - Controlled open state
  - `:default_open` - Default open state (uncontrolled)
  - `:on_open_change` - Callback when open state changes
  - `:placement` - Dropdown placement (:bottom, :top, :left, :right)
  """
  def dropdown do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        controlled_open = Map.get(props, :open)
        default_open = Map.get(props, :default_open, false)
        on_open_change = Map.get(props, :on_open_change)
        placement = Map.get(props, :placement, :bottom)
        children = Map.get(props, :children, [])

        # Manage open state (controlled vs uncontrolled)
        {is_open, set_is_open} =
          manage_dropdown_state(controlled_open, on_open_change, default_open)

        # Close dropdown when clicking outside (placeholder implementation)
        Hooks.use_effect(
          fn -> setup_outside_click_handler(is_open, set_is_open) end,
          [is_open]
        )

        # Dropdown context
        dropdown_context = %{
          is_open: is_open,
          set_open: set_is_open,
          placement: placement,
          close: fn -> set_is_open.(false) end
        }

        Context.create_provider(
          Context.create_context(dropdown_context, :dropdown_context),
          dropdown_context,
          children
        )
      end
    }
  end

  @doc """
  Dropdown trigger that opens/closes the dropdown when clicked.
  """
  def dropdown_trigger do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        children = Map.get(props, :children, [])

        # Get dropdown context
        dropdown_context = Hooks.use_context(:dropdown_context) || %{}

        %{
          type: :button,
          attrs: %{
            on_click: fn ->
              Map.get(dropdown_context, :set_open, fn _ -> nil end).(not Map.get(dropdown_context, :is_open, false))
            end,
            aria_expanded: Map.get(dropdown_context, :is_open),
            aria_haspopup: true,
            style: %{
              position: :relative,
              cursor: :pointer
            }
          },
          children: children
        }
      end
    }
  end

  @doc """
  Dropdown content that contains the dropdown menu items.
  """
  def dropdown_content do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        children = Map.get(props, :children, [])

        # Get dropdown context
        dropdown_context = Hooks.use_context(:dropdown_context) || %{}

        render_dropdown_content(
          Map.get(dropdown_context, :is_open, false),
          Map.get(dropdown_context, :placement, :bottom),
          children
        )
      end
    }
  end

  @doc """
  Dropdown item that represents a single menu option.

  ## Props
  - `:value` - Value associated with this item
  - `:disabled` - Whether this item is disabled
  - `:on_select` - Callback when this item is selected
  """
  def dropdown_item do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        value = Map.get(props, :value)
        disabled = Map.get(props, :disabled, false)
        on_select = Map.get(props, :on_select)
        children = Map.get(props, :children, [])

        # Get dropdown context
        dropdown_context = Hooks.use_context(:dropdown_context) || %{}

        handle_select =
          create_dropdown_item_handler(
            disabled,
            on_select,
            value,
            dropdown_context
          )

        %{
          type: :button,
          attrs: %{
            role: :menuitem,
            disabled: disabled,
            on_click: handle_select,
            style: %{
              width: "100%",
              padding: 8,
              text_align: :left,
              background: :transparent,
              border: :none,
              cursor: get_cursor_style(disabled),
              opacity: get_opacity_style(disabled),
              hover: %{
                background: get_hover_background(disabled)
              }
            }
          },
          children: children
        }
      end
    }
  end

  @doc """
  Dropdown separator that visually separates groups of menu items.
  """
  def dropdown_separator do
    %{
      type: :compound_component,
      render_fn: fn _props, _context ->
        %{
          type: :box,
          attrs: %{
            role: :separator,
            style: %{
              height: 1,
              background: "#e0e0e0",
              margin: %{vertical: 4}
            }
          }
        }
      end
    }
  end

  ## Tabs Compound Component

  @doc """
  Tabs root component that manages active tab state.

  ## Props
  - `:value` - Controlled active tab value
  - `:default_value` - Default active tab (uncontrolled)
  - `:on_value_change` - Callback when active tab changes
  - `:orientation` - :horizontal or :vertical
  """
  def tabs do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        controlled_value = Map.get(props, :value)
        default_value = Map.get(props, :default_value)
        on_value_change = Map.get(props, :on_value_change)
        orientation = Map.get(props, :orientation, :horizontal)
        children = Map.get(props, :children, [])

        {active_tab, set_active_tab} =
          manage_tabs_state(controlled_value, on_value_change, default_value)

        tabs_context = %{
          active_tab: active_tab,
          set_active_tab: set_active_tab,
          orientation: orientation
        }

        Context.create_provider(
          Context.create_context(tabs_context, :tabs_context),
          tabs_context,
          children
        )
      end
    }
  end

  @doc """
  Tabs list that contains the tab triggers.
  """
  def tabs_list do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        children = Map.get(props, :children, [])

        # Get tabs context
        tabs_context = Hooks.use_context(:tabs_context)

        container_type =
          case Map.get(tabs_context || %{}, :orientation) do
            :horizontal -> :row
            :vertical -> :column
          end

        %{
          type: container_type,
          attrs: %{
            role: :tablist,
            aria_orientation: Map.get(tabs_context || %{}, :orientation),
            style: %{
              border_bottom:
                case Map.get(tabs_context || %{}, :orientation) do
                  :horizontal -> "1px solid #e0e0e0"
                  _ -> :none
                end,
              border_right:
                case Map.get(tabs_context || %{}, :orientation) do
                  :vertical -> "1px solid #e0e0e0"
                  _ -> :none
                end
            }
          },
          children: children
        }
      end
    }
  end

  @doc """
  Tab trigger that switches to a specific tab when clicked.

  ## Props
  - `:value` - The tab value this trigger activates (required)
  - `:disabled` - Whether this tab is disabled
  """
  def tabs_trigger do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        value = Map.get(props, :value)
        disabled = Map.get(props, :disabled, false)
        children = Map.get(props, :children, [])

        case value do
          nil ->
            render_tabs_trigger_error()

          _ ->
            # Get tabs context
            tabs_context = Hooks.use_context(:tabs_context)
            is_active = Map.get(tabs_context || %{}, :active_tab) == value

            handle_click =
              create_tabs_click_handler(disabled, value, tabs_context)

            %{
              type: :button,
              attrs: %{
                role: :tab,
                "aria-selected": is_active,
                "aria-controls": "tab-panel-#{value}",
                disabled: disabled,
                on_click: handle_click,
                style: %{
                  padding: 12,
                  background: case is_active do
                    true -> :white
                    false -> :transparent
                  end,
                  border: :none,
                  border_bottom:
                    case {is_active, Map.get(tabs_context || %{}, :orientation)} do
                      {true, :horizontal} -> "2px solid #007acc"
                      _ -> :none
                    end,
                  border_right:
                    case {is_active, Map.get(tabs_context || %{}, :orientation)} do
                      {true, :vertical} -> "2px solid #007acc"
                      _ -> :none
                    end,
                  cursor: case disabled do
                    true -> :not_allowed
                    false -> :pointer
                  end,
                  opacity: case disabled do
                    true -> 0.5
                    false -> 1.0
                  end,
                  font_weight: case is_active do
                    true -> :bold
                    false -> :normal
                  end
                }
              },
              children: children
            }
        end
      end
    }
  end

  @doc """
  Tab content panel that displays content for a specific tab.

  ## Props
  - `:value` - The tab value this content is associated with (required)
  """
  def tabs_content do
    %{
      type: :compound_component,
      render_fn: fn props, _context ->
        value = Map.get(props, :value)
        children = Map.get(props, :children, [])

        case value do
          nil -> render_tabs_content_error()
          _ -> render_tabs_content_panel(value, children)
        end
      end
    }
  end

  # Helper functions (placeholders)

  defp manage_dropdown_state(controlled_open, on_open_change, _default_open)
       when controlled_open != nil do
    {controlled_open, create_controlled_change_handler(on_open_change)}
  end

  defp manage_dropdown_state(_controlled_open, _on_open_change, default_open) do
    Hooks.use_state(default_open)
  end

  defp create_controlled_change_handler(nil), do: fn _new_open -> :ok end

  defp create_controlled_change_handler(on_open_change) do
    fn new_open -> on_open_change.(new_open) end
  end

  defp setup_outside_click_handler(false, _set_is_open), do: nil

  defp setup_outside_click_handler(true, set_is_open) do
    outside_click_handler = fn _event -> set_is_open.(false) end
    register_outside_click_listener(outside_click_handler)
    fn -> unregister_outside_click_listener(outside_click_handler) end
  end

  defp render_accordion_content(false, _value, _children) do
    %{type: :text, attrs: %{content: "", style: %{display: :none}}}
  end

  defp render_accordion_content(true, value, children) do
    %{
      type: :column,
      attrs: %{
        id: "accordion-content-#{value}",
        style: %{
          padding: 10,
          border_top: "1px solid #e0e0e0"
        }
      },
      children: children
    }
  end

  defp render_dropdown_content(false, _placement, _children) do
    %{type: :text, attrs: %{content: "", style: %{display: :none}}}
  end

  defp render_dropdown_content(true, placement, children) do
    %{
      type: :column,
      attrs: %{
        role: :menu,
        style: %{
          position: :absolute,
          top: get_dropdown_position(:top, placement),
          bottom: get_dropdown_position(:bottom, placement),
          left: get_dropdown_position(:left, placement),
          right: get_dropdown_position(:right, placement),
          z_index: 1000,
          background: :white,
          border: "1px solid #e0e0e0",
          border_radius: 4,
          box_shadow: "0 2px 8px rgba(0,0,0,0.15)",
          padding: 4,
          min_width: 150
        }
      },
      children: children
    }
  end

  defp get_dropdown_position(:top, :top), do: :auto
  defp get_dropdown_position(:top, _), do: "100%"
  defp get_dropdown_position(:bottom, :top), do: "100%"
  defp get_dropdown_position(:bottom, _), do: :auto
  defp get_dropdown_position(:left, :left), do: :auto
  defp get_dropdown_position(:left, :right), do: "100%"
  defp get_dropdown_position(:left, _), do: 0
  defp get_dropdown_position(:right, :right), do: :auto
  defp get_dropdown_position(:right, :left), do: "100%"
  defp get_dropdown_position(:right, _), do: :auto

  defp create_dropdown_item_handler(
         disabled,
         on_select,
         value,
         dropdown_context
       ) do
    Hooks.use_callback(
      fn ->
        handle_dropdown_item_select(
          disabled,
          on_select,
          value,
          dropdown_context
        )
      end,
      [disabled, on_select, value]
    )
  end

  defp handle_dropdown_item_select(true, _on_select, _value, _dropdown_context),
    do: :ok

  defp handle_dropdown_item_select(false, on_select, value, dropdown_context) do
    execute_on_select(on_select, value)
    dropdown_context.close.()
  end

  defp execute_on_select(nil, _value), do: :ok
  defp execute_on_select(on_select, value), do: on_select.(value)

  defp manage_tabs_state(controlled_value, on_value_change, _default_value)
       when controlled_value != nil do
    {controlled_value, create_tabs_change_handler(on_value_change)}
  end

  defp manage_tabs_state(_controlled_value, _on_value_change, default_value) do
    Hooks.use_state(default_value)
  end

  defp create_tabs_change_handler(nil), do: fn _new_value -> :ok end

  defp create_tabs_change_handler(on_value_change) do
    fn new_value -> on_value_change.(new_value) end
  end

  defp render_tabs_trigger_error do
    %{
      type: :text,
      attrs: %{content: "Error: tabs_trigger requires :value prop"}
    }
  end

  defp create_tabs_click_handler(disabled, value, tabs_context) do
    Hooks.use_callback(
      fn -> handle_tabs_click(disabled, value, tabs_context) end,
      [disabled, value]
    )
  end

  defp handle_tabs_click(true, _value, _tabs_context), do: :ok

  defp handle_tabs_click(false, value, tabs_context) do
    Map.get(tabs_context || %{}, :set_active_tab, fn _ -> nil end).(value)
  end

  defp get_cursor_style(true), do: :not_allowed
  defp get_cursor_style(false), do: :pointer

  defp get_opacity_style(true), do: 0.5
  defp get_opacity_style(false), do: 1.0

  defp get_hover_background(true), do: :transparent
  defp get_hover_background(false), do: :primary_light

  # Unused function - commented out to reduce warnings
  # defp render_tabs_trigger_content(
  #        is_active,
  #        disabled,
  #        tabs_context,
  #        handle_click,
  #        children,
  #        value
  #      ) do
  #   %{
  #     type: :button,
  #     attrs: %{
  #       role: :tab,
  #       "aria-selected": is_active,
  #       "aria-controls": "tab-panel-#{value}",
  #       disabled: disabled,
  #       on_click: handle_click,
  #       style: %{
  #         padding: 12,
  #         background: get_tab_background(is_active),
  #         border: :none,
  #         border_bottom:
  #           get_tab_border_bottom(is_active, tabs_context.orientation),
  #         border_right:
  #           get_tab_border_right(is_active, tabs_context.orientation),
  #         cursor: get_cursor_style(disabled),
  #         opacity: get_opacity_style(disabled),
  #         font_weight: get_font_weight(is_active)
  #       }
  #     },
  #     children: children
  #   }
  # end

  # defp get_tab_background(true), do: :white
  # defp get_tab_background(false), do: :transparent

  # defp get_tab_border_bottom(true, :horizontal), do: "2px solid #007acc"
  # defp get_tab_border_bottom(_, _), do: :none

  # defp get_tab_border_right(true, :vertical), do: "2px solid #007acc"
  # defp get_tab_border_right(_, _), do: :none

  # defp get_font_weight(true), do: :bold
  # defp get_font_weight(false), do: :normal

  defp render_tabs_content_error do
    %{
      type: :text,
      attrs: %{content: "Error: tabs_content requires :value prop"}
    }
  end

  defp render_tabs_content_panel(value, children) do
    tabs_context = Hooks.use_context(:tabs_context)
    is_active = Map.get(tabs_context || %{}, :active_tab) == value
    render_tabs_panel_if_active(is_active, value, children)
  end

  defp render_tabs_panel_if_active(false, _value, _children) do
    %{type: :text, attrs: %{content: "", style: %{display: :none}}}
  end

  defp render_tabs_panel_if_active(true, value, children) do
    %{
      type: :column,
      attrs: %{
        role: :tabpanel,
        id: "tab-panel-#{value}",
        "aria-labelledby": "tab-#{value}",
        style: %{
          padding: 16
        }
      },
      children: children
    }
  end

  defp register_outside_click_listener(_handler) do
    # This would integrate with the actual event system
    :ok
  end

  defp unregister_outside_click_listener(_handler) do
    # This would integrate with the actual event system
    :ok
  end
end
