defmodule Raxol.Terminal.Emulator.Delegations do
  @moduledoc """
  Contains all the function delegations from the main Emulator module.
  This separates the coordination logic from the pure delegation patterns.
  """

  alias Raxol.Terminal.{
    Operations.CursorOperations,
    Operations.ScreenOperations,
    Operations.TextOperations,
    Operations.SelectionOperations,
    Operations.ScrollOperations,
    Operations.StateOperations,
    Emulator.BufferOperations,
    Emulator.Dimensions
  }

  @doc """
  Defines cursor operation delegations.
  """
  defmacro cursor_delegations do
    quote do
      # Cursor Operations
      defdelegate get_cursor_position(emulator), to: CursorOperations
      defdelegate set_cursor_position(emulator, x, y), to: CursorOperations
      defdelegate get_cursor_style(emulator), to: CursorOperations
      defdelegate set_cursor_style(emulator, style), to: CursorOperations
      defdelegate cursor_visible?(emulator), to: CursorOperations

      defdelegate get_cursor_visible(emulator),
        to: CursorOperations,
        as: :cursor_visible?

      defdelegate set_cursor_visibility(emulator, visible), to: CursorOperations
      defdelegate cursor_blinking?(emulator), to: CursorOperations
      defdelegate set_cursor_blink(emulator, blinking), to: CursorOperations

      # Alias for blinking? to match expected interface
      defdelegate blinking?(emulator),
        to: CursorOperations,
        as: :cursor_blinking?
    end
  end

  @doc """
  Defines screen operation delegations.
  """
  defmacro screen_delegations do
    quote do
      # Screen Operations
      defdelegate clear_screen(emulator), to: ScreenOperations
      defdelegate clear_line(emulator, line), to: ScreenOperations
      defdelegate erase_display(emulator, mode), to: ScreenOperations
      defdelegate erase_in_display(emulator, mode), to: ScreenOperations
      defdelegate erase_line(emulator, mode), to: ScreenOperations
      defdelegate erase_in_line(emulator, mode), to: ScreenOperations
      defdelegate erase_from_cursor_to_end(emulator), to: ScreenOperations
      defdelegate erase_from_start_to_cursor(emulator), to: ScreenOperations
      defdelegate erase_chars(emulator, count), to: ScreenOperations
    end
  end

  @doc """
  Defines text operation delegations.
  """
  defmacro text_delegations do
    quote do
      # Text Operations
      defdelegate insert_char(emulator, char), to: TextOperations
      defdelegate insert_chars(emulator, count), to: TextOperations
      defdelegate delete_char(emulator), to: TextOperations
      defdelegate delete_chars(emulator, count), to: TextOperations
    end
  end

  @doc """
  Defines selection operation delegations.
  """
  defmacro selection_delegations do
    quote do
      # Selection Operations
      defdelegate start_selection(emulator, x, y), to: SelectionOperations
      defdelegate update_selection(emulator, x, y), to: SelectionOperations
      defdelegate end_selection(emulator), to: SelectionOperations
      defdelegate clear_selection(emulator), to: SelectionOperations
      defdelegate get_selection(emulator), to: SelectionOperations
      defdelegate has_selection?(emulator), to: SelectionOperations
    end
  end

  @doc """
  Defines scroll operation delegations.
  """
  defmacro scroll_delegations do
    quote do
      # Scroll Operations
      defdelegate scroll_up(emulator, lines), to: ScrollOperations
      defdelegate scroll_down(emulator, lines), to: ScrollOperations
    end
  end

  @doc """
  Defines state operation delegations.
  """
  defmacro state_delegations do
    quote do
      # State Operations
      defdelegate save_state(emulator), to: StateOperations
      defdelegate restore_state(emulator), to: StateOperations
    end
  end

  @doc """
  Defines buffer operation delegations.
  """
  defmacro buffer_delegations do
    quote do
      # Buffer Operations
      defdelegate switch_to_alternate_screen(emulator), to: BufferOperations
      defdelegate switch_to_normal_screen(emulator), to: BufferOperations

      # Clear scrollback buffer
      defdelegate clear_scrollback(emulator), to: BufferOperations

      # Buffer management
      defdelegate update_active_buffer(emulator, buffer), to: BufferOperations
      defdelegate write_to_output(emulator, data), to: BufferOperations
    end
  end

  @doc """
  Defines dimension and property delegations.
  """
  defmacro property_delegations do
    quote do
      # Dimension getters
      defdelegate get_width(emulator), to: Dimensions
      defdelegate get_height(emulator), to: Dimensions

      # Scroll region getter
      defdelegate get_scroll_region(emulator), to: Dimensions

      # Cursor visibility getter (alias for cursor_visible?)
      defdelegate visible?(emulator), to: CursorOperations, as: :cursor_visible?
    end
  end
end
