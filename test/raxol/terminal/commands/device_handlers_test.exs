defmodule Raxol.Terminal.Commands.DeviceHandlersTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.{Commands.DeviceHandlers, Emulator, OutputManager}
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  setup do
    # Create a test emulator with a 10x10 screen using the proper constructor
    emulator = Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  describe "handle_c/2 (Device Attributes)" do
    test "responds to primary DA request", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_c(emulator, [0], ""))
      assert OutputManager.get_content(result) == "\e[?1;2c"
    end

    test "responds to secondary DA request", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_c(emulator, [0], ">"))
      assert OutputManager.get_content(result) == "\e[>0;1;0c"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_c(emulator, [], ""))
      assert OutputManager.get_content(result) == "\e[?1;2c"
    end
  end

  describe "handle_n/2 (Device Status Report)" do
    test "responds to DSR request (5)", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_n(emulator, [5]))
      assert OutputManager.get_content(result) == "\e[0n"
    end

    test "responds to CPR request (6)", %{emulator: emulator} do
      # Set cursor position using the cursor manager
      CursorManager.set_position(emulator.cursor, {5, 5})
      result = unwrap_ok(DeviceHandlers.handle_n(emulator, [6]))
      assert OutputManager.get_content(result) == "\e[6;6R"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_n(emulator, []))
      assert OutputManager.get_content(result) == "\e[0n"
    end
  end

  describe "handle_n/2 (Device Status Report) for DSR and CPR" do
    test "reports device status (DSR 5)", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandlers.handle_n(emulator, [5]))
      assert OutputManager.get_content(result) == "\e[0n"
    end

    test "reports cursor position (CPR 6)", %{emulator: emulator} do
      # Move cursor to position (5,5) using the cursor manager
      CursorManager.set_position(emulator.cursor, {5, 5})
      result = unwrap_ok(DeviceHandlers.handle_n(emulator, [6]))
      assert OutputManager.get_content(result) == "\e[6;6R"
    end
  end
end
