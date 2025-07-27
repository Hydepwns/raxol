defmodule Raxol.Terminal.Emulator.TextOperations do
  @moduledoc """
  Text operation functions extracted from the main emulator module.
  Handles text writing with charset translation and cursor updates.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Emulator.{Helpers, BufferOperations}

  @type emulator :: Emulator.t()

  @doc """
  Writes a string to the terminal with charset translation.
  Updates cursor position after writing.
  """
  @spec write_string(
          emulator(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map()
        ) :: emulator()
  def write_string(%Emulator{} = emulator, x, y, string, style \\ %{}) do
    translated =
      Raxol.Terminal.ANSI.CharacterSets.translate_string(
        string,
        emulator.charset_state
      )

    # Get the active buffer
    buffer = BufferOperations.get_screen_buffer(emulator)

    # Write the string to the buffer
    updated_buffer =
      ScreenBuffer.write_string(buffer, x, y, translated, style)

    # Update cursor position after writing
    cursor = Helpers.get_cursor_struct(emulator)
    new_x = x + String.length(translated)
    new_cursor = %{cursor | col: new_x, row: y, position: {new_x, y}}

    # Update the appropriate buffer
    emulator =
      case emulator.active_buffer_type do
        :main ->
          %{emulator | main_screen_buffer: updated_buffer, cursor: new_cursor}

        :alternate ->
          %{
            emulator
            | alternate_screen_buffer: updated_buffer,
              cursor: new_cursor
          }
      end

    emulator
  end

  @doc """
  Sets an attribute on the emulator (placeholder implementation).
  """
  @spec set_attribute(emulator(), atom(), any()) :: emulator()
  def set_attribute(emulator, _attribute, _value) do
    # Currently a no-op, but structured for future attribute handling
    # Could be extended to handle text styling attributes
    emulator
  end
end
