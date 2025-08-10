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
            if(accordion_type == :single, do: nil, else: [])
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
                if is_list(default_value),
                  do: MapSet.new(default_value),
                  else: MapSet.new()

              Hooks.use_state(default_set)
          end

        # Toggle item function
        toggle_item =
          Hooks.use_callback(
            fn item_value ->
              case accordion_type do
                :single ->
                  new_value =
                    if expanded_items == item_value do
                      if collapsible, do: nil, else: item_value
                    else
                      item_value
                    end

                  set_expanded_items.(new_value)
                  if on_value_change, do: on_value_change.(new_value)

                :multiple ->
                  new_set =
                    if MapSet.member?(expanded_items, item_value) do
                      MapSet.delete(expanded_items, item_value)
                    else
                      MapSet.put(expanded_items, item_value)
                    end

                  set_expanded_items.(new_set)

                  if on_value_change,
                    do: on_value_change.(MapSet.to_list(new_set))
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

        if value do
          # Get accordion context
          accordion_context = Hooks.use_context(:accordion_context)

          # Determine if this item is expanded
          is_expanded =
            case accordion_context.accordion_type do
              :single ->
                accordion_context.expanded_items == value

              :multiple ->
                MapSet.member?(accordion_context.expanded_items, value)
            end

          # Create item context
          item_context = %{
            value: value,
            is_expanded: is_expanded,
            disabled: disabled,
            toggle:
              if(disabled,
                do: fn -> :ok end,
                else: fn -> accordion_context.toggle_item.(value) end
              )
          }

          # Provide item context to children
          Context.create_provider(
            Context.create_context(item_context, :accordion_item_context),
            item_context,
            children
          )
        else
          %{
            type: :text,
            attrs: %{content: "Error: accordion_item requires :value prop"}
          }
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
        item_context = Hooks.use_context(:accordion_item_context)

        %{
          type: :button,
          attrs: %{
            disabled: item_context.disabled,
            on_click: item_context.toggle,
            aria_expanded: item_context.is_expanded,
            aria_controls: "accordion-content-#{item_context.value}",
            style: %{
              display: :flex,
              align_items: :center,
              justify_content: :space_between,
              padding: 10,
              background:
                if(item_context.is_expanded,
                  do: :primary_light,
                  else: :transparent
                ),
              border: :none,
              cursor:
                if(item_context.disabled, do: :not_allowed, else: :pointer)
            }
          },
          children:
            children ++
              [
                %{
                  type: :text,
                  attrs: %{
                    content: if(item_context.is_expanded, do: "−", else: "+"),
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
        item_context = Hooks.use_context(:accordion_item_context)

        if item_context.is_expanded do
          %{
            type: :column,
            attrs: %{
              id: "accordion-content-#{item_context.value}",
              style: %{
                padding: 10,
                border_top: "1px solid #e0e0e0"
              }
            },
            children: children
          }
        else
          %{type: :text, attrs: %{content: "", style: %{display: :none}}}
        end
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
          if controlled_open != nil do
            {controlled_open,
             fn new_open -> if on_open_change, do: on_open_change.(new_open) end}
          else
            Hooks.use_state(default_open)
          end

        # Close dropdown when clicking outside (placeholder implementation)
        Hooks.use_effect(
          fn ->
            if is_open do
              outside_click_handler = fn _event ->
                set_is_open.(false)
              end

              register_outside_click_listener(outside_click_handler)

              fn ->
                unregister_outside_click_listener(outside_click_handler)
              end
            end
          end,
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
        dropdown_context = Hooks.use_context(:dropdown_context)

        %{
          type: :button,
          attrs: %{
            on_click: fn ->
              dropdown_context.set_open.(not dropdown_context.is_open)
            end,
            aria_expanded: dropdown_context.is_open,
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
        dropdown_context = Hooks.use_context(:dropdown_context)

        if dropdown_context.is_open do
          %{
            type: :column,
            attrs: %{
              role: :menu,
              style: %{
                position: :absolute,
                top:
                  case dropdown_context.placement do
                    :top -> :auto
                    _ -> "100%"
                  end,
                bottom:
                  case dropdown_context.placement do
                    :top -> "100%"
                    _ -> :auto
                  end,
                left:
                  case dropdown_context.placement do
                    :left -> :auto
                    :right -> "100%"
                    _ -> 0
                  end,
                right:
                  case dropdown_context.placement do
                    :right -> :auto
                    :left -> "100%"
                    _ -> :auto
                  end,
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
        else
          %{type: :text, attrs: %{content: "", style: %{display: :none}}}
        end
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
        dropdown_context = Hooks.use_context(:dropdown_context)

        handle_select =
          Hooks.use_callback(
            fn ->
              if not disabled do
                if on_select, do: on_select.(value)
                dropdown_context.close.()
              end
            end,
            [disabled, on_select, value]
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
              cursor: if(disabled, do: :not_allowed, else: :pointer),
              opacity: if(disabled, do: 0.5, else: 1.0),
              hover: %{
                background: if(disabled, do: :transparent, else: :primary_light)
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
          if controlled_value != nil do
            {controlled_value,
             fn new_value ->
               if on_value_change, do: on_value_change.(new_value)
             end}
          else
            Hooks.use_state(default_value)
          end

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
          case tabs_context.orientation do
            :horizontal -> :row
            :vertical -> :column
          end

        %{
          type: container_type,
          attrs: %{
            role: :tablist,
            aria_orientation: tabs_context.orientation,
            style: %{
              border_bottom:
                if(tabs_context.orientation == :horizontal,
                  do: "1px solid #e0e0e0",
                  else: :none
                ),
              border_right:
                if(tabs_context.orientation == :vertical,
                  do: "1px solid #e0e0e0",
                  else: :none
                )
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

        if value do
          # Get tabs context
          tabs_context = Hooks.use_context(:tabs_context)

          is_active = tabs_context.active_tab == value

          handle_click =
            Hooks.use_callback(
              fn ->
                if not disabled do
                  tabs_context.set_active_tab.(value)
                end
              end,
              [disabled, value]
            )

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
                background: if(is_active, do: :white, else: :transparent),
                border: :none,
                border_bottom:
                  if(is_active and tabs_context.orientation == :horizontal,
                    do: "2px solid #007acc",
                    else: :none
                  ),
                border_right:
                  if(is_active and tabs_context.orientation == :vertical,
                    do: "2px solid #007acc",
                    else: :none
                  ),
                cursor: if(disabled, do: :not_allowed, else: :pointer),
                opacity: if(disabled, do: 0.5, else: 1.0),
                font_weight: if(is_active, do: :bold, else: :normal)
              }
            },
            children: children
          }
        else
          %{
            type: :text,
            attrs: %{content: "Error: tabs_trigger requires :value prop"}
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

        if value do
          # Get tabs context
          tabs_context = Hooks.use_context(:tabs_context)

          is_active = tabs_context.active_tab == value

          if is_active do
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
          else
            %{type: :text, attrs: %{content: "", style: %{display: :none}}}
          end
        else
          %{
            type: :text,
            attrs: %{content: "Error: tabs_content requires :value prop"}
          }
        end
      end
    }
  end

  # Helper functions (placeholders)

  defp register_outside_click_listener(_handler) do
    # This would integrate with the actual event system
    :ok
  end

  defp unregister_outside_click_listener(_handler) do
    # This would integrate with the actual event system
    :ok
  end
end
