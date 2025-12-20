defmodule Raxol.Terminal.Commands.DeviceHandlerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.{Commands.DeviceHandler, Emulator, OutputManager}

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
      result = unwrap_ok(DeviceHandler.handle_c(emulator, [0], ""))
      assert OutputManager.get_content(result) == "\e[?6c"
    end

    test "responds to secondary DA request", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandler.handle_c(emulator, [0], ">"))
      assert OutputManager.get_content(result) == "\e[>0;0;0c"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandler.handle_c(emulator, [], ""))
      assert OutputManager.get_content(result) == "\e[?6c"
    end
  end

  describe "handle_n/2 (Device Status Report)" do
    test "responds to DSR request (5)", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandler.handle_n(emulator, [5]))
      assert OutputManager.get_content(result) == "\e[0n"
    end

    test "responds to CPR request (6)", %{emulator: emulator} do
      # Set cursor position by updating the cursor struct
      updated_cursor = %{emulator.cursor | position: {5, 5}, row: 5, col: 5}
      updated_emulator = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(DeviceHandler.handle_n(updated_emulator, [6]))
      assert OutputManager.get_content(result) == "\e[6;6R"
    end

    test "handles missing parameter", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandler.handle_n(emulator, []))
      assert OutputManager.get_content(result) == "\e[0n"
    end
  end

  describe "handle_n/2 (Device Status Report) for DSR and CPR" do
    test "reports device status (DSR 5)", %{emulator: emulator} do
      result = unwrap_ok(DeviceHandler.handle_n(emulator, [5]))
      assert OutputManager.get_content(result) == "\e[0n"
    end

    test "reports cursor position (CPR 6)", %{emulator: emulator} do
      # Move cursor to position (5,5) by updating cursor struct
      updated_cursor = %{emulator.cursor | position: {5, 5}, row: 5, col: 5}
      emulator_with_cursor = %{emulator | cursor: updated_cursor}
      result = unwrap_ok(DeviceHandler.handle_n(emulator_with_cursor, [6]))
      assert OutputManager.get_content(result) == "\e[6;6R"
    end
  end
end
