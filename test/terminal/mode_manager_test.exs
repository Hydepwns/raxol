defmodule Raxol.Terminal.ModeManagerTest do
  use ExUnit.Case, async: false
  require Mox
  import Raxol.Test.Support.TestHelper

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ScreenBuffer
  alias MapSet

  setup do
    # Set up test environment and mocks
    {:ok, context} = setup_test_env()
    setup_common_mocks()

    # Configure the application to use the mock for this test
    # This ensures ModeManager uses our TerminalStateMock
    original_impl = Application.get_env(:raxol, :terminal_state_impl)

    Application.put_env(
      :raxol,
      :terminal_state_impl,
      Raxol.Terminal.Parser.StateMock
    )

    on_exit(fn ->
      Application.put_env(:raxol, :terminal_state_impl, original_impl)
    end)

    {:ok, context}
  end

  describe "set_mode/2 with state saving" do
    test 'save_state is called when setting a mode that saves terminal state' do
      # 1. Arrange: Create an initial emulator state
      main_buffer = ScreenBuffer.new(80, 24, 1000)
      # Alternate buffer usually has no scrollback
      alt_buffer = ScreenBuffer.new(80, 24, 0)

      initial_emulator_state = Emulator.new(80, 24)

      initial_emulator_state = %{
        initial_emulator_state
        | state_stack: [],
          cursor: %CursorManager{
            position: {0, 0},
            state: :visible,
            style: :block
          },
          style: TextFormatting.new(),
          mode_manager: ModeManager.new(),
          main_screen_buffer: main_buffer,
          alternate_screen_buffer: alt_buffer,
          active_buffer_type: :main,
          output_buffer: "",
          # Default scroll region
          scroll_region: nil,
          charset_state: Raxol.Terminal.ANSI.CharacterSets.new(),
          tab_stops:
            MapSet.new(Enum.filter(1..80, fn col -> rem(col - 1, 8) == 0 end))
      }

      # 2. Expect: TerminalStateMock.save_state/2 to be called once.
      # It's called as @terminal_state_module.save_state(emulator.terminal_state, emulator)
      # It should return a new stack (list).
      Mox.expect(TerminalStateMock, :save_state, 1, fn current_stack,
                                                       emulator_arg ->
        assert is_list(current_stack)
        assert %Emulator{} = emulator_arg
        # The mock should return a valid new stack
        [%{mock_saved_state_marker: true} | current_stack]
      end)

      # 3. Act: Call ModeManager.set_mode with a mode that triggers save_terminal_state
      # :use_alternate_buffer_clear (DEC private mode 1049) corresponds to :alt_screen_buffer internally.
      # ModeManager.set_mode/2 takes emulator and a list of mode atoms.
      _updated_emulator =
        ModeManager.set_mode(initial_emulator_state, [:alt_screen_buffer])

      # 4. Assert: Manually verify the mock expectation since verify_on_exit! was removed.
      Mox.verify!(TerminalStateMock)
    end
  end
end
