defmodule Raxol.Terminal.Commands.DeviceHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.DeviceHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting

  setup do
    # Create a test emulator with a 10x10 screen
    emulator = %Emulator{
      main_screen_buffer: ScreenBuffer.new(10, 10),
      cursor: CursorManager.new(),
      style: TextFormatting.new()
    }
    {:ok, emulator: emulator}
  end

  describe "handle_c/2 (Device Attributes)" do
    test "responds to primary DA request", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_c(emulator, [0])

      # Verify response format
      assert_receive {:io_write, "\e[?1;2c"}, 1000
      :meck.unload(IO)
    end

    test "responds to secondary DA request", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_c(emulator, [0])

      # Verify response format
      assert_receive {:io_write, "\e[>0;1;0c"}, 1000
      :meck.unload(IO)
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_c(emulator, [])

      # Should default to primary DA request
      assert_receive {:io_write, "\e[?1;2c"}, 1000
      :meck.unload(IO)
    end
  end

  describe "handle_n/2 (Device Status Report)" do
    test "responds to DSR request (5)", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:dsr_response, data}) end)

      result = DeviceHandlers.handle_n(emulator, [5])

      # Verify the response matches the expected format
      assert_receive {:dsr_response, "\e[0n"}
      # Verify emulator state is unchanged
      assert result == emulator
      :meck.unload(IO)
    end

    test "responds to CPR request (6)", %{emulator: emulator} do
      # Set cursor position
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:dsr_response, data}) end)

      result = DeviceHandlers.handle_n(emulator, [6])

      # Verify the response matches the expected format (1-based coordinates)
      assert_receive {:dsr_response, "\e[6;6R"}
      # Verify emulator state is unchanged
      assert result == emulator
      :meck.unload(IO)
    end

    test "handles missing parameter", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:dsr_response, data}) end)

      result = DeviceHandlers.handle_n(emulator, [])

      # Verify default behavior (DSR request)
      assert_receive {:dsr_response, "\e[0n"}
      # Verify emulator state is unchanged
      assert result == emulator
      :meck.unload(IO)
    end
  end

  describe "handle_Z/2 (Cursor Position Report)" do
    test "reports cursor position", %{emulator: emulator} do
      # Move cursor to position (5,5)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_Z(emulator, [])

      # Verify response format (1-based coordinates)
      assert_receive {:io_write, "\e[6;6R"}, 1000
      :meck.unload(IO)
    end

    test "handles cursor at origin", %{emulator: emulator} do
      # Move cursor to position (0,0)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 0}}}

      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_Z(emulator, [])

      # Verify response format (1-based coordinates)
      assert_receive {:io_write, "\e[1;1R"}, 1000
      :meck.unload(IO)
    end
  end

  describe "handle_6n/2 (Cursor Position Report)" do
    test "reports cursor position", %{emulator: emulator} do
      # Move cursor to position (5,5)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {5, 5}}}

      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_6n(emulator, [])

      # Verify response format (1-based coordinates)
      assert_receive {:io_write, "\e[6;6R"}, 1000
      :meck.unload(IO)
    end

    test "handles cursor at origin", %{emulator: emulator} do
      # Move cursor to position (0,0)
      emulator = %{emulator | cursor: %{emulator.cursor | position: {0, 0}}}

      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_6n(emulator, [])

      # Verify response format (1-based coordinates)
      assert_receive {:io_write, "\e[1;1R"}, 1000
      :meck.unload(IO)
    end
  end

  describe "handle_5n/2 (Device Status Report)" do
    test "reports device status", %{emulator: emulator} do
      # Mock IO.write to capture response
      me = self()
      :meck.new(IO, [:passthrough])
      :meck.expect(IO, :write, fn data -> send(me, {:io_write, data}) end)

      DeviceHandlers.handle_5n(emulator, [])

      # Verify response format
      assert_receive {:io_write, "\e[0n"}, 1000
      :meck.unload(IO)
    end
  end
end
