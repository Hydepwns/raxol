defmodule Raxol.UI.Components.Input.MultiLineInput do
  @moduledoc """
  A multi-line input component for text editing, supporting line wrapping, scrolling, selection, and accessibility.

  **BREAKING:** All styling is now theme-driven. The `style` field and `@default_style` are removed. Use the theme system for all appearance customization.

  Harmonized with modern Raxol component standards (style/theme merging, lifecycle hooks, accessibility props).
  """

  alias Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements

  @behaviour Component

  @default_width 40
  @default_height 10

  @typedoc "State for the MultiLineInput component. See @type t for field details."
  @type t :: %__MODULE__{
          id: String.t() | nil,
          value: String.t(),
          placeholder: String.t(),
          width: integer(),
          height: integer(),
          theme: map(),
          wrap: :none | :char | :word,
          cursor_pos: {integer(), integer()},
          scroll_offset: {integer(), integer()},
          selection_start: {integer(), integer()} | nil,
          selection_end: {integer(), integer()} | nil,
          history: any(),
          shift_held: boolean(),
          focused: boolean(),
          on_change: (String.t() -> any()) | nil,
          on_submit: (-> any()) | nil,
          aria_label: String.t() | nil,
          tooltip: String.t() | nil,
          lines: [String.t()],
          desired_col: integer() | nil
        }

  defstruct id: nil,
            value: "",
            placeholder: "",
            width: @default_width,
            height: @default_height,
            theme: %{},
            wrap: :word,
            cursor_pos: {0, 0},
            scroll_offset: {0, 0},
            selection_start: nil,
            selection_end: nil,
            history: nil,
            shift_held: false,
            focused: false,
            on_change: nil,
            on_submit: nil,
            aria_label: nil,
            tooltip: nil,
            lines: [""],
            desired_col: nil

  @spec init(map()) :: __MODULE__.t()
  @impl true
  @doc """
  Initializes the MultiLineInput state, harmonizing style/theme/extra props and splitting lines for editing.
  """
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    value = props[:value] || ""
    width = props[:width] || @default_width
    height = props[:height] || @default_height
    wrap = props[:wrap] || :word
    placeholder = props[:placeholder] || ""
    theme = props[:theme] || %{}
    aria_label = props[:aria_label]
    tooltip = props[:tooltip]
    on_change = props[:on_change]
    on_submit = props[:on_submit]
    focused = props[:focused] || false
    # Use the canonical helper for line splitting
    lines =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.split_into_lines(
        value,
        width,
        wrap
      )

    %__MODULE__{
      id: id,
      value: value,
      placeholder: placeholder,
      width: width,
      height: height,
      theme: theme,
      wrap: wrap,
      cursor_pos: {0, 0},
      scroll_offset: {0, 0},
      selection_start: nil,
      selection_end: nil,
      history: nil,
      shift_held: false,
      focused: focused,
      on_change: on_change,
      on_submit: on_submit,
      aria_label: aria_label,
      tooltip: tooltip,
      lines: lines
    }
  end

  @doc """
  Mounts the MultiLineInput component. Performs any setup needed after initialization.
  """
  @spec mount(__MODULE__.t()) :: __MODULE__.t()
  @impl true
  def mount(state), do: state

  @doc """
  Unmounts the MultiLineInput component, performing any necessary cleanup.
  """
  @spec unmount(__MODULE__.t()) :: __MODULE__.t()
  @impl true
  def unmount(state), do: state

  @impl true
  def update(msg, state) do
    route_message(msg, state)
  end

  # --- Message routing ---
  defp route_message(msg, state) do
    case Raxol.UI.Components.Input.MultiLineInput.MessageRouter.route(
           msg,
           state
         ) do
      {:ok, result} -> result
      :error -> handle_unknown_message(msg, state)
    end
  end

  # --- Message handlers ---
  def handle_update_props(new_props, state) do
    new_state = Map.merge(state, new_props)
    new_state = ensure_cursor_visible(new_state)
    {:noreply, new_state, nil}
  end

  def handle_input(char_codepoint, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.insert_char(
        state,
        char_codepoint
      )

    trigger_on_change({:noreply, ensure_cursor_visible(new_state), nil}, state)
  end

  def handle_backspace(state) do
    new_state =
      if elem(
           Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
             state
           ),
           0
         ) != nil do
        {s, _deleted} =
          Raxol.UI.Components.Input.MultiLineInput.TextHelper.delete_selection(
            state
          )

        s
      else
        Raxol.UI.Components.Input.MultiLineInput.TextHelper.handle_backspace_no_selection(
          state
        )
      end

    trigger_on_change({:noreply, ensure_cursor_visible(new_state), nil}, state)
  end

  def handle_delete(state) do
    new_state =
      if elem(
           Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
             state
           ),
           0
         ) != nil do
        {s, _deleted} =
          Raxol.UI.Components.Input.MultiLineInput.TextHelper.delete_selection(
            state
          )

        s
      else
        Raxol.UI.Components.Input.MultiLineInput.TextHelper.handle_delete_no_selection(
          state
        )
      end

    trigger_on_change({:noreply, ensure_cursor_visible(new_state), nil}, state)
  end

  def handle_enter(state) do
    {state_after_delete, _} =
      if elem(
           Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
             state
           ),
           0
         ) != nil do
        Raxol.UI.Components.Input.MultiLineInput.TextHelper.delete_selection(
          state
        )
      else
        {state, ""}
      end

    new_state =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.insert_char(
        state_after_delete,
        10
      )

    trigger_on_change({:noreply, ensure_cursor_visible(new_state), nil}, state)
  end

  def handle_move_cursor(direction, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        direction
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_line_start(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_start(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_line_end(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_end(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_page(direction, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
        state,
        direction
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_doc_start(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_start(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_doc_end(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_end(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_to({row, col}, state) do
    new_state =
      %{state | cursor_pos: {row, col}}
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_select_all(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.select_all(
        state
      )

    {:noreply, new_state, nil}
  end

  def handle_copy(state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.copy_selection(
        state
      )
    end

    {:noreply, state, nil}
  end

  def handle_cut(state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      {new_state, cmd} =
        Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.cut_selection(
          state
        )

      trigger_on_change(
        {:noreply, ensure_cursor_visible(new_state), cmd},
        state
      )
    else
      {:noreply, state, nil}
    end
  end

  def handle_paste(state) do
    Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.paste(state)
  end

  def handle_clipboard_content(content, state) do
    {start_pos, end_pos} =
      if state.selection_start && state.selection_end do
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
          state
        )
      else
        {state.cursor_pos, state.cursor_pos}
      end

    {new_value, _replaced} =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.replace_text_range(
        state.lines,
        start_pos,
        end_pos,
        content
      )

    {start_row, start_col} = start_pos

    {new_row, new_col} =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.calculate_new_position(
        start_row,
        start_col,
        content
      )

    new_state = %{
      state
      | value: new_value,
        cursor_pos: {new_row, new_col},
        selection_start: nil,
        selection_end: nil
    }

    trigger_on_change({:noreply, new_state, nil}, state)
  end

  def handle_focus(state) do
    {:noreply, %{state | focused: true}, nil}
  end

  def handle_blur(state) do
    {:noreply,
     %{state | focused: false, selection_start: nil, selection_end: nil}, nil}
  end

  def handle_set_shift_held(held, state) do
    {:noreply, %{state | shift_held: held}, nil}
  end

  def handle_delete_selection(_direction, state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.delete_selection(
        state
      )
    else
      {:noreply, state}
    end
  end

  def handle_copy_selection(state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.copy_selection(
        state
      )
    end

    {:noreply, state}
  end

  def handle_move_cursor_word_left(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        :word_left
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_word_right(state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        :word_right
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_select_to({row, col}, state) do
    original_cursor_pos = state.cursor_pos
    selection_start = state.selection_start || original_cursor_pos

    new_state = %{
      state
      | selection_start: selection_start,
        selection_end: {row, col},
        cursor_pos: {row, col}
    }

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def handle_unknown_message(msg, state) do
    Raxol.Core.Runtime.Log.warning(
      "[MultiLineInput] Unhandled update message: #{inspect(msg)}"
    )

    {:noreply, state, nil}
  end

  @doc """
  Handles events for the MultiLineInput component, such as keypresses, mouse events, and context changes.
  """
  @impl true
  def handle_event(event, _context, state) do
    # Delegate to the legacy EventHandler for translation
    case Raxol.UI.Components.Input.MultiLineInput.EventHandler.handle_event(
           event,
           state
         ) do
      {:update, msg, new_state} ->
        # Call update/2 with the translated message
        update(msg, new_state)

      {:noreply, new_state, cmds} ->
        {:noreply, new_state, cmds}

      _other ->
        # Fallback for any other return shape
        {:noreply, state, nil}
    end
  end

  # --- Internal Helpers ---
  defp ensure_cursor_visible(state) do
    {cursor_row, _cursor_col} = state.cursor_pos
    {scroll_row, scroll_col} = state.scroll_offset
    height = state.height

    new_scroll_row = calculate_scroll_row(cursor_row, scroll_row, height)

    new_scroll_col = scroll_col

    new_lines =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.split_into_lines(
        state.value,
        state.width,
        state.wrap
      )

    %{state | scroll_offset: {new_scroll_row, new_scroll_col}, lines: new_lines}
  end

  defp trigger_on_change({:noreply, new_state, existing_cmd}, old_state) do
    if new_state.value != old_state.value and
         is_function(new_state.on_change, 1) do
      change_event_cmd =
        {:component_event, new_state.id, {:change, new_state.value}}

      new_cmd =
        case existing_cmd do
          nil -> [change_event_cmd]
          cmd when is_list(cmd) -> [change_event_cmd | cmd]
          single_cmd -> [change_event_cmd, single_cmd]
        end

      Raxol.Core.Runtime.Log.debug(
        "Value changed for #{new_state.id}, queueing :change event."
      )

      {:noreply, new_state, new_cmd}
    else
      {:noreply, new_state, existing_cmd}
    end
  end

  defp trigger_on_change(other, _old_state), do: other

  def handle_selection_move(state, direction) do
    original_cursor_pos = state.cursor_pos
    moved_state = move_cursor_by_direction(state, direction)
    new_cursor_pos = moved_state.cursor_pos
    selection_start = state.selection_start || original_cursor_pos

    final_state = %{
      moved_state
      | selection_start: selection_start,
        selection_end: new_cursor_pos
    }

    {:noreply, ensure_cursor_visible(final_state), nil}
  end

  defp move_cursor_by_direction(state, direction) do
    direction_handlers = %{
      :left => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
          state,
          :left
        )
      end,
      :right => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
          state,
          :right
        )
      end,
      :up => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
          state,
          :up
        )
      end,
      :down => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
          state,
          :down
        )
      end,
      :line_start => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_start(
          state
        )
      end,
      :line_end => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_end(
          state
        )
      end,
      :page_up => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
          state,
          :up
        )
      end,
      :page_down => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
          state,
          :down
        )
      end,
      :doc_start => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_start(
          state
        )
      end,
      :doc_end => fn ->
        Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_end(
          state
        )
      end
    }

    case Map.get(direction_handlers, direction) do
      nil -> state
      handler -> handler.()
    end
  end

  @doc """
  Renders the MultiLineInput component using the current state and context.
  """
  @impl true
  def render(state, context) do
    merged_theme = merge_themes(context, state)
    visible_lines = calculate_visible_lines(state)

    children = build_children(state, visible_lines, merged_theme)

    root_props = build_root_props(state, merged_theme)

    Raxol.View.Elements.column root_props do
      children
    end
  end

  # --- Private helpers ---
  defp merge_themes(context, state) do
    component_theme = Map.get(context.theme || %{}, :multi_line_input, %{})
    Map.merge(component_theme, state.theme || %{})
  end

  defp calculate_visible_lines(state) do
    start_row = state.scroll_offset |> elem(0)
    end_row = min(start_row + state.height - 1, length(state.lines) - 1)
    Enum.slice(state.lines, start_row..end_row)
  end

  defp build_children(state, visible_lines, merged_theme) do
    line_elements = render_line_elements(visible_lines, state, merged_theme)
    placeholder_element = render_placeholder(state, merged_theme)

    children =
      if placeholder_element != nil and visible_lines == [""] do
        [placeholder_element]
      else
        line_elements
      end

    children |> List.flatten() |> Enum.reject(&is_nil/1)
  end

  defp render_line_elements(visible_lines, state, merged_theme) do
    start_row = state.scroll_offset |> elem(0)

    Enum.with_index(visible_lines, start_row)
    |> Enum.map(fn {line, index} ->
      Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
        index,
        line,
        state,
        %{components: %{multi_line_input: merged_theme}}
      )
    end)
  end

  defp render_placeholder(state, merged_theme) do
    if state.value == "" and not state.focused and state.placeholder != "" do
      Raxol.View.Elements.label(
        content: state.placeholder,
        style: [color: merged_theme[:placeholder_color] || :gray]
      )
    else
      nil
    end
  end

  defp build_root_props(state, merged_theme) do
    %{
      style: merged_theme,
      aria_label: state.aria_label,
      tooltip: state.tooltip
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp calculate_scroll_row(cursor_row, scroll_row, height) 
       when cursor_row < scroll_row, do: cursor_row
  
  defp calculate_scroll_row(cursor_row, scroll_row, height) 
       when cursor_row >= scroll_row + height, do: cursor_row - height + 1
  
  defp calculate_scroll_row(_cursor_row, scroll_row, _height), do: scroll_row
end
