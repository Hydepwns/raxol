defmodule Raxol.UI.Components.Input.SelectList.Renderer do
  @moduledoc """
  Handles rendering functionality for the SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList.Pagination

  @doc """
  Renders the SelectList component.
  """
  def render(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    # Get visible options based on pagination
    visible_options =
      if state.show_pagination do
        Pagination.get_page_options(effective_options, state.current_page, state.page_size)
      else
        effective_options
      end

    # Build the component tree
    [
      # Search input if enabled
      if state.enable_search do
        render_search_input(state)
      end,
      # Main list container
      render_list_container(state, visible_options),
      # Pagination controls if enabled
      if state.show_pagination do
        render_pagination_controls(state)
      end
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Renders the search input element.
  """
  def render_search_input(state) do
    %{
      type: :input,
      props: %{
        type: :text,
        value: state.search_text,
        placeholder: state.placeholder,
        on_change: {:search, &Raxol.UI.Components.Input.SelectList.Search.update_search_state/2},
        on_focus: {:toggle_search_focus, &Raxol.UI.Components.Input.SelectList.update/2},
        style: %{
          width: "100%",
          padding: "0.5rem",
          margin_bottom: "0.5rem",
          border: "1px solid #ccc",
          border_radius: "4px"
        }
      }
    }
  end

  @doc """
  Renders the main list container with options.
  """
  def render_list_container(state, visible_options) do
    %{
      type: :container,
      props: %{
        style: %{
          width: "100%",
          max_height: state.max_height,
          overflow_y: "auto",
          border: "1px solid #ccc",
          border_radius: "4px"
        }
      },
      children: render_options(state, visible_options)
    }
  end

  @doc """
  Renders the list of options.
  """
  def render_options(state, visible_options) do
    if Enum.empty?(visible_options) do
      [
        %{
          type: :text,
          props: %{
            content: state.empty_message,
            style: %{
              padding: "1rem",
              text_align: "center",
              color: "#666"
            }
          }
        }
      ]
    else
      Enum.map_with_index(visible_options, fn {label, _value}, index ->
        render_option(state, label, index + state.scroll_offset)
      end)
    end
  end

  @doc """
  Renders a single option.
  """
  def render_option(state, label, index) do
    is_selected = MapSet.member?(state.selected_indices, index)
    is_focused = index == state.focused_index

    %{
      type: :container,
      props: %{
        style: %{
          padding: "0.5rem",
          background_color: if(is_focused, do: "#e6f3ff", else: "transparent"),
          border_bottom: "1px solid #eee",
          cursor: "pointer"
        },
        on_click: {:select_option, &Raxol.UI.Components.Input.SelectList.Selection.update_selection_state/2, [index]}
      },
      children: [
        %{
          type: :text,
          props: %{
            content: if(is_selected, do: "✓ #{label}", else: "  #{label}"),
            style: %{
              color: if(is_selected, do: "#0066cc", else: "#333")
            }
          }
        }
      ]
    }
  end

  @doc """
  Renders pagination controls.
  """
  def render_pagination_controls(state) do
    effective_options = Pagination.get_effective_options(state)
    total_pages = Pagination.calculate_total_pages(length(effective_options), state.page_size)

    %{
      type: :container,
      props: %{
        style: %{
          display: "flex",
          justify_content: "space-between",
          align_items: "center",
          padding: "0.5rem",
          border_top: "1px solid #ccc"
        }
      },
      children: [
        %{
          type: :button,
          props: %{
            content: "Previous",
            disabled: state.current_page == 0,
            on_click: {:set_page, &Pagination.update_page_state/2, [state.current_page - 1]},
            style: %{
              padding: "0.25rem 0.5rem",
              border: "1px solid #ccc",
              border_radius: "4px",
              background_color: if(state.current_page == 0, do: "#f5f5f5", else: "white")
            }
          }
        },
        %{
          type: :text,
          props: %{
            content: "Page #{state.current_page + 1} of #{total_pages}",
            style: %{
              color: "#666"
            }
          }
        },
        %{
          type: :button,
          props: %{
            content: "Next",
            disabled: state.current_page >= total_pages - 1,
            on_click: {:set_page, &Pagination.update_page_state/2, [state.current_page + 1]},
            style: %{
              padding: "0.25rem 0.5rem",
              border: "1px solid #ccc",
              border_radius: "4px",
              background_color: if(state.current_page >= total_pages - 1, do: "#f5f5f5", else: "white")
            }
          }
        }
      ]
    }
  end
end
