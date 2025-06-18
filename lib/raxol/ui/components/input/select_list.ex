defmodule Raxol.UI.Components.Input.SelectList do
  @moduledoc '''
  A component that allows users to select an option from a list.

  Features:
  * Single or multiple selections
  * Robust keyboard navigation with stateful scrolling
  * Search/filtering capabilities
  * Accessibility support
  * Custom styling and theming
  * Pagination for very large lists
  '''

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
          :on_focus => (integer() -> any()) | nil
        }

  # --- Component Implementation ---

  @doc '''
  Initializes the SelectList component state from the given props.
  '''
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
      on_focus: nil
    }

    # Merge validated props with default internal state
    Map.merge(defaults, props)
  end

  @doc '''
  Updates the SelectList component state in response to messages or prop changes.
  '''
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

  @doc '''
  Handles events for the SelectList component, such as keypresses, mouse events, and context changes.
  '''
  @spec handle_event(map(), term(), map()) :: {map(), any()} | {map(), nil}
  @impl true
  def handle_event(%{__struct__: _} = event, context, state) do
    handle_event(Map.from_struct(event), context, state)
  end

  def handle_event(%{type: :key, data: %{key: key}}, _context, state) do
    state = ensure_state(state)

    cond do
      key in ["Down", :down] ->
        Navigation.handle_arrow_down(state) |> then(&{&1, nil})

      key in ["Up", :up] ->
        Navigation.handle_arrow_up(state) |> then(&{&1, nil})

      key in ["PageDown", :pagedown] ->
        Navigation.handle_page_down(state) |> then(&{&1, nil})

      key in ["PageUp", :pageup] ->
        Navigation.handle_page_up(state) |> then(&{&1, nil})

      key in ["Home", :home] ->
        Navigation.handle_home(state) |> then(&{&1, nil})

      key in ["End", :end] ->
        Navigation.handle_end(state) |> then(&{&1, nil})

      key in ["Enter", :enter] ->
        {new_state, commands} =
          Selection.update_selection_state(state, state.focused_index)

        Enum.each(commands, fn
          {:callback, fun, args} -> apply(fun, args)
          _ -> :ok
        end)

        {new_state, nil}

      key in ["Tab", :tab] ->
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

      key in ["Backspace", :backspace] ->
        if state.is_search_focused and state.search_buffer != "" do
          new_buffer =
            String.slice(
              state.search_buffer,
              0,
              String.length(state.search_buffer) - 1
            )

          {new_state, _} = update({:search, new_buffer}, state)
          {new_state, nil}
        else
          {state, nil}
        end

      is_binary(key) and String.length(key) == 1 and state.enable_search and
          state.is_search_focused ->
        # Always update search_buffer immediately for character keys
        {new_state, _} = update({:search, state.search_buffer <> key}, state)
        {new_state, nil}

      true ->
        {state, nil}
    end
  end

  def handle_event(%{type: :focus}, _context, state) do
    state = ensure_state(state)
    {new_state, _} = update({:set_focus, true}, state)
    {new_state, nil}
  end

  def handle_event(%{type: :blur}, _context, state) do
    state = ensure_state(state)
    {new_state, _} = update({:set_focus, false}, state)
    {new_state, nil}
  end

  def handle_event(
        %{type: :resize, data: %{width: _w, height: h}},
        _context,
        state
      ) do
    state = ensure_state(state)
    {new_state, _} = update({:set_visible_height, h}, state)
    {Navigation.update_scroll_position(new_state), nil}
  end

  def handle_event(%{type: :mouse, data: %{x: _x, y: y}}, _context, state) do
    state = ensure_state(state)

    cond do
      state.enable_search and y == 1 ->
        # Always set is_search_focused to true on search box click
        {new_state, _} = update({:set_search_focus, true}, state)
        {new_state, nil}

      y >= 2 ->
        # Option click: y-2 (0-based index)
        index = Navigation.calculate_clicked_index(y - 2, state)
        effective_options = Pagination.get_effective_options(state)

        if index >= 0 and index < length(effective_options) do
          {maybe_new_state, commands} =
            Selection.update_selection_state(state, index)

          # Always set focused_index to the clicked index, even if selection didn't change
          new_state = Map.put(maybe_new_state, :focused_index, index)

          Enum.each(commands, fn
            {:callback, fun, args} -> apply(fun, args)
            _ -> :ok
          end)

          {new_state, nil}
        else
          {state, nil}
        end

      true ->
        {state, nil}
    end
  end

  @doc '''
  Renders the SelectList component using the current state and context.
  '''
  @spec render(map(), map()) :: any()
  @impl true
  def render(state, context) do
    Renderer.render(state, context)
  end

  @doc '''
  Mounts the SelectList component. Performs any setup needed after initialization.
  '''
  @impl true
  def mount(state), do: state

  @doc '''
  Unmounts the SelectList component, performing any necessary cleanup.
  '''
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

          if not is_binary(label) do
            raise ArgumentError, "SelectList option labels must be strings"
          end

        is_tuple(option) and tuple_size(option) == 3 ->
          {label, _value, style} = option

          if not is_binary(label) do
            raise ArgumentError, "SelectList option labels must be strings"
          end

          if not is_map(style) do
            raise ArgumentError,
                  "SelectList option style (third element) must be a map"
          end

        true ->
          raise ArgumentError,
                "SelectList options must be {label, value} or {label, value, style} tuples"
      end
    end)
  end

  defp ensure_state(state) do
    # If state is an empty map or missing required fields, initialize a default state
    cond do
      is_map(state) and map_size(state) == 0 -> init(%{options: []})
      not is_map(state) -> init(%{options: []})
      not Map.has_key?(state, :options) -> init(%{options: []})
      true -> state
    end
  end
end
