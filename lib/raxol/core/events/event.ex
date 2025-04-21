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

  # alias ExTermbox.Event, as: ExTermboxEvent # Unused
  # alias ExTermbox.Constants, as: ExTermboxConstants # Unused

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
  def mouse(button, position, drag: true)
      when button in [:left, :right, :middle] do
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
  def focus_event(target, focused)
      when target in [:component, :window, :application] do
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

  # Event Conversion removed - moved to Raxol.Core.Events.TermboxConverter
end
