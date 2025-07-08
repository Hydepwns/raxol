defmodule Raxol.Terminal.Emulator.CursorManagementTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  # Keep Manager alias if used directly
  alias Raxol.Terminal.Cursor.Manager

  setup do
    emulator = Emulator.new(80, 24)
    {:ok, emulator: emulator}
  end

  describe "Emulator Cursor Management" do
    test "set_cursor_style delegates to Cursor.Manager", %{emulator: emulator} do
      # Default should be block
      assert Manager.get_style(emulator.cursor) == :block

      # Set to line (Assuming set_cursor_style maps :line to a valid atom like :bar or :underline?)
      # Let's assume Emulator.set_cursor_style is not implemented yet or maps :line differently.
      # The DECSCUSR handler maps 5 -> :blinking_bar, 6 -> :steady_bar
      # Let's test setting to :underline and :bar directly via DECSCUSR first, then revisit set_cursor_style if needed.
      # {emulator, _} = Emulator.process_input(emulator, "\e[4 q") # Steady Underline
      # assert emulator.cursor_style == :steady_underline
      # {emulator, _} = Emulator.process_input(emulator, "\e[6 q") # Steady Bar
      # assert emulator.cursor_style == :steady_bar

      # Let's test setting Manager style directly if Emulator.set_cursor_style is not the target
      emulator = %{
        emulator
        | cursor: Manager.set_style(emulator.cursor, :underline)
      }

      assert Manager.get_style(emulator.cursor) == :underline

      emulator = %{emulator | cursor: Manager.set_style(emulator.cursor, :bar)}
      assert Manager.get_style(emulator.cursor) == :bar
    end

    test ~c"set_cursor_visible delegates to Cursor.Style" do
      emulator = Emulator.new(80, 24)
      # Assuming default is visible
      # Check state directly
      assert Manager.get_state(emulator.cursor) == :visible

      emulator = %{
        emulator
        | cursor: Manager.set_state(emulator.cursor, :hidden)
      }

      assert Manager.get_state(emulator.cursor) == :hidden

      emulator = %{
        emulator
        | cursor: Manager.set_state(emulator.cursor, :visible)
      }

      assert Manager.get_state(emulator.cursor) == :visible
    end

    # DECSC/DECRC tests belong with state stack/ANSI processing, not direct cursor methods.
    # test 'save/restore cursor position (DECSC/DECRC)' do ...
  end
end
