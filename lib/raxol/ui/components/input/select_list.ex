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
          # Made options mandatory in props
          :options => options(),
          optional(:label) => String.t(),
          optional(:on_select) => (any() -> any()),
          optional(:on_cancel) => (-> any()) | nil,
          optional(:on_change) => (any() -> any()) | nil,
          optional(:on_focus) => (integer() -> any()) | nil,
          optional(:theme) => map(),
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
          # Props merged into state
          :id => String.t() | nil,
          :options => options(),
          :label => String.t() | nil,
          :on_select => (any() -> any()) | nil,
          :on_cancel => (-> any()) | nil,
          :on_change => (any() -> any()) | nil,
          :on_focus => (integer() -> any()) | nil,
          :theme => map() | nil,
          :max_height => integer() | nil,
          :enable_search => boolean(),
          :multiple => boolean(),
          :searchable_fields => list(atom()) | nil,
          :placeholder => String.t(),
          :empty_message => String.t(),
          :show_pagination => boolean(),

          # Internal state
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
          :search_timer => reference() | nil
        }

  # --- Component Implementation ---

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
      search_timer: nil
    }

    # Merge validated props with default internal state
    Map.merge(defaults, props)
  end

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
    Map.merge(updated_state, new_props)
  end

  def update({:search, search_text}, state) do
    # Cancel any existing timer
    if state.search_timer do
      Process.cancel_timer(state.search_timer)
    end

    # Schedule new search
    timer_ref = Process.send_after(self(), {:apply_search, search_text}, 300)

    # Update buffer immediately
    %{state | search_buffer: search_text, search_timer: timer_ref}
  end

  def update({:apply_search, search_text}, state) do
    Search.update_search_state(%{state | search_text: search_text, search_timer: nil}, search_text)
  end

  def update({:select_option, index}, state) do
    Selection.update_selection_state(state, index)
  end

  def update({:set_page, page_num}, state) do
    Pagination.update_page_state(state, page_num)
  end

  def update({:set_focus, has_focus}, state) do
    new_state = %{state | has_focus: has_focus}

    # Call on_focus callback if provided
    if has_focus and state.on_focus do
      state.on_focus.(state.focused_index)
    end

    new_state
  end

  def update({:toggle_search_focus}, state) do
    # Only toggle if search is enabled
    if state.enable_search do
      new_state = %{state | is_search_focused: !state.is_search_focused}

      # If focusing search, clear any existing search
      if new_state.is_search_focused do
        %{new_state | search_text: "", search_buffer: "", filtered_options: nil, is_filtering: false}
      else
        new_state
      end
    else
      state
    end
  end

  def update({:set_visible_height, height}, state) do
    # Update the visible height based on available space
    %{state | visible_height: height}
  end

  def update(_message, state) do
    # Other messages aren't handled, return state unchanged
    state
  end

  @impl true
  def handle_event(event, state, _context) do
    case event do
      {:key, :up} ->
        handle_key_up(state)
      {:key, :down} ->
        handle_key_down(state)
      {:key, :enter} ->
        handle_enter(state)
      {:key, :backspace} ->
        handle_backspace(state)
      {:mouse, :click, _x, y} ->
        handle_mouse_click(y, state)
      {:focus, :gain} ->
        handle_focus_gain(state)
      {:focus, :lose} ->
        handle_focus_lose(state)
      {:resize, _width, _height} ->
        handle_resize(state)
      _ ->
        state
    end
  end

  @impl true
  def render(state) do
    Renderer.render(state)
  end

  # --- Private Helper Functions ---

  defp validate_props!(props) do
    unless Map.has_key?(props, :options) do
      raise ArgumentError, "SelectList requires :options prop"
    end

    unless is_list(props.options) do
      raise ArgumentError, "SelectList :options must be a list"
    end

    # Validate each option
    Enum.each(props.options, fn option ->
      unless is_tuple(option) and tuple_size(option) == 2 do
        raise ArgumentError, "SelectList options must be {label, value} tuples"
      end

      {label, _value} = option
      unless is_binary(label) do
        raise ArgumentError, "SelectList option labels must be strings"
      end
    end)
  end

  defp handle_key_up(state) do
    if state.focused_index > 0 do
      new_index = state.focused_index - 1
      Navigation.update_focus_state(state, new_index)
    else
      state
    end
  end

  defp handle_key_down(state) do
    options = state.filtered_options || state.options
    if state.focused_index < length(options) - 1 do
      new_index = state.focused_index + 1
      Navigation.update_focus_state(state, new_index)
    else
      state
    end
  end

  defp handle_enter(state) do
    if state.focused_index >= 0 do
      Selection.update_selection_state(state, state.focused_index)
    else
      state
    end
  end

  defp handle_backspace(state) do
    if state.is_search_focused and state.search_buffer != "" do
      new_buffer = String.slice(state.search_buffer, 0..-2)
      update({:search, new_buffer}, state)
    else
      state
    end
  end

  defp handle_focus_gain(state) do
    update({:set_focus, true}, state)
  end

  defp handle_focus_lose(state) do
    update({:set_focus, false}, state)
  end

  defp handle_resize(state) do
    # Recalculate visible height and update scroll position if needed
    if state.visible_height do
      Navigation.update_scroll_position(state)
    else
      state
    end
  end

  defp handle_mouse_click(y, state) do
    # Calculate which option was clicked based on y position
    # and update focus/selection accordingly
    if state.visible_height do
      index = Navigation.calculate_clicked_index(y, state)
      if index >= 0 and index < length(state.options) do
        Selection.update_selection_state(state, index)
      else
        state
      end
    else
      state
    end
  end
end
