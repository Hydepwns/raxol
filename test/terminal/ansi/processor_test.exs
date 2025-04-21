defmodule Raxol.Terminal.ANSI.ProcessorTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.Processor
  alias Raxol.Terminal.Buffer.Manager

  setup do
    # Only start required applications
    # {:ok, _} = Application.ensure_all_started(:stdlib) # Removed redundant
    {:ok, _} = Application.ensure_all_started(:logger)
    # {:ok, _} = Application.ensure_all_started(:gen_statem) # Removed redundant

    # Initialize processor and buffer manager with test dimensions
    {:ok, processor} = Processor.start_link([])
    {:ok, buffer_manager} = Manager.new(80, 24, 1000, 10_000_000)

    # Set up the buffer manager in the processor
    :ok = Processor.set_buffer_manager(processor, buffer_manager)

    # Return the test context
    %{processor: processor, buffer_manager: buffer_manager}
  end

  describe "parse_sequence/1" do
    test "parses CSI sequences", %{processor: processor} do
      # This is a private function, so we need to use :erlang.apply/3
      result = :erlang.apply(Processor, :parse_sequence, ["\e[31m"])

      assert result.type == :csi
      assert result.command == "m"
      assert result.params == ["31"]
    end

    test "parses OSC sequences", %{processor: processor} do
      result = :erlang.apply(Processor, :parse_sequence, ["\e]0;title\a"])

      assert result.type == :osc
      assert result.text == "0;title"
    end

    test "parses ESC sequences", %{processor: processor} do
      result = :erlang.apply(Processor, :parse_sequence, ["\eM"])

      assert result.type == :esc
      assert result.command == "M"
    end

    test "parses plain text", %{processor: processor} do
      result = :erlang.apply(Processor, :parse_sequence, ["Hello, world!"])

      assert result.type == :text
      assert result.text == "Hello, world!"
    end
  end

  describe "process_sequence/1" do
    test "processes cursor up sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 10)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process cursor up sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[5A")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check cursor position
      {x, y} = Manager.get_cursor_position(new_buffer_manager)
      assert x == 10
      # 10 - 5 = 5
      assert y == 5
    end

    test "processes cursor down sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process cursor down sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[5B")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check cursor position
      {x, y} = Manager.get_cursor_position(new_buffer_manager)
      assert x == 10
      # 5 + 5 = 10
      assert y == 10
    end

    test "processes cursor forward sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 5, 10)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process cursor forward sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[5C")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check cursor position
      {x, y} = Manager.get_cursor_position(new_buffer_manager)
      # 5 + 5 = 10
      assert x == 10
      assert y == 10
    end

    test "processes cursor backward sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 10)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process cursor backward sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[5D")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check cursor position
      {x, y} = Manager.get_cursor_position(new_buffer_manager)
      # 10 - 5 = 5
      assert x == 5
      assert y == 10
    end

    test "processes cursor position sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 0, 0)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process cursor position sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[10;20H")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check cursor position (1-based to 0-based conversion)
      {x, y} = Manager.get_cursor_position(new_buffer_manager)
      # 20 - 1 = 19
      assert x == 19
      # 10 - 1 = 9
      assert y == 9
    end

    test "processes erase display sequence (from cursor to end)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase display sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[0J")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {10, 5, 79, 23}
    end

    test "processes erase display sequence (from beginning to cursor)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase display sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[1J")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 10, 5}
    end

    test "processes erase display sequence (entire display)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase display sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[2J")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}
    end

    test "processes erase line sequence (from cursor to end)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase line sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[0K")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {10, 5, 79, 5}
    end

    test "processes erase line sequence (from beginning to cursor)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase line sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[1K")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 5, 10, 5}
    end

    test "processes erase line sequence (entire line)", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process erase line sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[2K")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 5, 79, 5}
    end

    test "processes text attributes sequence", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 0, 0)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process text attributes sequence
      {:ok, _} = Processor.process_sequence(processor, "\e[1;4;31m")

      # Get the terminal state
      terminal_state = GenServer.call(processor, :get_terminal_state)

      # Check attributes
      assert terminal_state.attributes.bold == true
      assert terminal_state.attributes.underline == true
      # 31 - 30 = 1
      assert terminal_state.attributes.foreground == 1
    end
  end

  describe "terminal modes" do
    test "handles cursor visibility", %{processor: processor} do
      # Hide cursor
      {:ok, state} = Processor.process_sequence(processor, "\e[?25l")
      assert state.terminal_state.modes.cursor_visible == false

      # Show cursor
      {:ok, state} = Processor.process_sequence(processor, "\e[?25h")
      assert state.terminal_state.modes.cursor_visible == true
    end

    test "handles bracketed paste mode", %{processor: processor} do
      # Enable bracketed paste
      {:ok, state} = Processor.process_sequence(processor, "\e[?2004h")
      assert state.terminal_state.modes.bracketed_paste == true

      # Disable bracketed paste
      {:ok, state} = Processor.process_sequence(processor, "\e[?2004l")
      assert state.terminal_state.modes.bracketed_paste == false
    end

    test "handles focus reporting mode", %{processor: processor} do
      # Enable focus reporting
      {:ok, state} = Processor.process_sequence(processor, "\e[?1004h")
      assert state.terminal_state.modes.focus_reporting == true

      # Disable focus reporting
      {:ok, state} = Processor.process_sequence(processor, "\e[?1004l")
      assert state.terminal_state.modes.focus_reporting == false
    end
  end

  describe "display erasure" do
    test "handles clear entire display with scrollback", %{
      processor: processor,
      buffer_manager: buffer_manager
    } do
      # Set initial cursor position
      buffer_manager = Manager.set_cursor_position(buffer_manager, 10, 5)
      :ok = Processor.set_buffer_manager(processor, buffer_manager)

      # Process clear display sequence with scrollback
      {:ok, _} = Processor.process_sequence(processor, "\e[3J")

      # Get the new buffer manager
      new_buffer_manager = Processor.get_buffer_manager(processor)

      # Check damage regions
      damage_regions = Manager.get_damage_regions(new_buffer_manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}

      # Check scrollback buffer is cleared
      assert new_buffer_manager.scrollback_buffer == []
    end
  end

  # Helper functions

  defp get_buffer_manager(processor) do
    GenServer.call(processor, :get_buffer_manager)
  end

  defp get_terminal_state(processor) do
    GenServer.call(processor, :get_terminal_state)
  end
end
