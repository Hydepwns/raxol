defmodule Raxol.UI.Components.Input.SelectList do
  @moduledoc """
  A component that allows users to select an option from a list.

  Allows single or multiple selections.
  * Supports scrolling for long lists.
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
          optional(:theme) => map(),
          optional(:max_height) => integer() | nil
        }

  # State now includes props and internal state
  @type state :: %{
          # Props merged into state
          :id => String.t() | nil,
          :options => options(),
          :label => String.t() | nil,
          # Adjusted type
          :on_select => (any() -> any()) | nil,
          :on_cancel => (-> any()) | nil,
          :theme => map() | nil,
          :max_height => integer() | nil,
          # Internal state
          :focused_index => integer(),
          :scroll_offset => integer()
        }

  # Removed @type t

  # --- Component Implementation ---

  @impl true
  def init(props) do
    validate_props!(props)
    # Merge validated props with default internal state
    Map.merge(props, %{
      focused_index: 0,
      scroll_offset: 0
    })
  end

  @impl true
  def update({:update_props, new_props}, state) do
    validate_props!(new_props)
    # Reset focus/scroll if options change? For now, just merge.
    # Consider smarter merging if needed.
    Map.merge(state, new_props)
  end

  def update(_message, state) do
    # No other messages currently handled, return state unchanged
    state
  end

  @impl true
  def handle_event(event, state, _context) do
    case event do
      {:key_press, :arrow_up, _} ->
        {handle_arrow_up(state), []}

      {:key_press, :arrow_down, _} ->
        {handle_arrow_down(state), []}

      {:key_press, :enter, _} ->
        # Callbacks run synchronously
        {handle_select(state), []}

      {:key_press, :escape, _} ->
        # Callbacks run synchronously
        {handle_cancel(state), []}

      _ ->
        # Ignore other events, return unchanged state and no commands
        {state, []}
    end
  end

  @impl true
  def render(state, context) do
    # Access props/state directly from the state map
    theme_config = Map.get(context.theme, :select_list, %{})
    component_theme = Map.get(state, :theme, %{})
    theme = Map.merge(theme_config, component_theme)

    colors = %{
      label: Map.get(theme, :label_fg, :cyan),
      option_fg: Map.get(theme, :option_fg, :white),
      option_bg: Map.get(theme, :option_bg, :black),
      focused_fg: Map.get(theme, :focused_fg, :black),
      focused_bg: Map.get(theme, :focused_bg, :cyan)
    }

    # Access from state
    label_element =
      if label = state[:label] do
        [%{type: :text, text: label, y: 0, attrs: %{fg: colors.label}}]
      else
        []
      end

    # Access from state
    label_height = if state[:label], do: 1, else: 0

    # Determine visible range
    # Access from state
    max_h = state[:max_height]
    # Access from state
    options = state[:options]
    option_count = length(options)

    visible_height =
      cond do
        is_integer(max_h) and max_h > label_height -> max_h - label_height
        # Default to full height if max_height is nil or too small
        true -> option_count
      end

    # Ensure visible height is at least 1 if there are options
    visible_height = if option_count > 0, do: max(1, visible_height), else: 0

    {start_index, end_index, _new_scroll_offset} =
      calculate_visible_range(
        state.focused_index,
        state.scroll_offset,
        option_count,
        visible_height
      )

    # Note: Scroll offset calculation depends on render-time info (visible_height).
    # Ideally, state changes should only happen in update/handle_event.
    # This implies state.scroll_offset might not be perfectly up-to-date here if
    # max_height changes dynamically.
    # For now, we use the calculated start_index based on potentially stale scroll_offset
    # and the current focused_index.

    visible_options =
      if option_count > 0 do
        Enum.slice(options, start_index, end_index - start_index + 1)
      else
        []
      end

    option_elements =
      Enum.with_index(visible_options, start_index)
      |> Enum.map(fn {{opt_label, _opt_value}, index} ->
        is_focused = index == state.focused_index

        render_option(
          opt_label,
          is_focused,
          colors,
          # Calculate y-position
          index - start_index + label_height
        )
      end)

    label_element ++ option_elements
  end

  # --- Private Helper Functions ---

  defp validate_props!(props) do
    if !Map.has_key?(props, :options) or !is_list(props.options) do
      raise ArgumentError, ":options prop must be a list and is required"
    end

    # Add other validations (e.g., option format) if needed
  end

  # Helpers now accept and return state
  defp handle_arrow_up(state) do
    current_index = state.focused_index
    new_index = max(0, current_index - 1)

    if new_index != current_index do
      # Scroll offset is recalculated during render based on focused_index
      %{state | focused_index: new_index}
    else
      # Already at the top
      state
    end
  end

  defp handle_arrow_down(state) do
    current_index = state.focused_index
    option_count = length(state.options)
    new_index = min(option_count - 1, current_index + 1)

    if new_index != current_index do
      # Scroll offset is recalculated during render based on focused_index
      %{state | focused_index: new_index}
    else
      # Already at the bottom
      state
    end
  end

  defp handle_select(state) do
    if on_select = state[:on_select] do
      selected_index = state.focused_index

      case Enum.at(state.options, selected_index) do
        {_label, value} ->
          # Execute callback
          on_select.(value)
          # Return unchanged state
          state

        nil ->
          # Should not happen if index is valid
          # Log error?
          # Return unchanged state
          state
      end
    else
      # No callback provided
      state
    end
  end

  defp handle_cancel(state) do
    if on_cancel = state[:on_cancel] do
      # Execute callback
      on_cancel.()
    end

    # Return unchanged state
    state
  end

  # Calculates the start/end index of visible options and adjusted scroll offset
  defp calculate_visible_range(
         focused_index,
         scroll_offset,
         option_count,
         visible_height
       ) do
    # Ensure visible_height is at least 1 if scrolling is possible and options exist
    visible_height = if option_count > 0, do: max(1, visible_height), else: 0

    # If no height, show nothing
    if visible_height == 0 do
      {0, -1, 0}
    else
      new_scroll_offset =
        cond do
          focused_index < scroll_offset ->
            # Focused item is above the visible window
            focused_index

          focused_index >= scroll_offset + visible_height ->
            # Focused item is below the visible window
            focused_index - visible_height + 1

          true ->
            # Focused item is within the visible window
            scroll_offset
        end

      # Clamp scroll offset
      max_scroll = max(0, option_count - visible_height)
      new_scroll_offset = clamp(new_scroll_offset, 0, max_scroll)

      start_index = new_scroll_offset
      # Adjust end_index calculation for empty list case
      end_index =
        if option_count > 0,
          do: min(option_count - 1, new_scroll_offset + visible_height - 1),
          else: -1

      {start_index, end_index, new_scroll_offset}
    end
  end

  # Clamp helper
  defp clamp(val, min_val, max_val) do
    max(min_val, min(val, max_val))
  end

  defp render_option(label, is_focused, colors, y_pos) do
    attrs = %{
      fg: if(is_focused, do: colors.focused_fg, else: colors.option_fg),
      bg: if(is_focused, do: colors.focused_bg, else: colors.option_bg)
    }

    %{type: :text, text: " #{label} ", y: y_pos, attrs: attrs}
  end

  # Optional callbacks mount/unmount have defaults from `use Component`
end
