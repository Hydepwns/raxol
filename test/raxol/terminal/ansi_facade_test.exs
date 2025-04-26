defmodule Raxol.Terminal.ANSIFacadeTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSIFacade
  alias Raxol.Terminal.ANSI

  # Create a basic emulator mock struct for testing
  defmodule EmulatorMock do
    defstruct cursor_x: 0,
              cursor_y: 0,
              cursor_saved: nil,
              cursor_visible: true,
              style: %{},
              attributes: %{
                foreground_true: nil,
                background_true: nil,
                foreground_256: nil,
                background_256: nil
              },
              screen_modes: %{},
              active_buffer: []
  end

  test "facade initializes state correctly" do
    state = ANSIFacade.new()
    assert is_map(state)
    assert Map.has_key?(state, :mouse_state)
    assert Map.has_key?(state, :window_state)
    assert Map.has_key?(state, :sixel_state)
  end

  test "original ANSI module delegates to facade" do
    # This test verifies that calling ANSI.new() goes through the facade
    assert ANSI.new() == ANSIFacade.new()
  end

  test "process_escape handles cursor movement" do
    emulator = %EmulatorMock{}

    # Test cursor movements via the facade
    updated = ANSIFacade.process_escape(emulator, "\e[5B")
    assert updated.cursor_y == 5

    # Ensure both direct facade call and delegated call work the same
    assert ANSI.process_escape(emulator, "\e[5B") ==
             ANSIFacade.process_escape(emulator, "\e[5B")
  end

  test "process_escape handles cursor save/restore" do
    emulator = %EmulatorMock{cursor_x: 10, cursor_y: 20}

    # Save cursor position
    saved = ANSIFacade.process_escape(emulator, "\e[S")
    assert saved.cursor_saved == {10, 20}

    # Move cursor
    moved = ANSIFacade.process_escape(saved, "\e[5B")
    assert moved.cursor_y == 25

    # Restore cursor position
    restored = ANSIFacade.process_escape(moved, "\e[T")
    assert restored.cursor_x == 10
    assert restored.cursor_y == 20
  end

  test "deprecation warning is shown" do
    # We can't directly test compiler warnings, but we can verify the attribute
    # Verify module attribute
    assert :deprecated in ANSIFacade.__info__(:attributes)
  end
end
