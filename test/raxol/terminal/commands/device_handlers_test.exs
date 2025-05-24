defmodule Raxol.Terminal.Commands.DeviceHandlersTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Commands.DeviceHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen
    emulator = %Emulator{
      main_screen_buffer: ScreenBuffer.new(10, 10),
      alternate_screen_buffer: ScreenBuffer.new(10, 10),
      cursor: CursorManager.new(),
      style: TextFormatting.new()
    }

    {:ok, emulator: emulator}
  end

  describe "handle_c/2 (Device Attributes)" do
    test "responds to primary DA request", %{emulator: emulator} do
      result = DeviceHandlers.handle_c(emulator, [0], "")
      assert result.output_buffer == "\e[?1;2c"
    end

    test "responds to secondary DA request", %{emulator: emulator} do
      result = DeviceHandlers.handle_c(emulator, [0], ">")
      assert result.output_buffer == "\e[>0;1;0c"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = DeviceHandlers.handle_c(emulator, [], "")
      assert result.output_buffer == "\e[?1;2c"
    end
  end

  describe "handle_n/2 (Device Status Report)" do
    test "responds to DSR request (5)", %{emulator: emulator} do
      result = DeviceHandlers.handle_n(emulator, [5])
      assert result.output_buffer == "\e[0n"
    end

    test "responds to CPR request (6)", %{emulator: emulator} do
      # Set cursor position
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = DeviceHandlers.handle_n(emulator, [6])
      assert result.output_buffer == "\e[6;6R"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = DeviceHandlers.handle_n(emulator, [])
      assert result.output_buffer == "\e[0n"
    end
  end

  describe "handle_n/2 (Device Status Report) for DSR and CPR" do
    test "reports device status (DSR 5)", %{emulator: emulator} do
      result = DeviceHandlers.handle_n(emulator, [5])
      assert result.output_buffer == "\e[0n"
    end

    test "reports cursor position (CPR 6)", %{emulator: emulator} do
      # Move cursor to position (5,5)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      result = DeviceHandlers.handle_n(emulator, [6])
      assert result.output_buffer == "\e[6;6R"
    end
  end
end
