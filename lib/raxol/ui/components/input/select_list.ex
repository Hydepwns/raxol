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

  import Raxol.Guards

  alias Raxol.UI.Components.Input.SelectList.{
    Search,
    Pagination,
    Navigation,
    Selection,
    Renderer
  }

  @behaviour Raxol.UI.Components.Base.Component

  @key_mapping %{
    "Down" => :navigation_down,
    :down => :navigation_down,
    "Up" => :navigation_up,
    :up => :navigation_up,
    "PageDown" => :navigation_page_down,
    :pagedown => :navigation_page_down,
    :page_down => :navigation_page_down,
    "PageUp" => :navigation_page_up,
    :pageup => :navigation_page_up,
    :page_up => :navigation_page_up,
    "Home" => :navigation_home,
    :home => :navigation_home,
    "End" => :navigation_end,
    :end => :navigation_end,
    "Enter" => :enter,
    :enter => :enter,
    "Tab" => :tab,
    :tab => :tab,
    "Backspace" => :backspace,
    :backspace => :backspace
  }

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
          :search_timer => integer() | nil,
          :on_focus => (integer() -> any()) | nil
        }

  # --- Component Implementation ---

  @doc """
  Initializes the SelectList component state from the given props.
  """
  @spec init(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
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

  @doc """
  Updates the SelectList component state in response to messages or prop changes.
  """
  @spec update(term(), map()) :: {map(), any()} | {map(), nil}
  @impl Raxol.UI.Components.Base.Component
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
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:apply_search, search_text}, 300)

    # Update buffer immediately
    {%{state | search_buffer: search_text, search_timer: timer_id}, nil}
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
        map?(state) and map_size(state) == 0 -> init(%{options: []})
        not map?(state) -> init(%{options: []})
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
  @impl Raxol.UI.Components.Base.Component
  def handle_event(%{__struct__: _} = event, context, state) do
    handle_event(Map.from_struct(event), context, state)
  end

  def handle_event(%{type: :key, data: %{key: key}}, _context, state) do
    state = ensure_state(state)
    handle_key_event(key, state)
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
    handle_mouse_click(y, state)
  end

  defp handle_mouse_click(y, state) when y == 0 and state.enable_search do
    # Click on search input (y=0)
    {new_state, _} = update({:set_search_focus, true}, state)
    {new_state, nil}
  end

  defp handle_mouse_click(y, state) when y >= 1 do
    # Option click: y gives us the 0-based index directly
    index = y
    effective_options = Pagination.get_effective_options(state)

    if index >= 0 and index < length(effective_options) do
      handle_option_click(state, index)
    else
      {state, nil}
    end
  end

  defp handle_mouse_click(_y, state), do: {state, nil}

  defp handle_option_click(state, index) do
    {maybe_new_state, commands} = Selection.update_selection_state(state, index)
    new_state = Map.put(maybe_new_state, :focused_index, index)
    execute_commands(commands)
    {new_state, nil}
  end

  defp execute_commands(commands) do
    Enum.each(commands, fn
      {:callback, fun, args} -> apply(fun, args)
      _ -> :ok
    end)
  end

  @doc """
  Renders the SelectList component using the current state and context.
  """
  @spec render(map(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, context) do
    Renderer.render(state, context)
  end

  @doc """
  Mounts the SelectList component. Performs any setup needed after initialization.
  """
  @impl Raxol.UI.Components.Base.Component
  def mount(state), do: state

  @doc """
  Unmounts the SelectList component, performing any necessary cleanup.
  """
  @impl Raxol.UI.Components.Base.Component
  def unmount(state), do: state

  # --- Private Helper Functions ---

  defp validate_props!(props) do
    if not Map.has_key?(props, :options) do
      raise ArgumentError, "SelectList requires :options prop"
    end

    if not list?(props.options) do
      raise ArgumentError, "SelectList :options must be a list"
    end

    # Validate each option
    Enum.each(props.options, &validate_option!/1)
  end

  defp validate_option!(option) do
    cond do
      tuple?(option) and tuple_size(option) == 2 ->
        {label, _value} = option
        validate_label!(label)

      tuple?(option) and tuple_size(option) == 3 ->
        {label, _value, style} = option
        validate_label!(label)
        validate_style!(style)

      true ->
        raise ArgumentError,
              "SelectList options must be {label, value} or {label, value, style} tuples"
    end
  end

  defp validate_label!(label) do
    if not binary?(label) do
      raise ArgumentError, "SelectList option labels must be strings"
    end
  end

  defp validate_style!(style) do
    if not map?(style) do
      raise ArgumentError,
            "SelectList option style (third element) must be a map"
    end
  end

  defp ensure_state(state) do
    # If state is an empty map or missing required fields, initialize a default state
    cond do
      map?(state) and map_size(state) == 0 -> init(%{options: []})
      not map?(state) -> init(%{options: []})
      not Map.has_key?(state, :options) -> init(%{options: []})
      true -> state
    end
  end

  defp handle_key_event(key, state) do
    action = classify_key_action(key, state)
    execute_key_action(action, state)
  end

  @key_action_mapping %{
    :navigation_down => {:navigation, :down},
    :navigation_up => {:navigation, :up},
    :navigation_page_down => {:navigation, :page_down},
    :navigation_page_up => {:navigation, :page_up},
    :navigation_home => {:navigation, :home},
    :navigation_end => {:navigation, :end},
    :enter => {:selection, :enter},
    :tab => {:search, :toggle_focus},
    :backspace => {:search, :backspace}
  }

  defp classify_key_action(key, state) do
    key_type = classify_key(key, state)

    case key_type do
      :character -> {:search, {:character, key}}
      :unknown -> {:noop, nil}
      _ -> Map.get(@key_action_mapping, key_type, {:noop, nil})
    end
  end

  defp execute_key_action({:navigation, direction}, state) do
    navigation_handler(direction, state)
  end

  defp execute_key_action({:selection, :enter}, state) do
    Selection.update_selection_state(state, state.focused_index)
  end

  defp execute_key_action({:search, action}, state) do
    search_handler(action, state)
  end

  defp execute_key_action({:noop, _}, state), do: {state, nil}

  defp navigation_handler(:down, state),
    do: Navigation.handle_arrow_down(state) |> then(&{&1, nil})

  defp navigation_handler(:up, state),
    do: Navigation.handle_arrow_up(state) |> then(&{&1, nil})

  defp navigation_handler(:page_down, state),
    do: Navigation.handle_page_down(state) |> then(&{&1, nil})

  defp navigation_handler(:page_up, state),
    do: Navigation.handle_page_up(state) |> then(&{&1, nil})

  defp navigation_handler(:home, state),
    do: Navigation.handle_home(state) |> then(&{&1, nil})

  defp navigation_handler(:end, state),
    do: Navigation.handle_end(state) |> then(&{&1, nil})

  defp search_handler(:toggle_focus, state), do: handle_tab_key(state)
  defp search_handler(:backspace, state), do: handle_backspace_key(state)

  defp search_handler({:character, key}, state),
    do: handle_character_key(key, state)

  defp classify_key(key, state) do
    key_type = get_key_type(key)

    if key_type == :unknown and character_key?(key, state) do
      :character
    else
      key_type
    end
  end

  defp get_key_type(key) do
    @key_mapping[key] || :unknown
  end

  defp character_key?(key, state) do
    single_character?(key) and search_enabled_and_focused?(state)
  end

  defp single_character?(key) do
    binary?(key) and byte_size(key) == 1
  end

  defp search_enabled_and_focused?(state) do
    state.enable_search and state.is_search_focused
  end

  defp handle_character_key(key, state) do
    {new_state, _} = update({:search, state.search_buffer <> key}, state)
    {new_state, nil}
  end

  defp handle_tab_key(state) do
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

  defp handle_backspace_key(state) do
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
  end
end
