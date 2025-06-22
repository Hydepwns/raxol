defmodule Raxol.UI.Components.Input.SelectList.Renderer do
  @moduledoc """
  Handles rendering functionality for the SelectList component.
  """

  import Raxol.Guards

  alias Raxol.UI.Components.Input.SelectList.Pagination

  @doc """
  Renders the SelectList component.
  """
  def render(state, _context) do
    effective_options = Pagination.get_effective_options(state)
    _num_options = length(effective_options)

    # Get visible options based on pagination
    visible_options =
      if state.show_pagination do
        Pagination.get_page_options(
          effective_options,
          state.current_page,
          state.page_size
        )
      else
        effective_options
      end

    # Merge default, theme, and style props for the main container
    merged_style =
      Map.merge(
        %{
          width: "100%",
          max_height: state.max_height,
          overflow_y: "auto",
          border: "1px solid #ccc",
          border_radius: "4px"
        },
        Map.merge(
          state.theme[:container] || %{},
          state.style[:container] || %{}
        )
      )

    [
      # Search input if enabled
      if state.enable_search do
        render_search_input(state)
      end,
      # Main list container
      %{
        type: :container,
        props: %{style: merged_style},
        children: render_options(state, visible_options)
      },
      # Pagination controls if enabled
      if state.show_pagination do
        render_pagination_controls(state)
      end
    ]
    |> Enum.reject(&nil?/1)
  end

  @doc """
  Renders the search input element.
  """
  def render_search_input(state) do
    merged_style =
      Map.merge(
        %{
          width: "100%",
          padding: "0.5rem",
          margin_bottom: "0.5rem",
          border: "1px solid #ccc",
          border_radius: "4px"
        },
        Map.merge(
          state.theme[:search_input] || %{},
          state.style[:search_input] || %{}
        )
      )

    %{
      type: :input,
      props: %{
        type: :text,
        value: state.search_text,
        placeholder: state.placeholder,
        on_change:
          {:search,
           &Raxol.UI.Components.Input.SelectList.Search.update_search_state/2},
        on_focus:
          {:toggle_search_focus, &Raxol.UI.Components.Input.SelectList.update/2},
        style: merged_style
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
      merged_style =
        Map.merge(
          %{
            padding: "1rem",
            text_align: "center",
            color: "#666"
          },
          Map.merge(
            state.theme[:empty_message] || %{},
            state.style[:empty_message] || %{}
          )
        )

      [
        %{
          type: :text,
          props: %{
            content: state.empty_message,
            style: merged_style
          }
        }
      ]
    else
      Enum.with_index(visible_options)
      |> Enum.map(fn {option, index} ->
        cond do
          tuple?(option) and tuple_size(option) == 3 ->
            # {label, value, opt_style}
            {label, value, opt_style} = option

            render_option(
              state,
              label,
              value,
              index + state.scroll_offset,
              opt_style
            )

          tuple?(option) and tuple_size(option) == 2 ->
            # {label, value} (value may be a map or any type)
            {label, value} = option
            render_option(state, label, value, index + state.scroll_offset, %{})

          true ->
            # Fallback: render as string
            render_option(
              state,
              to_string(option),
              nil,
              index + state.scroll_offset,
              %{}
            )
        end
      end)
    end
  end

  @doc """
  Renders a single option.
  """
  def render_option(state, label, _value, index, opt_style) do
    selected = MapSet.member?(state.selected_indices, index)
    focused = index == state.focused_index

    merged_style =
      Map.merge(
        %{
          padding: "0.5rem",
          background_color:
            if(focused,
              do:
                state.theme[:focused_bg] || state.style[:focused_bg] ||
                  "#e6f3ff",
              else:
                state.theme[:option_bg] || state.style[:option_bg] ||
                  "transparent"
            ),
          border_bottom: "1px solid #eee",
          cursor: "pointer"
        },
        Map.merge(state.theme[:option] || %{}, state.style[:option] || %{})
      )

    merged_style = Map.merge(merged_style, opt_style || %{})

    %{
      type: :container,
      props: %{
        style: merged_style,
        on_click:
          {:select_option,
           &Raxol.UI.Components.Input.SelectList.Selection.update_selection_state/2,
           [index]}
      },
      children: [
        %{
          type: :text,
          props: %{
            content: if(selected, do: "✓ #{label}", else: "  #{label}"),
            style:
              if selected do
                Map.merge(
                  Map.merge(
                    %{
                      color:
                        state.style[:selected_color] ||
                          state.theme[:selected_color] || "#0066cc"
                    },
                    Map.merge(
                      state.theme[:option_text] || %{},
                      state.style[:option_text] || %{}
                    )
                  ),
                  # Per-option style merged, but color is always overridden
                  Map.drop(opt_style || %{}, [:color, "color"])
                )
              else
                Map.merge(
                  Map.merge(
                    %{
                      color:
                        opt_style[:color] || state.theme[:option_color] ||
                          state.style[:option_color] || "#333"
                    },
                    Map.merge(
                      state.theme[:option_text] || %{},
                      state.style[:option_text] || %{}
                    )
                  ),
                  opt_style || %{}
                )
              end
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

    total_pages =
      Pagination.calculate_total_pages(
        length(effective_options),
        state.page_size
      )

    merged_style =
      Map.merge(
        %{
          display: "flex",
          justify_content: "space-between",
          align_items: "center",
          padding: "0.5rem",
          border_top: "1px solid #ccc"
        },
        Map.merge(
          state.theme[:pagination] || %{},
          state.style[:pagination] || %{}
        )
      )

    %{
      type: :container,
      props: %{
        style: merged_style
      },
      children: [
        %{
          type: :button,
          props: %{
            content: "Previous",
            disabled: state.current_page == 0,
            on_click:
              {:set_page, &Pagination.update_page_state/2,
               [state.current_page - 1]},
            style:
              Map.merge(
                %{
                  padding: "0.25rem 0.5rem",
                  border: "1px solid #ccc",
                  border_radius: "4px",
                  background_color:
                    if(state.current_page == 0, do: "#f5f5f5", else: "white")
                },
                Map.merge(
                  state.theme[:pagination_button] || %{},
                  state.style[:pagination_button] || %{}
                )
              )
          }
        },
        %{
          type: :text,
          props: %{
            content: "Page #{state.current_page + 1} of #{total_pages}",
            style:
              Map.merge(
                %{color: "#666"},
                Map.merge(
                  state.theme[:pagination_text] || %{},
                  state.style[:pagination_text] || %{}
                )
              )
          }
        },
        %{
          type: :button,
          props: %{
            content: "Next",
            disabled: state.current_page >= total_pages - 1,
            on_click:
              {:set_page, &Pagination.update_page_state/2,
               [state.current_page + 1]},
            style:
              Map.merge(
                %{
                  padding: "0.25rem 0.5rem",
                  border: "1px solid #ccc",
                  border_radius: "4px",
                  background_color:
                    if(state.current_page >= total_pages - 1,
                      do: "#f5f5f5",
                      else: "white"
                    )
                },
                Map.merge(
                  state.theme[:pagination_button] || %{},
                  state.style[:pagination_button] || %{}
                )
              )
          }
        }
      ]
    }
  end
end
