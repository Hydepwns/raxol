defmodule Raxol.UI.Components.Input.SelectList do
  @moduledoc """
  A component that allows users to select an option from a list.

  Features:
  * Single or multiple selections
  * Robust keyboard navigation with stateful scrolling
  * Search/filtering capabilities
  * Accessibility support
  * Custom styling and theming
  * Pagination for very large lists
  """

  alias Raxol.UI.Components.Input.SelectList.{
    Search,
    Pagination,
    Navigation,
    Selection,
    Renderer
  }

  @behaviour Raxol.UI.Components.Base.Component

  # Example: {"Option Label", :option_value}
  @type option :: {String.t(), any()}
  @type options :: [option()]
  @type props :: %{
          optional(:id) => String.t(),
          :options => options(),
          optional(:label) => String.t(),
          optional(:on_select) => (any() -> any()),
          optional(:on_cancel) => (-> any()) | nil,
          optional(:on_change) => (any() -> any()) | nil,
          optional(:on_focus) => (integer() -> any()) | nil,
          optional(:theme) => map(),
          optional(:style) => map(),
          optional(:max_height) => integer() | nil,
          optional(:enable_search) => boolean(),
          optional(:multiple) => boolean(),
          optional(:searchable_fields) => list(atom()) | nil,
          optional(:placeholder) => String.t(),
          optional(:empty_message) => String.t(),
          optional(:show_pagination) => boolean()
        }

  # Enhanced state includes props and more comprehensive internal state
  @type state :: %{
          :id => String.t() | nil,
          :options => options(),
          :label => String.t() | nil,
          :on_select => (any() -> any()) | nil,
          :on_cancel => (-> any()) | nil,
          :on_change => (any() -> any()) | nil,
          :on_focus => (integer() -> any()) | nil,
          :theme => map() | nil,
          :style => map() | nil,
          :max_height => integer() | nil,
          :enable_search => boolean(),
          :multiple => boolean(),
          :searchable_fields => list(atom()) | nil,
          :placeholder => String.t(),
          :empty_message => String.t(),
          :show_pagination => boolean(),
          :focused_index => integer(),
          :scroll_offset => integer(),
          :search_text => String.t(),
          :filtered_options => options() | nil,
          :is_filtering => boolean(),
          :selected_indices => MapSet.t(),
          :is_search_focused => boolean(),
          :page_size => integer(),
          :current_page => integer(),
          :has_focus => boolean(),
          :visible_height => integer() | nil,
          :last_key_time => integer() | nil,
          :search_buffer => String.t(),
          :search_timer => reference() | nil,
          :on_focus => (integer() -> any()) | nil,
          :viewport_width => integer() | nil,
          :viewport_height => integer() | nil
        }

  # --- Component Implementation ---

  @doc """
  Initializes the SelectList component state from the given props.
  """
  @spec init(map()) :: map()
  @impl true
  def init(props) do
    validate_props!(props)

    defaults = %{
      focused_index: 0,
      scroll_offset: 0,
      search_text: "",
      filtered_options: nil,
      is_filtering: false,
      selected_indices: MapSet.new(),
      is_search_focused: false,
      page_size: 10,
      current_page: 0,
      enable_search: false,
      multiple: false,
      searchable_fields: nil,
      placeholder: "Type to search...",
      empty_message: "No options available",
      show_pagination: false,
      has_focus: false,
      visible_height: nil,
      last_key_time: nil,
      search_buffer: "",
      search_timer: nil,
      theme: %{},
      style: %{},
      on_focus: nil,
      viewport_width: nil,
      viewport_height: nil
    }

    # Merge validated props with default internal state
    Map.merge(defaults, props)
  end

  @doc """
  Updates the SelectList component state in response to messages or prop changes.
  """
  @spec update(term(), map()) :: {map(), any()} | {map(), nil}
  @impl true
  def update({:update_props, new_props}, state) do
    validate_props!(new_props)

    # If options change substantially, we may need to reset some state
    reset_state = %{}

    reset_state =
      if Map.has_key?(new_props, :options) and
           new_props.options != state.options do
        # Cancel any pending search timer
        if state.search_timer do
          Process.cancel_timer(state.search_timer)
        end

        Map.merge(reset_state, %{
          filtered_options: nil,
          is_filtering: false,
          search_text: "",
          search_buffer: "",
          search_timer: nil,
          # Preserve selection if possible, otherwise reset
          focused_index: 0,
          scroll_offset: 0,
          current_page: 0
        })
      else
        reset_state
      end

    # Merge everything together, with new_props taking precedence
    updated_state = Map.merge(state, reset_state)
    {Map.merge(updated_state, new_props), nil}
  end

  def update({:search, search_text}, state) do
    # Cancel any existing timer
    if state.search_timer do
      Process.cancel_timer(state.search_timer)
    end

    # Schedule new search
    timer_ref = Process.send_after(self(), {:apply_search, search_text}, 300)

    # Update buffer immediately
    {%{state | search_buffer: search_text, search_timer: timer_ref}, nil}
  end

  def update({:apply_search, search_text}, state) do
    new_state =
      Search.update_search_state(
        %{state | search_text: search_text, search_timer: nil},
        search_text
      )

    {new_state, nil}
  end

  def update({:select_option, index}, state) do
    Selection.update_selection_state(state, index)
  end

  def update({:set_page, page_num}, state) do
    new_state = Pagination.update_page_state(state, page_num)
    {new_state, nil}
  end

  def update({:set_focus, has_focus}, state) do
    new_state = %{state | has_focus: has_focus}

    if has_focus and state.on_focus do
      state.on_focus.(state.focused_index)
    end

    {new_state, nil}
  end

  def update({:toggle_search_focus}, state) do
    if state.enable_search do
      new_state = %{state | is_search_focused: !state.is_search_focused}

      cleared_state = %{
        new_state
        | search_text: "",
          search_buffer: "",
          filtered_options: nil,
          is_filtering: false
      }

      {cleared_state, nil}
    else
      {state, nil}
    end
  end

  def update({:set_visible_height, height}, state) do
    {%{state | visible_height: height}, nil}
  end

  def update({:set_search_focus, true}, state) do
    new_state = %{
      state
      | is_search_focused: true,
        search_text: "",
        search_buffer: "",
        filtered_options: nil,
        is_filtering: false
    }

    {new_state, nil}
  end

  def update(message, state) do
    # If state is an empty map or missing required fields, initialize a default state
    state =
      cond do
        is_map(state) and map_size(state) == 0 -> init(%{options: []})
        not is_map(state) -> init(%{options: []})
        not Map.has_key?(state, :options) -> init(%{options: []})
        true -> state
      end

    do_update(message, state)
  end

  defp do_update({:update_props, new_props}, state),
    do: update({:update_props, new_props}, state)

  defp do_update({:search, search_text}, state),
    do: update({:search, search_text}, state)

  defp do_update({:apply_search, search_text}, state),
    do: update({:apply_search, search_text}, state)

  defp do_update({:select_option, index}, state),
    do: update({:select_option, index}, state)

  defp do_update({:set_page, page_num}, state),
    do: update({:set_page, page_num}, state)

  defp do_update({:set_focus, has_focus}, state),
    do: update({:set_focus, has_focus}, state)

  defp do_update({:toggle_search_focus}, state),
    do: update({:toggle_search_focus}, state)

  defp do_update({:set_visible_height, height}, state),
    do: update({:set_visible_height, height}, state)

  defp do_update({:set_search_focus, true}, state),
    do: update({:set_search_focus, true}, state)

  defp do_update(_message, state), do: {state, nil}

  @doc """
  Handles events for the SelectList component, such as keypresses, mouse events, and context changes.
  """
  @spec handle_event(map(), term(), map()) :: {map(), any()} | {map(), nil}
  @impl true
  def handle_event(%{__struct__: _} = event, context, state) do
    handle_event(Map.from_struct(event), context, state)
  end

  # Handle character list for numbers, e.g. from numpad
  # This clause must come BEFORE the general :key clause
  def handle_event(%{type: :key, data: %{key: key_charlist}}, _context, state)
      when is_list(key_charlist) do
    # Attempt to convert charlist to string, then to integer if it looks like a number
    key_string = List.to_string(key_charlist)

    case Integer.parse(key_string) do
      {digit, ""} when digit >= 0 and digit <= 9 ->
        # Treat as if '0' through '9' was pressed
        handle_numeric_select(state, Integer.to_string(digit) |> String.first())

      _ ->
        {:no_change, state}
    end
  end

  def handle_event(%{type: :key, data: %{key: key}}, _context, state) do
    case key do
      :up ->
        handle_key_up(state)

      :down ->
        handle_key_down(state)

      :page_up ->
        result_state = Navigation.handle_page_up(state)
        result_state

      :page_down ->
        Navigation.handle_page_down(state)

      :home ->
        Navigation.handle_home(state)

      :end ->
        Navigation.handle_end(state)

      "Enter" ->
        handle_enter(state)

      :backspace ->
        if state.is_search_focused and state.enable_search do
          handle_backspace(state)
        else
          {:no_change, state}
        end

      # Handle Tab key for search focus toggle
      "Tab" ->
        if state.enable_search do
          new_is_search_focused = not state.is_search_focused
          # When toggling search focus, typically clear search text and results
          new_state = %{
            state
            | is_search_focused: new_is_search_focused,
              search_text: "",
              search_buffer: "",
              filtered_options: nil,
              is_filtering: false,
              # Reset list focus when toggling search
              focused_index: 0
          }

          # No specific command needed here, UI just updates
          {new_state, nil}
        else
          # Tab does nothing if search is not enabled
          {:no_change, state}
        end

      # Numbers 0-9 for quick selection (if enabled)
      num when num in ?0..?9 ->
        handle_numeric_select(state, num)

      # Text input for filtering
      char when is_binary(char) and byte_size(char) == 1 ->
        if state.is_search_focused and state.enable_search do
          handle_text_input(state, char)
        else
          # If search is not focused, character input could be for type-ahead list navigation
          # For now, treat as no_change if not search focused.
          # TODO: Implement type-ahead list navigation if desired.
          {:no_change, state}
        end

      _ ->
        # Fallback: if it's a complex key event not handled above, keep current state
        # Or, if filtering is enabled, append to filter_text
        # For now, assume no change for unhandled specific keys.
        # Or consider :passthrough if other components might handle it
        {:no_change, state}
    end
  end

  def handle_event(%{type: :focus}, _context, state) do
    handle_focus_gain(state)
  end

  def handle_event(%{type: :blur}, _context, state) do
    handle_focus_lose(state)
  end

  def handle_event(
        %{type: :resize, data: %{width: width, height: height}},
        _context,
        state
      ) do
    new_state =
      state
      |> Map.put(:viewport_width, width)
      |> Map.put(:viewport_height, height)
      # Or some calculation based on height
      |> Map.put(:visible_height, height)

    # TODO: Potentially recalculate pagination or other layout-dependent things here
    # For now, just acknowledge the resize and store dimensions.
    {:no_change, new_state}
  end

  # Specific click handler now comes BEFORE the generic mouse handler
  def handle_event(
        %{type: :mouse, data: %{action: :click, x: _x, y: y_pos}},
        _context,
        state
      ) do
    cond do
      # Click on search input
      state.enable_search && y_pos == 0 ->
        new_state = %{state | is_search_focused: true, has_focus: true}
        {new_state, {:request_focus_search_input, nil}}

      true ->
        # Calls the private helper
        handle_mouse_click(y_pos, state)
    end
  end

  # Generic event for things like :mouse_up, :mouse_down if not handled by specific clause below
  def handle_event(%{type: :mouse} = _event, _context, state) do
    # For now, generic mouse events don't change state unless it's a click on an item
    {:no_change, state}
  end

  @doc """
  Renders the SelectList component using the current state and context.
  """
  @spec render(map(), map()) :: any()
  @impl true
  def render(state, context) do
    Renderer.render(state, context)
  end

  @doc """
  Mounts the SelectList component. Performs any setup needed after initialization.
  """
  @impl true
  def mount(state), do: state

  @doc """
  Unmounts the SelectList component, performing any necessary cleanup.
  """
  @impl true
  def unmount(state), do: state

  # --- Private Helper Functions ---

  defp validate_props!(props) do
    if not Map.has_key?(props, :options) do
      raise ArgumentError, "SelectList requires :options prop"
    end

    if not is_list(props.options) do
      raise ArgumentError, "SelectList :options must be a list"
    end

    # Validate each option
    Enum.each(props.options, fn option ->
      cond do
        is_tuple(option) and tuple_size(option) == 2 ->
          {label, _value} = option

          unless is_binary(label) do
            raise ArgumentError, "SelectList option labels must be strings"
          end

        is_tuple(option) and tuple_size(option) == 3 ->
          {label, _value, style} = option

          unless is_binary(label) do
            raise ArgumentError, "SelectList option labels must be strings"
          end

          unless is_map(style) do
            raise ArgumentError,
                  "SelectList option style (third element) must be a map"
          end

        true ->
          raise ArgumentError,
                "SelectList options must be {label, value} or {label, value, style} tuples"
      end
    end)
  end

  defp handle_key_up(state) do
    if state.focused_index > 0 do
      new_index = state.focused_index - 1
      Navigation.update_focus_and_scroll(state, new_index)
    else
      state
    end
  end

  defp handle_key_down(state) do
    options = state.filtered_options || state.options

    if state.focused_index < length(options) - 1 do
      new_index = state.focused_index + 1
      Navigation.update_focus_and_scroll(state, new_index)
    else
      state
    end
  end

  defp handle_enter(state) do
    if state.focused_index >= 0 do
      # Directly return the tuple from Selection.update_selection_state
      Selection.update_selection_state(state, state.focused_index)
    else
      # Return state with no commands if no focused index
      # Or state if the caller expects just state for no-op
      {state, nil}
      # Matching the tuple pattern for consistency from update_selection_state
    end
  end

  defp handle_backspace(state) do
    if String.length(state.search_buffer) > 0 do
      new_search_buffer =
        String.slice(
          state.search_buffer,
          0,
          String.length(state.search_buffer) - 1
        )

      intermediate_state = %{
        state
        | search_buffer: new_search_buffer,
          # Reset focus to top
          focused_index: 0,
          is_filtering: String.length(new_search_buffer) > 0
      }

      # Trigger the debounced search
      {final_state, _command} =
        update({:search, new_search_buffer}, intermediate_state)

      final_state
    else
      state
    end
  end

  defp handle_focus_gain(state) do
    {new_state, _} = update({:set_focus, true}, state)
    new_state
  end

  defp handle_focus_lose(state) do
    {new_state, _} = update({:set_focus, false}, state)
    new_state
  end

  defp handle_mouse_click(y, state) do
    return_value =
      if state.visible_height do
        index = Navigation.calculate_clicked_index(y, state)

        if index >= 0 and index < length(state.options) do
          Selection.update_selection_state(state, index)
        else
          {state, nil}
        end
      else
        {state, nil}
      end

    return_value
  end

  defp handle_text_input(state, char) do
    new_search_buffer = state.search_buffer <> char

    intermediate_state = %{
      state
      | search_buffer: new_search_buffer,
        # Reset focus to top on new input
        focused_index: 0,
        is_filtering: true
    }

    # Trigger the debounced search
    {final_state, _command} =
      update({:search, new_search_buffer}, intermediate_state)

    final_state
  end

  # Placeholder for numeric selection
  defp handle_numeric_select(state, _num_char) do
    # TODO: Implement actual numeric selection logic if needed
    # For now, returns state unchanged to allow compilation
    state
  end
end
