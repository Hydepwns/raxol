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

  # use Raxol.UI.Components.Base
  # alias Raxol.UI.Element # Unused
  # alias Raxol.UI.Layout.Constraints # Unused
  # alias Raxol.UI.Theming.Theme # Unused
  # alias Raxol.UI.Components.Base.Component # Unused
  # alias Raxol.UI.Style # Unused
  # alias Raxol.UI.Components.Input.SelectList # Unused (self-alias)
  # alias Raxol.Core.Events # Unused
  # alias Raxol.Core.Events.{FocusEvent, KeyEvent} # Unused

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
          :search_buffer => String.t()
        }

  # Removed @type t

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
      search_buffer: ""
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
      if Map.has_key?(new_props, :options) and new_props.options != state.options do
        Map.merge(reset_state, %{
          filtered_options: nil,
          is_filtering: false,
          # Preserve selection if possible, otherwise reset
          focused_index: 0,
          scroll_offset: 0
        })
      else
        reset_state
      end

    # Merge everything together, with new_props taking precedence
    updated_state = Map.merge(state, reset_state)
    Map.merge(updated_state, new_props)
  end

  def update({:search, search_text}, state) do
    # Update search text and filter options
    %{state |
      search_text: search_text,
      is_filtering: search_text != "",
      filtered_options: filter_options(state.options, search_text, state.searchable_fields),
      focused_index: 0,  # Reset focus to first matching item
      scroll_offset: 0   # Reset scroll position
    }
  end

  def update({:select_option, index}, state) do
    updated_indices =
      if state.multiple do
        # Toggle selection for multiple select
        if MapSet.member?(state.selected_indices, index) do
          MapSet.delete(state.selected_indices, index)
        else
          MapSet.put(state.selected_indices, index)
        end
      else
        # Single selection - replace with just this index
        MapSet.new([index])
      end

    # Update state with new selection
    %{state |
      selected_indices: updated_indices,
      focused_index: index
    }
  end

  def update({:set_page, page_num}, state) do
    effective_options = get_effective_options(state)
    total_pages = calculate_total_pages(length(effective_options), state.page_size)

    # Ensure page number is valid
    valid_page = max(0, min(page_num, total_pages - 1))

    # Calculate new focused index based on page change
    new_focused_index = valid_page * state.page_size

    # Clamp to valid option range
    clamped_focus = min(new_focused_index, max(0, length(effective_options) - 1))

    %{state |
      current_page: valid_page,
      focused_index: clamped_focus,
      scroll_offset: valid_page * state.page_size
    }
  end

  def update({:set_focus, has_focus}, state) do
    %{state | has_focus: has_focus}
  end

  def update({:toggle_search_focus}, state) do
    # Only toggle if search is enabled
    if state.enable_search do
      %{state | is_search_focused: !state.is_search_focused}
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
  def handle_event(event, state, context) do
    case event do
      # Handle basic navigation
      {:key_press, :arrow_up, _} ->
        {handle_arrow_up(state), []}

      {:key_press, :arrow_down, _} ->
        {handle_arrow_down(state), []}

      {:key_press, :page_up, _} ->
        {handle_page_up(state), []}

      {:key_press, :page_down, _} ->
        {handle_page_down(state), []}

      {:key_press, :home, _} ->
        {handle_home(state), []}

      {:key_press, :end, _} ->
        {handle_end(state), []}

      # Handle selection
      {:key_press, :enter, _} ->
        {state2, commands} = handle_select(state)
        {state2, commands}

      # Handle cancellation
      {:key_press, :escape, _} ->
        # If we're searching, clear search first; otherwise cancel
        if state.is_filtering do
          {update({:search, ""}, state), []}
        else
          {handle_cancel(state), []}
        end

      # Handle tab to switch between search box and list
      {:key_press, :tab, %{shift: shift}} ->
        if state.enable_search do
          {update({:toggle_search_focus}, state), []}
        else
          {state, []}
        end

      # Handle space for multiple selection toggle
      {:key_press, :space, _} when state.multiple ->
        index = state.focused_index
        {update({:select_option, index}, state), []}

      # Handle search input (when search box focused)
      {:key_press, :backspace, _} when state.is_search_focused ->
        # Delete last character from search
        new_search = String.slice(state.search_text, 0..-2)
        {update({:search, new_search}, state), []}

      # Handle printable characters for incremental search
      {:key_press, key, _} when is_binary(key) ->
        if state.is_search_focused do
          # Append to search text when search box is focused
          new_search = state.search_text <> key
          {update({:search, new_search}, state), []}
        else
          # Incremental search in the list (type-ahead)
          {handle_incremental_search(state, key), []}
        end

      # Handle focus gain/loss
      {:focus, true} ->
        previous_focus = state.has_focus
        updated_state = update({:set_focus, true}, state)
        commands =
          if !previous_focus and updated_state.on_focus do
            # Call on_focus with the focused index
            [fn -> updated_state.on_focus.(updated_state.focused_index) end]
          else
            []
          end
        {updated_state, commands}

      {:focus, false} ->
        {update({:set_focus, false}, state), []}

      # Handle mouse clicks on options
      {:click, x, y, _button} ->
        # Calculate which option was clicked based on y position
        clicked_index = calculate_clicked_index(state, y)

        if clicked_index != nil do
          # Select the clicked option
          updated_state = update({:select_option, clicked_index}, state)
          commands =
            if updated_state.on_focus do
              [fn -> updated_state.on_focus.(clicked_index) end]
            else
              []
            end
          {updated_state, commands}
        else
          # Check if search box was clicked
          if state.enable_search and y == 0 and state.label == nil do
            {update({:toggle_search_focus}, state), []}
          else
            {state, []}
          end
        end

      # Handle pagination clicks
      {:pagination_prev} ->
        {update({:set_page, state.current_page - 1}, state), []}

      {:pagination_next} ->
        {update({:set_page, state.current_page + 1}, state), []}

      _ ->
        # Ignore other events
        {state, []}
    end
  end

  @impl true
  def render(state, context) do
    # Get theme configuration
    theme_config = Map.get(context.theme || %{}, :select_list, %{})
    component_theme = Map.get(state, :theme, %{})
    theme = Map.merge(theme_config, component_theme)

    colors = %{
      label: Map.get(theme, :label_fg, :cyan),
      option_fg: Map.get(theme, :option_fg, :white),
      option_bg: Map.get(theme, :option_bg, :black),
      focused_fg: Map.get(theme, :focused_fg, :black),
      focused_bg: Map.get(theme, :focused_bg, :cyan),
      selected_fg: Map.get(theme, :selected_fg, :black),
      selected_bg: Map.get(theme, :selected_bg, :green),
      search_fg: Map.get(theme, :search_fg, :white),
      search_bg: Map.get(theme, :search_bg, :blue),
      search_placeholder_fg: Map.get(theme, :search_placeholder_fg, :gray),
      empty_fg: Map.get(theme, :empty_fg, :gray),
      pagination_fg: Map.get(theme, :pagination_fg, :white),
      pagination_bg: Map.get(theme, :pagination_bg, :blue)
    }

    # Start building elements
    elements = []

    # Add label if present
    label_height = 0
    {elements, label_height} =
      if label = state[:label] do
        {[%{type: :text, text: label, y: 0, attrs: %{fg: colors.label}} | elements], 1}
      else
        {elements, 0}
      end

    # Add search box if enabled
    search_height = 0
    {elements, search_height} =
      if state.enable_search do
        search_text = if state.search_text == "", do: state.placeholder, else: state.search_text
        search_fg = if state.search_text == "", do: colors.search_placeholder_fg, else: colors.search_fg
        search_style = if state.is_search_focused, do: %{fg: search_fg, bg: colors.search_bg}, else: %{fg: search_fg}

        search_element = %{
          type: :text,
          text: "🔍 #{search_text}",
          y: label_height,
          attrs: search_style
        }

        {[search_element | elements], 1}
      else
        {elements, 0}
      end

    # Total offset for options
    options_offset = label_height + search_height

    # Get effective options (filtered or all)
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    # Handle empty state
    if option_count == 0 do
      empty_element = %{
        type: :text,
        text: state.empty_message,
        y: options_offset,
        attrs: %{fg: colors.empty_fg}
      }

      [empty_element | elements]
    end

    # Calculate visible height based on available space and max_height
    calculated_visible_height =
      cond do
        is_integer(state.visible_height) ->
          state.visible_height - options_offset
        is_integer(state.max_height) and state.max_height > options_offset ->
          state.max_height - options_offset
        true ->
          option_count # Default to showing all options
      end

    # Ensure visible height is at least 1 and doesn't exceed option count
    visible_height = max(1, min(calculated_visible_height, option_count))

    # If paginated, adjust visible range
    {start_index, end_index, new_scroll_offset} =
      if state.show_pagination do
        # In paginated mode, use current_page to determine visible range
        page_start = state.current_page * state.page_size
        page_end = min(option_count - 1, page_start + state.page_size - 1)
        {page_start, page_end, page_start}
      else
        # In scrolling mode, calculate visible range based on focus
        calculate_visible_range(
          state.focused_index,
          state.scroll_offset,
          option_count,
          visible_height
        )
      end

    # Slice the options to show only visible ones
    visible_options =
      if option_count > 0 do
        Enum.slice(effective_options, start_index, end_index - start_index + 1)
      else
        []
      end

    # Generate option elements
    option_elements =
      Enum.with_index(visible_options, start_index)
      |> Enum.map(fn {{opt_label, opt_value}, index} ->
        is_focused = index == state.focused_index
        is_selected = MapSet.member?(state.selected_indices, index)

        # Determine style based on focus and selection state
        style = cond do
          is_focused and is_selected ->
            %{fg: colors.selected_fg, bg: colors.selected_bg, underline: true}
          is_focused ->
            %{fg: colors.focused_fg, bg: colors.focused_bg}
          is_selected ->
            %{fg: colors.selected_fg, bg: colors.selected_bg}
          true ->
            %{fg: colors.option_fg, bg: colors.option_bg}
        end

        # Add selection indicator for multiple select
        prefix = if state.multiple, do: (if is_selected, do: "[✓] ", else: "[ ] "), else: ""

        # Calculate y-position accounting for label and search box
        y_pos = index - start_index + options_offset

        %{type: :text, text: "#{prefix}#{opt_label}", y: y_pos, attrs: style}
      end)

    # Add pagination controls if enabled
    pagination_elements =
      if state.show_pagination and option_count > state.page_size do
        total_pages = calculate_total_pages(option_count, state.page_size)
        prev_enabled = state.current_page > 0
        next_enabled = state.current_page < total_pages - 1

        # Y position for pagination controls (after the options)
        pagination_y = options_offset + visible_height

        prev_style = if prev_enabled, do: %{fg: colors.pagination_fg, bg: colors.pagination_bg}, else: %{fg: colors.empty_fg}
        next_style = if next_enabled, do: %{fg: colors.pagination_fg, bg: colors.pagination_bg}, else: %{fg: colors.empty_fg}

        [
          %{type: :text, text: "< Prev", y: pagination_y, x: 0, attrs: prev_style, on_click: :pagination_prev},
          %{type: :text, text: "Page #{state.current_page + 1}/#{total_pages}", y: pagination_y, x: 10, attrs: %{fg: colors.pagination_fg}},
          %{type: :text, text: "Next >", y: pagination_y, x: 20, attrs: next_style, on_click: :pagination_next}
        ]
      else
        []
      end

    # Combine all elements
    elements ++ option_elements ++ pagination_elements
  end

  # --- Private Helper Functions ---

  defp validate_props!(props) do
    if !Map.has_key?(props, :options) or !is_list(props.options) do
      raise ArgumentError, ":options prop must be a list and is required"
    end

    # Validate options format
    Enum.each(props.options, fn
      {label, _value} when is_binary(label) -> :ok
      option -> raise ArgumentError, "Invalid option format: #{inspect(option)}. Expected {String.t(), any()}"
    end)
  end

  # Get effective options (filtered or all)
  defp get_effective_options(state) do
    if state.is_filtering and state.filtered_options != nil do
      state.filtered_options
    else
      state.options
    end
  end

  # Filter options based on search text
  defp filter_options(options, "", _), do: options
  defp filter_options(options, search_text, searchable_fields) do
    search_text = String.downcase(search_text)

    Enum.filter(options, fn {label, value} ->
      # Always search in label
      label_match = String.contains?(String.downcase(label), search_text)

      # If searchable_fields provided and value is a map, search in those fields too
      field_match =
        if is_list(searchable_fields) and is_map(value) do
          Enum.any?(searchable_fields, fn field ->
            field_value = Map.get(value, field)
            is_binary(field_value) and
              String.contains?(String.downcase(field_value), search_text)
          end)
        else
          false
        end

      label_match or field_match
    end)
  end

  # Enhanced keyboard navigation
  defp handle_arrow_up(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      current_index = state.focused_index
      new_index = max(0, current_index - 1)

      updated_state = %{state | focused_index: new_index}

      # Call on_focus callback if provided
      if new_index != current_index and state.on_focus do
        state.on_focus.(new_index)
      end

      # Update scroll offset to ensure focused item is visible
      update_scroll_if_needed(updated_state)
    else
      state
    end
  end

  defp handle_arrow_down(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      current_index = state.focused_index
      new_index = min(option_count - 1, current_index + 1)

      updated_state = %{state | focused_index: new_index}

      # Call on_focus callback if provided
      if new_index != current_index and state.on_focus do
        state.on_focus.(new_index)
      end

      # Update scroll offset to ensure focused item is visible
      update_scroll_if_needed(updated_state)
    else
      state
    end
  end

  defp handle_page_up(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      # Calculate page size
      page_size = state.page_size || 10

      # Move focus up by page_size or to the top
      current_index = state.focused_index
      new_index = max(0, current_index - page_size)

      updated_state = %{state | focused_index: new_index}

      # Call on_focus callback if provided
      if new_index != current_index and state.on_focus do
        state.on_focus.(new_index)
      end

      # Update scroll offset - for page movement, directly set it
      %{updated_state | scroll_offset: max(0, new_index - (page_size / 2))}
    else
      state
    end
  end

  defp handle_page_down(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      # Calculate page size
      page_size = state.page_size || 10

      # Move focus down by page_size or to the bottom
      current_index = state.focused_index
      new_index = min(option_count - 1, current_index + page_size)

      updated_state = %{state | focused_index: new_index}

      # Call on_focus callback if provided
      if new_index != current_index and state.on_focus do
        state.on_focus.(new_index)
      end

      # Update scroll offset - for page movement, directly set it
      max_scroll = max(0, option_count - page_size)
      %{updated_state | scroll_offset: min(max_scroll, new_index - (page_size / 2))}
    else
      state
    end
  end

  defp handle_home(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      current_index = state.focused_index

      # Always move to the first option
      if current_index != 0 and state.on_focus do
        state.on_focus.(0)
      end

      # Reset scroll position to top
      %{state | focused_index: 0, scroll_offset: 0}
    else
      state
    end
  end

  defp handle_end(state) do
    effective_options = get_effective_options(state)
    option_count = length(effective_options)

    if option_count > 0 do
      current_index = state.focused_index
      last_index = option_count - 1

      # Move to the last option
      if current_index != last_index and state.on_focus do
        state.on_focus.(last_index)
      end

      # Calculate appropriate scroll position for last item
      visible_height = state.visible_height || state.max_height || option_count
      scroll_offset = max(0, last_index - visible_height + 1)

      %{state | focused_index: last_index, scroll_offset: scroll_offset}
    else
      state
    end
  end

  defp handle_select(state) do
    effective_options = get_effective_options(state)

    if state.on_select && Enum.count(effective_options) > 0 do
      selected_index = state.focused_index

      case Enum.at(effective_options, selected_index) do
        {_label, value} ->
          updated_state =
            if state.multiple do
              # For multiple select, toggle the selection
              update({:select_option, selected_index}, state)
            else
              # For single select, just update the selected_indices
              updated_indices = MapSet.new([selected_index])
              %{state | selected_indices: updated_indices}
            end

          # For multiple select, don't trigger on_select until explicitly submitted
          if state.multiple do
            {updated_state, []}
          else
            # For single select, trigger on_select immediately
            {updated_state, [fn -> state.on_select.(value) end]}
          end

        nil ->
          # Should not happen if index is valid
          {state, []}
      end
    else
      # No callback provided or no options
      {state, []}
    end
  end

  # Handle cancellation
  defp handle_cancel(state) do
    commands =
      if state.on_cancel do
        [fn -> state.on_cancel.() end]
      else
        []
      end

    {state, commands}
  end

  # Handle incremental search (type-ahead) in the list
  defp handle_incremental_search(state, key) do
    # Get current timestamp
    current_time = System.monotonic_time(:millisecond)

    # Check if we should append to existing buffer or start a new one
    # (append if last key press was less than 1 second ago)
    search_buffer =
      if state.last_key_time && current_time - state.last_key_time < 1000 do
        state.search_buffer <> key
      else
        key
      end

    # Update state with new search buffer and timestamp
    state_with_buffer = %{state |
      search_buffer: search_buffer,
      last_key_time: current_time
    }

    # Search for matching option
    effective_options = get_effective_options(state)

    # Find first option that starts with our search buffer
    search_text = String.downcase(search_buffer)
    matching_index =
      Enum.find_index(effective_options, fn {label, _} ->
        String.starts_with?(String.downcase(label), search_text)
      end)

    # If found, update focus
    if matching_index do
      state_with_focus = %{state_with_buffer | focused_index: matching_index}
      update_scroll_if_needed(state_with_focus)
    else
      state_with_buffer
    end
  end

  # Calculate which option was clicked
  defp calculate_clicked_index(state, y) do
    # Account for label and search box when calculating index
    options_offset =
      (if state[:label], do: 1, else: 0) +
      (if state.enable_search, do: 1, else: 0)

    # Adjust y to get relative position within options list
    relative_y = y - options_offset

    if relative_y >= 0 do
      # Convert y position to option index
      effective_options = get_effective_options(state)

      # Add scroll offset to get the actual index
      potential_index = relative_y + state.scroll_offset

      # Ensure the index is valid
      if potential_index >= 0 && potential_index < length(effective_options) do
        potential_index
      else
        nil
      end
    else
      nil
    end
  end

  # Update scroll offset to ensure focused item is visible
  defp update_scroll_if_needed(state) do
    visible_height = state.visible_height || state.max_height || length(get_effective_options(state))
    options_offset = (if state[:label], do: 1, else: 0) + (if state.enable_search, do: 1, else: 0)
    effective_visible_height = max(1, visible_height - options_offset)

    scroll_offset = state.scroll_offset
    focused_index = state.focused_index

    new_scroll_offset =
      cond do
        # Focused item is above the visible area
        focused_index < scroll_offset ->
          focused_index

        # Focused item is below the visible area
        focused_index >= scroll_offset + effective_visible_height ->
          focused_index - effective_visible_height + 1

        # Focused item is already visible
        true ->
          scroll_offset
      end

    # Clamp scroll offset to valid range
    max_scroll = max(0, length(get_effective_options(state)) - effective_visible_height)
    clamped_scroll = clamp(new_scroll_offset, 0, max_scroll)

    # Update state with new scroll offset if it changed
    if clamped_scroll != scroll_offset do
      %{state | scroll_offset: clamped_scroll}
    else
      state
    end
  end

  # Calculate visible range similar to before but with better handling
  defp calculate_visible_range(
         focused_index,
         scroll_offset,
         option_count,
         visible_height
       ) do
    # Ensure visible_height is at least 1 if there are options
    effective_visible_height = if option_count > 0, do: max(1, visible_height), else: 0

    if effective_visible_height == 0 do
      {0, -1, 0}  # No visible area
    else
      # Calculate new scroll offset to keep focused item visible
      new_scroll_offset =
        cond do
          focused_index < scroll_offset ->
            # Focused item is above the visible window
            focused_index

          focused_index >= scroll_offset + effective_visible_height ->
            # Focused item is below the visible window
            focused_index - effective_visible_height + 1

          true ->
            # Focused item is already visible
            scroll_offset
        end

      # Clamp scroll offset to valid range
      max_scroll = max(0, option_count - effective_visible_height)
      clamped_scroll = clamp(new_scroll_offset, 0, max_scroll)

      # Calculate visible range
      start_index = clamped_scroll
      end_index =
        if option_count > 0 do
          min(option_count - 1, clamped_scroll + effective_visible_height - 1)
        else
          -1
        end

      {start_index, end_index, clamped_scroll}
    end
  end

  # Calculate total pages for pagination
  defp calculate_total_pages(item_count, page_size) do
    ceil(item_count / page_size)
  end

  # Clamp helper
  defp clamp(val, min_val, max_val) do
    max(min_val, min(val, max_val))
  end

  # Render option with appropriate styling
  defp render_option(label, is_focused, colors, y_pos) do
    attrs = %{
      fg: if(is_focused, do: colors.focused_fg, else: colors.option_fg),
      bg: if(is_focused, do: colors.focused_bg, else: colors.option_bg)
    }

    %{type: :text, text: " #{label} ", y: y_pos, attrs: attrs}
  end
end
