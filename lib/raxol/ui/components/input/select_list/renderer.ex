defmodule Raxol.UI.Components.Input.SelectList.Renderer do
  @moduledoc """
  Rendering logic for SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList
  alias Raxol.UI.Components.Input.SelectList.{Pagination, Selection}

  @doc """
  Renders the SelectList component.
  """
  @spec render(SelectList.t(), map()) :: iolist()
  def render(state, _context \\ %{}) do
    visible_options = get_visible_options(state)

    rendered_options =
      visible_options
      |> Enum.with_index(state.scroll_offset)
      |> Enum.map(fn {option, index} ->
        render_option(option, index, state)
      end)

    search_bar =
      if state.search_enabled do
        [render_search_bar(state)]
      else
        []
      end

    pagination_info =
      if state.paginated do
        [render_pagination_info(state)]
      else
        []
      end

    (search_bar ++ rendered_options ++ pagination_info)
    |> Enum.filter(&(&1 != nil))
  end

  # Private functions

  defp get_visible_options(state) do
    effective_options =
      case state.filtered_options do
        nil -> state.options
        filtered -> filtered
      end

    visible_items = state.visible_items || 10
    start_index = state.scroll_offset

    Enum.slice(effective_options, start_index, visible_items)
  end

  defp render_option(option, index, state) do
    label = get_option_label(option)
    is_selected = Selection.selected?(state, index)

    prefix =
      if is_selected do
        state.selected_marker || "> "
      else
        String.duplicate(" ", String.length(state.selected_marker || "> "))
      end

    style =
      if is_selected do
        state.selected_style || %{reverse: true}
      else
        %{}
      end

    %{
      type: :text,
      props: %{
        content: apply_style("#{prefix}#{label}\n", style)
      }
    }
  end

  defp render_search_bar(state) do
    query = state.search_query || ""
    cursor = if state.search_active, do: "_", else: ""

    content = [
      "Search: ",
      query,
      cursor,
      "\n",
      String.duplicate("-", 40),
      "\n"
    ] |> IO.iodata_to_binary()

    %{
      type: :text,
      props: %{
        content: content
      }
    }
  end

  defp render_pagination_info(state) do
    current_page = Pagination.get_current_page(state) + 1
    total_pages = Pagination.calculate_total_pages(state)

    content = [
      "\n",
      String.duplicate("-", 40),
      "\n",
      "Page #{current_page} of #{total_pages}",
      if(Pagination.has_prev_page?(state), do: " [<-Prev]", else: ""),
      if(Pagination.has_next_page?(state), do: " [Next->]", else: ""),
      "\n"
    ] |> IO.iodata_to_binary()

    %{
      type: :text,
      props: %{
        content: content
      }
    }
  end

  defp get_option_label(option) when is_binary(option), do: option
  defp get_option_label({label, _value}), do: label
  defp get_option_label(%{label: label}), do: label
  defp get_option_label(%{text: text}), do: text
  defp get_option_label(%{name: name}), do: name
  defp get_option_label(option), do: to_string(option)

  defp apply_style(text, style) when map_size(style) == 0, do: text

  defp apply_style(text, style) do
    # Apply ANSI style codes based on style map
    codes = []
    codes = if style[:bold], do: ["\e[1m" | codes], else: codes
    codes = if style[:reverse], do: ["\e[7m" | codes], else: codes
    codes = if style[:underline], do: ["\e[4m" | codes], else: codes

    if codes == [] do
      text
    else
      IO.iodata_to_binary([codes, text, "\e[0m"])
    end
  end
end
