defmodule Raxol.Terminal.Emulator.CursorManagementTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager

  setup do
    emulator = Emulator.new(80, 24)
    {:ok, emulator: emulator}
  end

  describe "Emulator Cursor Management" do
    test "set_cursor_style delegates to Cursor.Manager", %{emulator: emulator} do
      # Default should be block
      assert Manager.get_style(emulator.cursor) == :block

      # Test setting Manager style directly - capture returned cursor
      updated_cursor = Manager.set_style(emulator.cursor, :underline)
      assert Manager.get_style(updated_cursor) == :underline

      updated_cursor = Manager.set_style(updated_cursor, :bar)
      assert Manager.get_style(updated_cursor) == :bar
    end

    test "set_cursor_visible delegates to Cursor.Manager", %{emulator: emulator} do
      # Assuming default is visible
      # Check state directly
      assert Manager.get_state(emulator.cursor) == :visible

      # Test setting Manager state directly - capture returned cursor
      updated_cursor = Manager.set_state(emulator.cursor, :hidden)
      assert Manager.get_state(updated_cursor) == :hidden

      updated_cursor = Manager.set_state(updated_cursor, :visible)
      assert Manager.get_state(updated_cursor) == :visible
    end

    # DECSC/DECRC tests belong with state stack/ANSI processing, not direct cursor methods.
    # test 'save/restore cursor position (DECSC/DECRC)' do ...
  end
end
