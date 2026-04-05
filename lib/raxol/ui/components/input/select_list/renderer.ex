defmodule Raxol.UI.Components.Input.SelectList.Renderer do
  @moduledoc """
  Rendering logic for SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList
  alias Raxol.UI.Components.Input.SelectList.{Pagination, Selection, Utils}

  @doc """
  Renders the SelectList component.
  """
  @spec render(SelectList.t(), map()) :: map()
  def render(state, context \\ %{}) do
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

    children =
      (search_bar ++ rendered_options ++ pagination_info)
      |> Enum.filter(&(&1 != nil))

    container_style =
      if state.has_focus do
        Raxol.UI.FocusHelper.focus_style(state.style || %{}, context)
      else
        state.style || %{}
      end

    %{
      type: :container,
      id: state[:id],
      style: container_style,
      children: children
    }
  end

  # Private functions

  defp get_visible_options(state) do
    effective_options =
      case state.filtered_options do
        nil -> state.options
        filtered -> filtered
      end

    visible_items = state.visible_items || Raxol.Core.Defaults.page_size()
    start_index = state.scroll_offset

    Enum.slice(effective_options, start_index, visible_items)
  end

  defp render_option(option, index, state) do
    label = Utils.get_option_label(option)
    is_selected = Selection.selected?(state, index)

    prefix =
      if is_selected do
        state.selected_marker || "> "
      else
        String.duplicate(" ", String.length(state.selected_marker || "> "))
      end

    style =
      if is_selected do
        state.selected_style || Raxol.Core.Defaults.selected_style()
      else
        %{}
      end

    style_attrs =
      Enum.flat_map(style, fn
        {:bold, true} -> [:bold]
        {:reverse, true} -> [:reverse]
        {:underline, true} -> [:underline]
        _ -> []
      end)

    Raxol.View.Components.text(
      content: "#{prefix}#{label}\n",
      style: style_attrs
    )
  end

  defp render_search_bar(state) do
    query = state.search_query || ""
    cursor = if state.search_active, do: "_", else: ""

    content =
      [
        "Search: ",
        query,
        cursor,
        "\n",
        String.duplicate("-", 40),
        "\n"
      ]
      |> IO.iodata_to_binary()

    Raxol.View.Components.text(content: content)
  end

  defp render_pagination_info(state) do
    current_page = Pagination.get_current_page(state) + 1
    total_pages = Pagination.calculate_total_pages(state)

    content =
      [
        "\n",
        String.duplicate("-", 40),
        "\n",
        "Page #{current_page} of #{total_pages}",
        if(Pagination.has_prev_page?(state), do: " [<-Prev]", else: ""),
        if(Pagination.has_next_page?(state), do: " [Next->]", else: ""),
        "\n"
      ]
      |> IO.iodata_to_binary()

    Raxol.View.Components.text(content: content)
  end
end
