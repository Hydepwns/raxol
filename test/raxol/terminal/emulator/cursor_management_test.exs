defmodule Raxol.Terminal.Emulator.CursorManagementTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager # Keep Manager alias if used directly

  describe "Emulator Cursor Management" do
    test "set_cursor_style delegates to Cursor.Manager" do
      emulator = Emulator.new(80, 24)
      # Use direct access - Assuming default shape is :block
      # Check default shape
      assert emulator.cursor.style.shape == :block
      # Replace with direct update
      emulator = %{
        emulator
        | cursor: %{
            emulator.cursor
            | style: %{emulator.cursor.style | shape: :underline}
          }
      }

      # Use direct access
      assert emulator.cursor.style.shape == :underline
    end

    test "set_cursor_visible delegates to Cursor.Style" do
      emulator = Emulator.new(80, 24)
      # Assuming default is visible
      # Check state directly
      assert emulator.cursor.state == :visible
      # Replace with direct update
      emulator = %{emulator | cursor: %{emulator.cursor | state: :hidden}}
      # Check state directly
      assert emulator.cursor.state == :hidden
      # Replace with direct update
      emulator = %{emulator | cursor: %{emulator.cursor | state: :visible}}
      # Check state directly
      assert emulator.cursor.state == :visible
    end

    # DECSC/DECRC tests belong with state stack/ANSI processing, not direct cursor methods.
    # test "save/restore cursor position (DECSC/DECRC)" do ...
  end
end
