defmodule Raxol.UI.Components.Input.MultiLineInput.MessageRouter do
  @moduledoc """
  Handles message routing for MultiLineInput component to reduce complexity.
  """

  @message_handlers %{
    {:update_props, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_update_props/2,
    {:input, :_} => &Raxol.UI.Components.Input.MultiLineInput.handle_input/2,
    {:backspace} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_backspace/1,
    {:delete} => &Raxol.UI.Components.Input.MultiLineInput.handle_delete/1,
    {:enter} => &Raxol.UI.Components.Input.MultiLineInput.handle_enter/1,
    {:move_cursor, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor/2,
    {:move_cursor_line_start} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_line_start/1,
    {:move_cursor_line_end} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_line_end/1,
    {:move_cursor_page, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_page/2,
    {:move_cursor_doc_start} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_doc_start/1,
    {:move_cursor_doc_end} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_doc_end/1,
    {:move_cursor_to, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_to/2,
    {:select_and_move, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_selection_move/2,
    {:select_all} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_select_all/1,
    {:copy} => &Raxol.UI.Components.Input.MultiLineInput.handle_copy/1,
    {:cut} => &Raxol.UI.Components.Input.MultiLineInput.handle_cut/1,
    {:paste} => &Raxol.UI.Components.Input.MultiLineInput.handle_paste/1,
    {:clipboard_content, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_clipboard_content/2,
    :focus => &Raxol.UI.Components.Input.MultiLineInput.handle_focus/1,
    :blur => &Raxol.UI.Components.Input.MultiLineInput.handle_blur/1,
    {:set_shift_held, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_set_shift_held/2,
    {:delete_selection, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_delete_selection/2,
    {:copy_selection} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_copy_selection/1,
    {:move_cursor_word_left} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_word_left/1,
    {:move_cursor_word_right} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_move_cursor_word_right/1,
    {:move_cursor_select, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_selection_move/2,
    {:select_to, :_} =>
      &Raxol.UI.Components.Input.MultiLineInput.handle_select_to/2
  }

  def route(msg, state) do
    case find_handler(msg) do
      {handler, args} -> {:ok, apply_handler(handler, args, state)}
      nil -> :error
    end
  end

  defp find_handler(msg) do
    Enum.find_value(@message_handlers, fn {pattern, handler} ->
      if matches_pattern?(msg, pattern) do
        {handler, extract_args(msg, pattern)}
      end
    end)
  end

  defp matches_pattern?(msg, pattern) do
    case {msg, pattern} do
      {msg, pattern} when msg == pattern -> true
      {{tag, _}, {tag, :_}} -> matches_tag_pattern?(tag, msg)
      _ -> false
    end
  end

  defp matches_tag_pattern?(:update_props, _msg), do: true
  defp matches_tag_pattern?(:input, _msg), do: true

  defp matches_tag_pattern?(:move_cursor, {:move_cursor, direction}),
    do: direction in [:left, :right, :up, :down]

  defp matches_tag_pattern?(:move_cursor_page, {:move_cursor_page, direction}),
    do: direction in [:up, :down]

  defp matches_tag_pattern?(:move_cursor_to, _msg), do: true
  defp matches_tag_pattern?(:select_and_move, _msg), do: true

  defp matches_tag_pattern?(:clipboard_content, {:clipboard_content, content}),
    do: is_binary(content)

  defp matches_tag_pattern?(:set_shift_held, _msg), do: true

  defp matches_tag_pattern?(:delete_selection, {:delete_selection, direction}),
    do: direction in [:backward, :forward]

  defp matches_tag_pattern?(
         :move_cursor_select,
         {:move_cursor_select, direction}
       ),
       do:
         direction in [
           :left,
           :right,
           :up,
           :down,
           :line_start,
           :line_end,
           :page_up,
           :page_down,
           :doc_start,
           :doc_end
         ]

  defp matches_tag_pattern?(:select_to, _msg), do: true
  defp matches_tag_pattern?(_, _), do: false

  defp extract_args(msg, pattern) do
    case {msg, pattern} do
      {{tag, arg}, {tag, :_}} -> extract_tag_args(tag, arg)
      _ -> []
    end
  end

  defp extract_tag_args(:update_props, new_props), do: [new_props]
  defp extract_tag_args(:input, char_codepoint), do: [char_codepoint]
  defp extract_tag_args(:move_cursor, direction), do: [direction]
  defp extract_tag_args(:move_cursor_page, direction), do: [direction]
  defp extract_tag_args(:move_cursor_to, pos), do: [pos]
  defp extract_tag_args(:select_and_move, direction), do: [direction]
  defp extract_tag_args(:clipboard_content, content), do: [content]
  defp extract_tag_args(:set_shift_held, held), do: [held]
  defp extract_tag_args(:delete_selection, direction), do: [direction]
  defp extract_tag_args(:move_cursor_select, direction), do: [direction]
  defp extract_tag_args(:select_to, pos), do: [pos]
  defp extract_tag_args(_, _), do: []

  defp apply_handler(handler, args, state) do
    case length(args) do
      0 -> handler.(state)
      1 -> apply(handler, [Enum.at(args, 0), state])
      2 -> apply(handler, args ++ [state])
    end
  end
end
