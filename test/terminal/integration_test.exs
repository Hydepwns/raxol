defmodule Raxol.Terminal.IntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager

  # Helper to extract text from a ScreenBuffer
  defp buffer_text(buffer) do
    buffer.cells
    |> Enum.map(fn line ->
      Enum.map_join(line, &(&1.char || " "))
    end)
    |> Enum.join("\n")
    |> String.trim_trailing()
  end

  describe "input to screen buffer integration" do
    setup do
      emulator_instance = Emulator.new(80, 24)
      %{state: emulator_instance}
    end

    test "processes keyboard input and updates screen buffer", %{
      state: initial_state
    } do
      # Initial state and dimensions
      # emulator = Emulator.new(80, 24) # This line is removed
      # Write "Hello"
      {state, _output} = Emulator.process_input(initial_state, "Hello")

      # Check only the beginning of the first line
      first_line_text =
        state.main_screen_buffer
        |> ScreenBuffer.get_line(0)
        |> Enum.map_join(&(&1.char || " "))

      assert String.starts_with?(first_line_text, "Hello")
    end

    test "handles cursor movement with arrow keys", %{state: initial_state} do
      # state = Emulator.new(80, 24) # Use state from setup

      {state, _output} = Emulator.process_input(initial_state, "Hello")
      {state, _output} = Emulator.process_input(state, "\e[D")
      {state, _output} = Emulator.process_input(state, "\e[D")
      {state, _output} = Emulator.process_input(state, "\e[D")

      assert state.cursor.position == {2, 0}
    end

    test "handles line wrapping" do
      state = Emulator.new(5, 3)

      {state, _output} = Emulator.process_input(state, "HelloWorld")

      assert buffer_text(state.main_screen_buffer) == "Hello\nWorld"
    end

    test "handles screen scrolling" do
      state = Emulator.new(5, 3)

      # Input 4 lines (no final newline), should force one line into scrollback
      {state, _output} =
        Emulator.process_input(state, "Line1\nLine2\nLine3\nLine4")

      # Expect 2 lines in scrollback after inputting 4 lines into a 3-line buffer
      assert length(state.main_screen_buffer.scrollback) == 2
      assert buffer_text(state.main_screen_buffer) == "Line2\nLine3\nLine4"
    end
  end

  describe "input to ANSI integration" do
    setup do
      initial_emulator_state = Emulator.new(80, 24)
      %{state: initial_emulator_state}
    end

    test "processes ANSI escape sequences", %{state: initial_state} do
      # This test creates its own state
      # state = Emulator.new(80, 24) # Use state from setup

      {state, _output} =
        Emulator.process_input(initial_state, "\e[31mHello\e[0m")

      first_cell =
        state.main_screen_buffer.cells |> List.first() |> List.first()

      assert first_cell.style.foreground == :red
    end

    test "handles multiple ANSI attributes", %{state: initial_state} do
      # Test enabling multiple attributes: bold, red foreground, underline
      {state, _output_attrs_on} =
        Emulator.process_input(
          initial_state,
          "\e[1;31;4mRed Underlined Bold\e[0m"
        )

      first_cell =
        state.main_screen_buffer.cells |> List.first() |> List.first()

      assert first_cell.style.bold == true
      assert first_cell.style.underline == true
      assert first_cell.style.foreground == :red
    end

    test "handles cursor positioning", %{state: initial_state} do
      # state = Emulator.new(80, 24) # Use state from setup

      {state, _output} = Emulator.process_input(initial_state, "\e[10;5H")

      assert state.cursor.position == {4, 9}
    end

    test "handles screen clearing", %{state: initial_state} do
      # state = Emulator.new(80, 24) # Use state from setup

      {state, _output} = Emulator.process_input(initial_state, "Hello")

      {state, _output} = Emulator.process_input(state, "\e[2J")

      # Check if the buffer content is effectively empty (only whitespace)
      assert String.trim(buffer_text(state.main_screen_buffer)) == ""
    end
  end

  describe "mouse input integration" do
    setup do
      initial_emulator_state = Emulator.new(80, 24)
      %{state: initial_emulator_state}
    end

    test "handles mouse clicks", %{state: initial_state} do
      # state = Emulator.new(80, 24) # Use state from setup

      # Enable X10 mouse reporting (any button, any event)
      {state, _output_mouse_enable} =
        Emulator.process_input(initial_state, "\e[?1000h")

      assert state.mode_manager.mouse_report_mode == :x10

      # Simulate a left mouse button press at (1,1)
      # Cb = 0 (left press) + 32 = 32 (space)
      # Cx = 1 (col) + 32 = 33 (!)
      # Cy = 1 (row) + 32 = 33 (!)
      # ESC [ M <space> ! !
      mouse_click_sequence = "\e[M !!"

      {_state, output_mouse_click} =
        Emulator.process_input(state, mouse_click_sequence)

      # The emulator should output the same sequence when mouse reporting is on
      assert output_mouse_click == mouse_click_sequence
    end

    test "handles mouse selection", %{state: initial_state} do
      # state = Emulator.new(80, 24) # Use state from setup

      # Enable X11 mouse reporting (button-event tracking)
      {state, _output_mouse_enable} =
        Emulator.process_input(initial_state, "\e[?1002h")

      assert state.mode_manager.mouse_report_mode == :cell_motion

      # 1. Press Left Button at (col 0, row 0)
      # Cb = 0 (LMB) + 32 = 32 (' ')
      # Cx = 0 + 1 + 32 = 33 ('!')
      # Cy = 0 + 1 + 32 = 33 ('!')
      press_sequence = "\e[M !!"
      {state, output_press} = Emulator.process_input(state, press_sequence)
      assert output_press == press_sequence

      # 2. Drag Left Button to (col 2, row 1)
      # Cb = 0 (LMB) + 32 (motion) + 32 = 64 ('@')
      # Cx = 2 + 1 + 32 = 35 ('#')
      # Cy = 1 + 1 + 32 = 34 ('"')
      drag_sequence = "\e[M@#\""
      {state, output_drag} = Emulator.process_input(state, drag_sequence)
      assert output_drag == drag_sequence

      # 3. Release Left Button at (col 2, row 1)
      # Cb = 3 (X10 release) + 32 = 35 ('#')
      # Cx = 2 + 1 + 32 = 35 ('#')
      # Cy = 1 + 1 + 32 = 34 ('"')
      release_sequence = "\e[M##\""
      {_state, output_release} = Emulator.process_input(state, release_sequence)
      assert output_release == release_sequence
    end
  end

  describe "input history integration" do
    setup do
      # Initialize with a small history size for testing
      emulator_instance = Emulator.new(80, 24, max_command_history: 3)
      %{state: emulator_instance}
    end

    test "maintains command history", %{state: initial_state} do
      # Process some commands
      {state_after_cmd1, _} =
        Emulator.process_input(initial_state, "command1\n")

      assert state_after_cmd1.command_history == ["command1"]

      # Process an empty command (should be ignored)
      {state_after_empty, _} = Emulator.process_input(state_after_cmd1, "\n")
      assert state_after_empty.command_history == ["command1"]

      # Add more commands
      {state_after_cmd2, _} =
        Emulator.process_input(state_after_empty, "command2\n")

      assert state_after_cmd2.command_history == ["command1", "command2"]

      {state_after_cmd3, _} =
        Emulator.process_input(state_after_cmd2, "command3\n")

      assert state_after_cmd3.command_history == [
               "command1",
               "command2",
               "command3"
             ]

      # Add another command, should push out the oldest ("command1")
      {state_after_cmd4, _} =
        Emulator.process_input(state_after_cmd3, "command4\n")

      assert state_after_cmd4.command_history == [
               "command2",
               "command3",
               "command4"
             ]

      # Add a command with no trailing newline (should not be added to history yet)
      {state_no_newline, _} =
        Emulator.process_input(state_after_cmd4, "pending")

      assert state_no_newline.command_history == [
               "command2",
               "command3",
               "command4"
             ]

      # Add the newline, now "pending" should be added, pushing out "command2"
      {state_after_pending, _} = Emulator.process_input(state_no_newline, "\n")

      assert state_after_pending.command_history == [
               "command3",
               "command4",
               "pending"
             ]
    end
  end

  describe "mode switching integration" do
    setup do
      initial_emulator_state = Emulator.new(80, 24)
      %{state: initial_emulator_state}
    end

    test "handles mode transitions", %{state: initial_state} do
      # Test DECOM (Origin Mode)
      # Set Origin Mode (CSI ?6h)
      {state_after_set, _output_set} =
        Emulator.process_input(initial_state, "\e[?6h")

      assert ModeManager.mode_enabled?(state_after_set.mode_manager, :decom) ==
               true

      # Reset Origin Mode (CSI ?6l)
      {state_after_reset, _output_reset} =
        Emulator.process_input(state_after_set, "\e[?6l")

      # assert state_after_reset.mode_manager.origin_mode == false
      assert ModeManager.mode_enabled?(state_after_reset.mode_manager, :decom) ==
               false

      # Test SGR mouse reporting (mode 1006)
      # Enable SGR Mouse Mode (CSI ?1006h)
      # ... (assertions for SGR mouse mode)
    end
  end

  describe "bracketed paste integration" do
    setup do
      initial_emulator_state = Emulator.new(80, 24)
      %{state: initial_emulator_state}
    end

    test "handles bracketed paste", %{state: initial_state} do
      # Enable bracketed paste mode
      {state, _output_enable} =
        Emulator.process_input(initial_state, "\e[?2004h")

      # Assert mode is enabled
      assert state.mode_manager.bracketed_paste_mode

      paste_text = "multi\nline\npaste"
      # When bracketed paste mode is on, the Emulator should wrap the raw text
      {_final_state, output_paste} = Emulator.process_input(state, paste_text)
      expected_output = "\e[200~multi\nline\npaste\e[201~"

      # IO.inspect({output_paste, expected_output}, label: "[IntegrationTest] PASTE ASSERTION CHECK") # DEBUG
      assert inspect(output_paste) == inspect(expected_output)
    end
  end

  describe "modifier key integration" do
    # Skipped: Feature not fully implemented. Requires design for modifier key sequence parsing (e.g., CSI u or XTerm-style) and how Emulator surfaces these events.
    @tag :skip
    test "handles modifier keys" do
      # TODO: Implement test once modifier key handling in Emulator is designed/implemented.
      # Example considerations:
      # 1. Define expected input sequence (e.g., CSI value;modifier u, or other common terminal extension).
      # 2. Define how Emulator makes this parsed key + modifier available (e.g., internal event, output sequence for driver).
      # 3. Write assertions based on that.
      # Placeholder until implemented
      assert true
    end
  end

  describe "sixel graphics integration" do
    # Skipped: Feature not fully implemented. Emulator's DCS handler needs to integrate with SixelGraphics.process_sequence and then render the parsed sixel data to the screen buffer.
    @tag :skip
    test "handles sixel graphics", %{state: initial_state} do
      # TODO: Implement test once SIXEL handling in Emulator is complete.
      # Steps:
      # 1. Ensure Emulator's DCS handler calls SixelGraphics.process_sequence.
      # 2. Ensure Emulator has a mechanism to render the SixelGraphics.pixel_buffer to its ScreenBuffer.
      # 3. Send a simple SIXEL sequence via Emulator.process_input.
      #    Example (1x1 black pixel): "\eP0;0;1q#0;2;0;0;0#0?\e\\" (DCS params q #color_def #sixel_data ST)
      # 4. Assert the expected cell(s) in initial_state.main_screen_buffer are modified (e.g., background color).

      # Minimal: define color 0 as black, draw 1 pixel with it.
      sixel_sequence = "\ePq#0;2;0;0;0#0?\e\\"

      # {final_state, _output} = Emulator.process_input(initial_state, sixel_sequence)

      # Example assertion (depends on how sixels are rendered to cells):
      # first_cell = ScreenBuffer.get_cell_at(final_state.main_screen_buffer, 0, 0)
      # assert first_cell.style.background == {0,0,0} # or whatever the black representation is
      # Placeholder until implemented
      assert true
    end
  end
end
