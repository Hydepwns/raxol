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
  def update({:update_props, new_props}, state) do
    new_state = Map.merge(state, new_props)
    new_state = ensure_cursor_visible(new_state)
    {:noreply, new_state, nil}
  end

  def update({:input, char_codepoint}, state)
      when is_integer(char_codepoint) or is_binary(char_codepoint) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.TextHelper.insert_char(
        state,
        char_codepoint
      )

    trigger_on_change({:noreply, ensure_cursor_visible(new_state), nil}, state)
  end

  def update({:backspace}, state) do
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

  def update({:delete}, state) do
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

  def update({:enter}, state) do
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

  def update({:move_cursor, direction}, state)
      when direction in [:left, :right, :up, :down] do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        direction
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_line_start}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_start(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_line_end}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_end(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_page, direction}, state)
      when direction in [:up, :down] do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
        state,
        direction
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_doc_start}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_start(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_doc_end}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_end(
        state
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_to, {row, col}}, state) do
    new_state =
      %{state | cursor_pos: {row, col}}
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:select_and_move, direction}, state) do
    handle_selection_move(state, direction)
  end

  def update({:select_all}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.select_all(
        state
      )

    {:noreply, new_state, nil}
  end

  def update({:copy}, state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.copy_selection(
        state
      )

      {:noreply, state, nil}
    else
      {:noreply, state, nil}
    end
  end

  def update({:cut}, state) do
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

  def update({:paste}, state) do
    {state, commands} =
      Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.paste(state)

    {state, commands}
  end

  def update({:clipboard_content, content}, state) when is_binary(content) do
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
        state.value,
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

    if state.on_change, do: state.on_change.(new_value)
    new_state
  end

  def update({:clipboard_content, _}, state) do
    {:noreply, state, nil}
  end

  def update(:focus, state) do
    {:noreply, %{state | focused: true}, nil}
  end

  def update(:blur, state) do
    {:noreply,
     %{state | focused: false, selection_start: nil, selection_end: nil}, nil}
  end

  def update({:set_shift_held, held}, state) do
    {:noreply, %{state | shift_held: held}, nil}
  end

  def update({:delete_selection, direction}, state)
      when direction in [:backward, :forward] do
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

  def update({:copy_selection}, state) do
    if elem(
         Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.normalize_selection(
           state
         ),
         0
       ) != nil do
      Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper.copy_selection(
        state
      )

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def update({:move_cursor_word_left}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        :word_left
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_word_right}, state) do
    new_state =
      Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
        state,
        :word_right
      )
      |> Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.clear_selection()

    {:noreply, ensure_cursor_visible(new_state), nil}
  end

  def update({:move_cursor_select, direction}, state)
      when direction in [
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
           ] do
    handle_selection_move(state, direction)
  end

  def update({:select_to, {row, col}}, state) do
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

  def update(msg, state) do
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

    new_scroll_row =
      cond do
        cursor_row < scroll_row -> cursor_row
        cursor_row >= scroll_row + height -> cursor_row - height + 1
        true -> scroll_row
      end

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

  defp handle_selection_move(state, direction) do
    original_cursor_pos = state.cursor_pos

    moved_state =
      case direction do
        :left ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
            state,
            :left
          )

        :right ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
            state,
            :right
          )

        :up ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
            state,
            :up
          )

        :down ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor(
            state,
            :down
          )

        :line_start ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_start(
            state
          )

        :line_end ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_line_end(
            state
          )

        :page_up ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
            state,
            :up
          )

        :page_down ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_page(
            state,
            :down
          )

        :doc_start ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_start(
            state
          )

        :doc_end ->
          Raxol.UI.Components.Input.MultiLineInput.NavigationHelper.move_cursor_doc_end(
            state
          )
      end

    new_cursor_pos = moved_state.cursor_pos
    selection_start = state.selection_start || original_cursor_pos

    final_state = %{
      moved_state
      | selection_start: selection_start,
        selection_end: new_cursor_pos
    }

    {:noreply, ensure_cursor_visible(final_state), nil}
  end

  @doc """
  Renders the MultiLineInput component using the current state and context.
  """
  @spec render(__MODULE__.t(), map()) :: any()
  @impl true
  def render(state, context) do
    # Merge themes: context.theme < state.theme
    component_theme = Map.get(context.theme || %{}, :multi_line_input, %{})
    merged_theme = Map.merge(component_theme, state.theme || %{})

    # Calculate visible lines
    start_row = state.scroll_offset |> elem(0)
    end_row = min(start_row + state.height - 1, length(state.lines) - 1)
    visible_lines = Enum.slice(state.lines, start_row..end_row)

    # Render each line using the RenderHelper
    line_elements =
      Enum.with_index(visible_lines, start_row)
      |> Enum.map(fn {line, index} ->
        Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(
          index,
          line,
          state,
          %{components: %{multi_line_input: merged_theme}}
        )
      end)

    # Render placeholder if needed
    placeholder_element =
      if state.value == "" and not state.focused and state.placeholder != "" do
        Raxol.View.Elements.label(
          content: state.placeholder,
          style: [color: merged_theme[:placeholder_color] || :gray]
        )
      else
        nil
      end

    # Compose children
    children =
      if placeholder_element != nil and visible_lines == [""] do
        [placeholder_element]
      else
        line_elements
      end

    processed_children = children |> List.flatten() |> Enum.reject(&is_nil/1)

    # Compose root element with accessibility/extra props
    root_props =
      %{
        style: merged_theme,
        aria_label: state.aria_label,
        tooltip: state.tooltip
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    Raxol.View.Elements.column root_props do
      processed_children
    end
  end
end
