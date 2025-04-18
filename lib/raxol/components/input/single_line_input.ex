defmodule Raxol.Components.Input.SingleLineInput do
  @moduledoc """
  A single-line input component with cursor management, text selection, and copy/paste support.

  ## Props
    * `:value` - Current text value (default: "")
    * `:placeholder` - Placeholder text when empty (default: "")
    * `:width` - Width of the input field (default: 20)
    * `:style` - Style map for customizing appearance
      * `:text_color` - Color of the text (default: :white)
      * `:placeholder_color` - Color of placeholder text (default: :gray)
      * `:selection_color` - Color of selected text (default: :blue)
      * `:cursor_color` - Color of the cursor (default: :white)
    * `:on_change` - Function called when text changes
    * `:on_submit` - Function called when Enter is pressed
  """

  use Raxol.Component
  alias Raxol.View.Components
  alias Raxol.Terminal.Clipboard

  @default_width 20
  @default_style %{
    text_color: :white,
    placeholder_color: :gray,
    selection_color: :blue,
    cursor_color: :white
  }

  @impl true
  def init(props) do
    %{
      value: props[:value] || "",
      placeholder: props[:placeholder] || "",
      width: props[:width] || @default_width,
      style: Map.merge(@default_style, props[:style] || %{}),
      cursor_pos: String.length(props[:value] || ""),
      selection_start: nil,
      selection_end: nil,
      focused: false,
      on_change: props[:on_change],
      on_submit: props[:on_submit],
      clipboard: Clipboard.new()
    }
  end

  @impl true
  def update({:set_value, value}, state) do
    %{
      state
      | value: value,
        cursor_pos: String.length(value),
        selection_start: nil,
        selection_end: nil
    }
  end

  def update({:move_cursor, pos}, state) do
    new_pos = clamp(pos, 0, String.length(state.value))
    %{state | cursor_pos: new_pos, selection_start: nil, selection_end: nil}
  end

  def update({:select, start_pos, end_pos}, state) do
    value_length = String.length(state.value)
    start_pos = clamp(start_pos, 0, value_length)
    end_pos = clamp(end_pos, 0, value_length)

    %{
      state
      | selection_start: start_pos,
        selection_end: end_pos,
        cursor_pos: end_pos
    }
  end

  def update(:focus, state) do
    %{state | focused: true}
  end

  def update(:blur, state) do
    %{state | focused: false}
  end

  def update(_msg, state), do: state

  @impl true
  def render(state) do
    # Use the View DSL to create the map representation
    dsl_result =
      if state.value == "" and not state.focused and state.placeholder != "" do
        # Render placeholder if value is empty, not focused, and placeholder exists
        Components.text(
          content: state.placeholder,
          color: state.style.placeholder_color
        )
      else
        # Otherwise, render the actual content
        Components.text(
          content: state.value,
          color: state.style.text_color
          # We might need cursor rendering logic here similar to MultiLineInput
        )
      end

    # Convert the DSL map to the Element struct required by the behaviour
    Raxol.View.to_element(dsl_result)
  end

  # defp render_text_with_selection(state) do
  #   # Placeholder implementation
  #   text = state.value
  #   start = min(state.selection_start, state.selection_end)
  #   ending = max(state.selection_start, state.selection_end)
  #
  #   if start == ending do
  #     text # No selection
  #   else
  #     pre = String.slice(text, 0, start)
  #     selected = String.slice(text, start, ending - start)
  #     post = String.slice(text, ending..-1)
  #     # TODO: Need proper View/Element structure here
  #     # [pre, Components.text(selected, style: @selected_style), post]
  #     pre <> "<SELECTED>" <> selected <> "</SELECTED>" <> post
  #   end
  # end

  @impl true
  def handle_event(%Event{type: :key, data: key_data} = _event, state)
      when state.focused do
    case key_data do
      %{key: key} when is_binary(key) and byte_size(key) == 1 ->
        # Regular character input
        {insert_text(state, key), []}

      %{key: :enter} ->
        if state.on_submit, do: state.on_submit.(state.value)
        {state, []}

      %{key: :backspace} ->
        {handle_backspace(state), []}

      %{key: :delete} ->
        {handle_delete(state), []}

      %{key: :left, modifiers: mods} ->
        if :ctrl in mods do
          {move_cursor_word_left(state), []}
        else
          {update({:move_cursor, state.cursor_pos - 1}, state), []}
        end

      %{key: :right, modifiers: mods} ->
        if :ctrl in mods do
          {move_cursor_word_right(state), []}
        else
          {update({:move_cursor, state.cursor_pos + 1}, state), []}
        end

      %{key: :home} ->
        {update({:move_cursor, 0}, state), []}

      %{key: :end} ->
        {update({:move_cursor, String.length(state.value)}, state), []}

      %{key: "c", modifiers: mods} ->
        if :ctrl in mods do
          new_state =
            if has_selection?(state) do
              {_, selected, _} = split_text_for_selection(state)

              case Clipboard.copy(state.clipboard, selected) do
                {:ok, new_clipboard_state} ->
                  %{state | clipboard: new_clipboard_state}

                # TODO: Log error?
                {:error, _reason} ->
                  state
              end
            else
              state
            end

          {new_state, []}
        else
          {insert_text(state, "c"), []}
        end

      %{key: "v", modifiers: mods} ->
        if :ctrl in mods do
          case Clipboard.paste(state.clipboard) do
            {:ok, text, new_clipboard_state} ->
              state_with_new_clipboard = %{
                state
                | clipboard: new_clipboard_state
              }

              {insert_text(state_with_new_clipboard, text), []}

            {:error, _reason} ->
              # TODO: Log error?
              {state, []}
          end
        else
          {insert_text(state, "v"), []}
        end

      %{key: "x", modifiers: mods} ->
        if :ctrl in mods do
          new_state =
            if has_selection?(state) do
              {_, selected, _} = split_text_for_selection(state)

              case Clipboard.copy(state.clipboard, selected) do
                {:ok, new_clipboard_state} ->
                  state_with_new_clipboard = %{
                    state
                    | clipboard: new_clipboard_state
                  }

                  delete_selection(state_with_new_clipboard)

                # TODO: Log error?
                {:error, _reason} ->
                  state
              end
            else
              state
            end

          {new_state, []}
        else
          {insert_text(state, "x"), []}
        end

      _ ->
        {state, []}
    end
  end

  def handle_event(%Event{type: :click}, state) do
    {update(:focus, state), []}
  end

  def handle_event(%Event{type: :blur}, state) do
    {update(:blur, state), []}
  end

  def handle_event(_event, state), do: {state, []}

  # Helper functions
  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  defp has_selection?(%{selection_start: start, selection_end: end_pos}) do
    start != nil and end_pos != nil and start != end_pos
  end

  defp insert_text(state, text) do
    if has_selection?(state) do
      state = delete_selection(state)
      do_insert_text(state, text)
    else
      do_insert_text(state, text)
    end
  end

  defp do_insert_text(state, text) do
    %{value: value, cursor_pos: pos} = state

    new_value =
      String.slice(value, 0, pos) <>
        text <> String.slice(value, pos, String.length(value))

    new_pos = pos + String.length(text)

    new_state = %{
      state
      | value: new_value,
        cursor_pos: new_pos,
        selection_start: nil,
        selection_end: nil
    }

    if state.on_change, do: state.on_change.(new_value)
    new_state
  end

  defp delete_selection(state) do
    {before_selection, _, after_selection} = split_text_for_selection(state)
    new_value = before_selection <> after_selection

    new_state = %{
      state
      | value: new_value,
        cursor_pos: state.selection_start,
        selection_start: nil,
        selection_end: nil
    }

    if state.on_change, do: state.on_change.(new_value)
    new_state
  end

  defp handle_backspace(state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      if state.cursor_pos > 0 do
        new_value =
          String.slice(state.value, 0, state.cursor_pos - 1) <>
            String.slice(
              state.value,
              state.cursor_pos,
              String.length(state.value)
            )

        new_state = %{
          state
          | value: new_value,
            cursor_pos: state.cursor_pos - 1
        }

        if state.on_change, do: state.on_change.(new_value)
        new_state
      else
        state
      end
    end
  end

  defp handle_delete(state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      if state.cursor_pos < String.length(state.value) do
        new_value =
          String.slice(state.value, 0, state.cursor_pos) <>
            String.slice(
              state.value,
              state.cursor_pos + 1,
              String.length(state.value)
            )

        new_state = %{state | value: new_value}

        if state.on_change, do: state.on_change.(new_value)
        new_state
      else
        state
      end
    end
  end

  defp move_cursor_word_left(state) do
    new_pos = find_word_boundary_left(state.value, state.cursor_pos)
    update({:move_cursor, new_pos}, state)
  end

  defp move_cursor_word_right(state) do
    new_pos = find_word_boundary_right(state.value, state.cursor_pos)
    update({:move_cursor, new_pos}, state)
  end

  defp find_word_boundary_left(text, pos) do
    text
    |> String.slice(0, pos)
    |> String.reverse()
    |> find_word_boundary()
    |> then(&(pos - &1))
  end

  defp find_word_boundary_right(text, pos) do
    text
    |> String.slice(pos, String.length(text))
    |> find_word_boundary()
    |> Kernel.+(pos)
  end

  defp find_word_boundary(text) do
    case Regex.run(~r/\b\w/, text, return: :index) do
      [{index, _}] -> index
      nil -> String.length(text)
    end
  end

  defp split_text_for_selection(%{
         value: value,
         selection_start: start,
         selection_end: end_pos
       }) do
    before_selection = String.slice(value, 0, start)
    selected = String.slice(value, start, end_pos - start)
    after_selection = String.slice(value, end_pos, String.length(value))
    {before_selection, selected, after_selection}
  end
end
