defmodule Raxol.Core.Events.Event do
  @moduledoc """
  Defines the structure and types for events in the Raxol system.

  Events represent various types of input and system occurrences, such as:
  * Keyboard input
  * Mouse input
  * Window events
  * System events
  * Custom events

  Each event has a type and associated data specific to that type.
  """

  @type event_type :: atom()

  @type t :: %__MODULE__{
    type: event_type(),
    timestamp: integer(),
    data: term()
  }

  defstruct [:type, :timestamp, :data]

  alias ExTermbox.Event, as: ExTermboxEvent
  alias ExTermbox.Constants, as: ExTermboxConstants

  @doc """
  Creates a new event with the given type and data.
  The timestamp is automatically set to the current system time.
  """
  def new(type, data) do
    %__MODULE__{
      type: type,
      timestamp: System.monotonic_time(),
      data: data
    }
  end

  # Keyboard Events

  @type key :: atom() | String.t()
  @type key_state :: :pressed | :released | :repeat
  @type modifiers :: [atom()]

  @type key_event :: %{
    key: key(),
    state: key_state(),
    modifiers: modifiers()
  }

  @doc """
  Creates a keyboard event.

  ## Parameters
    * `key` - The key that was pressed/released (e.g. :enter, :backspace, "a")
    * `state` - The state of the key (:pressed, :released, :repeat)
    * `modifiers` - List of active modifiers (e.g. [:shift, :ctrl])
  """
  def key_event(key, state, modifiers \\ [])
      when state in [:pressed, :released, :repeat] and is_list(modifiers) do
    new(:key, %{
      key: key,
      state: state,
      modifiers: modifiers
    })
  end

  @doc """
  Creates a simple key event with pressed state and no modifiers.
  """
  def key(key) do
    key_event(key, :pressed, [])
  end

  # Mouse Events

  @type mouse_button :: :left | :right | :middle
  @type mouse_state :: :pressed | :released | :double_click
  @type mouse_position :: {non_neg_integer(), non_neg_integer()}

  @type mouse_event :: %{
    button: mouse_button() | nil,
    state: mouse_state() | nil,
    position: mouse_position(),
    modifiers: modifiers()
  }

  @doc """
  Creates a mouse event.

  ## Parameters
    * `button` - The mouse button (:left, :right, :middle)
    * `position` - The mouse position as {x, y}
    * `state` - The button state (:pressed, :released, :double_click)
    * `modifiers` - List of active modifiers (e.g. [:shift, :ctrl])
  """
  def mouse_event(button, position, state \\ :pressed, modifiers \\ [])
      when button in [:left, :right, :middle] and
           state in [:pressed, :released, :double_click] and
           is_tuple(position) and
           is_list(modifiers) do
    new(:mouse, %{
      button: button,
      position: position,
      state: state,
      modifiers: modifiers
    })
  end

  @doc """
  Creates a simple mouse event with pressed state and no modifiers.
  """
  def mouse(button, position) when button in [:left, :right, :middle] do
    mouse_event(button, position)
  end

  @doc """
  Creates a mouse event with drag state.
  """
  def mouse(button, position, drag: true) when button in [:left, :right, :middle] do
    new(:mouse, %{
      button: button,
      position: position,
      state: :pressed,
      drag: true,
      modifiers: []
    })
  end

  # Window Events

  @type window_event :: %{
    width: non_neg_integer(),
    height: non_neg_integer(),
    action: :resize | :focus | :blur
  }

  @doc """
  Creates a window event.

  ## Parameters
    * `width` - The window width
    * `height` - The window height
    * `action` - The window action (:resize, :focus, :blur)
  """
  def window_event(width, height, action)
      when is_integer(width) and is_integer(height) and
           action in [:resize, :focus, :blur] do
    new(:window, %{
      width: width,
      height: height,
      action: action
    })
  end

  @doc """
  Creates a simple window event.
  """
  def window(width, height, action) when action in [:resize, :focus, :blur] do
    window_event(width, height, action)
  end

  # Timer Events

  @doc """
  Creates a timer event.

  ## Parameters
    * `data` - Timer-specific data
  """
  def timer_event(data) do
    new(:timer, data)
  end

  @doc """
  Creates a simple timer event.
  """
  def timer(data) do
    timer_event(data)
  end

  # Custom Events

  @doc """
  Creates a custom event.

  ## Parameters
    * `data` - Custom event data
  """
  def custom_event(data) do
    new(:custom, data)
  end

  @doc """
  Creates a simple custom event.
  """
  def custom(data) do
    custom_event(data)
  end

  # Terminal UI Events

  @type focus_target :: :component | :window | :application
  @type focus_event :: %{
    target: focus_target(),
    focused: boolean()
  }

  @doc """
  Creates a focus event.

  ## Parameters
    * `target` - What received/lost focus
    * `focused` - Whether focus was gained (true) or lost (false)
  """
  def focus_event(target, focused) when target in [:component, :window, :application] do
    new(:focus, %{
      target: target,
      focused: focused
    })
  end

  @type scroll_direction :: :vertical | :horizontal
  @type scroll_event :: %{
    direction: scroll_direction(),
    delta: integer(),
    position: {non_neg_integer(), non_neg_integer()}
  }

  @doc """
  Creates a scroll event.

  ## Parameters
    * `direction` - Scroll direction
    * `delta` - Amount scrolled (positive or negative)
    * `position` - Current scroll position
  """
  def scroll_event(direction, delta, position)
      when direction in [:vertical, :horizontal] and is_integer(delta) do
    new(:scroll, %{
      direction: direction,
      delta: delta,
      position: position
    })
  end

  @type cursor_event :: %{
    visible: boolean(),
    style: :block | :line | :underscore,
    blink: boolean(),
    position: {non_neg_integer(), non_neg_integer()}
  }

  @doc """
  Creates a cursor event.

  ## Parameters
    * `visible` - Whether cursor is visible
    * `style` - Cursor style
    * `blink` - Whether cursor should blink
    * `position` - Cursor position
  """
  def cursor_event(visible, style, blink, position)
      when is_boolean(visible) and style in [:block, :line, :underscore] and
           is_boolean(blink) and is_tuple(position) do
    new(:cursor, %{
      visible: visible,
      style: style,
      blink: blink,
      position: position
    })
  end

  @type selection_event :: %{
    start_pos: {non_neg_integer(), non_neg_integer()},
    end_pos: {non_neg_integer(), non_neg_integer()},
    text: String.t()
  }

  @doc """
  Creates a selection event.

  ## Parameters
    * `start_pos` - Selection start position
    * `end_pos` - Selection end position
    * `text` - Selected text
  """
  def selection_event(start_pos, end_pos, text)
      when is_tuple(start_pos) and is_tuple(end_pos) and is_binary(text) do
    new(:selection, %{
      start_pos: start_pos,
      end_pos: end_pos,
      text: text
    })
  end

  @type paste_event :: %{
    text: String.t(),
    position: {non_neg_integer(), non_neg_integer()}
  }

  @doc """
  Creates a paste event.

  ## Parameters
    * `text` - Pasted text
    * `position` - Paste position
  """
  def paste_event(text, position) when is_binary(text) and is_tuple(position) do
    new(:paste, %{
      text: text,
      position: position
    })
  end

  # Event Conversion

  @doc """
  Converts a raw event (e.g., from ExTermbox) into a Raxol event.
  """
  @spec convert(ExTermboxEvent.t()) :: t()
  def convert(%ExTermboxEvent{type: :key, mod: mod, key: key_code, ch: char_code}) do
    # TODO: Refine mapping of ExTermbox key/char/mod codes
    key = if key_code != 0, do: map_key_code(key_code), else: <<char_code>>
    modifiers = map_modifiers(mod)
    key_event(key, :pressed, modifiers)
  end

  def convert(%ExTermboxEvent{type: :resize, w: width, h: height}) do
    window_event(width, height, :resize)
  end

  def convert(%ExTermboxEvent{type: :mouse, key: button_code, x: x, y: y, mod: mod}) do
    # TODO: Refine mapping of ExTermbox mouse button/mod codes
    button = map_button_code(button_code)
    modifiers = map_modifiers(mod)
    mouse_event(button, {x, y}, :pressed, modifiers)
  end

  # --- Private Conversion Helpers ---

  # Requires constants from ExTermbox.Constants
  defp map_key_code(code) do
    # Using cond and calling the correct constant lookup functions
    cond do
      code == ExTermboxConstants.key(:f1) -> :f1
      code == ExTermboxConstants.key(:f2) -> :f2
      code == ExTermboxConstants.key(:f3) -> :f3
      code == ExTermboxConstants.key(:f4) -> :f4
      code == ExTermboxConstants.key(:f5) -> :f5
      code == ExTermboxConstants.key(:f6) -> :f6
      code == ExTermboxConstants.key(:f7) -> :f7
      code == ExTermboxConstants.key(:f8) -> :f8
      code == ExTermboxConstants.key(:f9) -> :f9
      code == ExTermboxConstants.key(:f10) -> :f10
      code == ExTermboxConstants.key(:f11) -> :f11
      code == ExTermboxConstants.key(:f12) -> :f12
      code == ExTermboxConstants.key(:insert) -> :insert
      code == ExTermboxConstants.key(:delete) -> :delete
      code == ExTermboxConstants.key(:home) -> :home
      code == ExTermboxConstants.key(:end) -> :end
      code == ExTermboxConstants.key(:pgup) -> :page_up
      code == ExTermboxConstants.key(:pgdn) -> :page_down
      code == ExTermboxConstants.key(:arrow_up) -> :up
      code == ExTermboxConstants.key(:arrow_down) -> :down
      code == ExTermboxConstants.key(:arrow_left) -> :left
      code == ExTermboxConstants.key(:arrow_right) -> :right
      code == ExTermboxConstants.key(:ctrl_tilde) -> {:ctrl, :tilde}
      # ... map other special keys ...
      code == ExTermboxConstants.key(:esc) -> :escape
      code == ExTermboxConstants.key(:enter) -> :enter
      code == ExTermboxConstants.key(:space) -> :space
      code == ExTermboxConstants.key(:backspace2) -> :backspace # Or KEY_BACKSPACE?
      code == ExTermboxConstants.key(:tab) -> :tab
      true -> {:unknown_key, code}
    end
  end

  defp map_modifiers(mod) do
    # Modifier constants seem to be missing from ExTermbox.Constants?
    # Using hardcoded values based on common practice (needs verification)
    # Or potentially they are attributes?
    # mod_shift = ExTermboxConstants.attribute(:bold) # Placeholder - incorrect!
    # mod_ctrl = ExTermboxConstants.attribute(:underline) # Placeholder - incorrect!
    # mod_alt = ExTermboxConstants.attribute(:reverse) # Placeholder - incorrect!

    mods = []
    mods = if Bitwise.band(mod, 4) != 0, do: [:shift | mods], else: mods # 0x4 for Shift
    mods = if Bitwise.band(mod, 8) != 0, do: [:alt | mods], else: mods # 0x8 for Alt
    mods = if Bitwise.band(mod, 16) != 0, do: [:ctrl | mods], else: mods # 0x10 for Ctrl
    Enum.reverse(mods)
  end

  defp map_button_code(code) do
    # Using cond and calling the correct constant lookup functions
    cond do
      code == ExTermboxConstants.key(:mouse_left) -> :left
      code == ExTermboxConstants.key(:mouse_right) -> :right
      code == ExTermboxConstants.key(:mouse_middle) -> :middle
      code == ExTermboxConstants.key(:mouse_wheel_up) -> :wheel_up
      code == ExTermboxConstants.key(:mouse_wheel_down) -> :wheel_down
      code == ExTermboxConstants.key(:mouse_release) -> :release # This is a key, not a button state
      true -> nil
    end
  end
end
