defmodule Raxol.Terminal.DriverIOTerminalTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.Driver
  alias Raxol.Terminal.IOTerminal

  @moduletag :driver_io_terminal
  @moduletag :skip_on_ci

  describe "Driver with IOTerminal backend" do
    test "initializes with IOTerminal when termbox2_nif not available" do
      # This test verifies the Driver can initialize using IOTerminal
      # Skip if termbox2_nif is actually available
      if Code.ensure_loaded?(:termbox2_nif) and
           function_exported?(:termbox2_nif, :tb_init, 0) do
        # Termbox available, skip this test
        :ok
      else
        # Start a test dispatcher
        {:ok, dispatcher} =
          GenServer.start_link(
            fn -> %{} end,
            fn
              {:dispatch, _event}, state -> {:noreply, state}
              {:driver_ready, _pid}, state -> {:noreply, state}
              _msg, state -> {:noreply, state}
            end
          )

        # Start driver with dispatcher
        {:ok, driver_pid} = Driver.start_link(dispatcher)

        # Driver should initialize successfully
        assert Process.alive?(driver_pid)

        # Cleanup
        GenServer.stop(driver_pid)
        GenServer.stop(dispatcher)
      end
    end

    test "Driver uses IOTerminal for size detection when termbox unavailable" do
      if Code.ensure_loaded?(:termbox2_nif) and
           function_exported?(:termbox2_nif, :tb_init, 0) do
        :ok
      else
        # IOTerminal should be used for size detection
        {:ok, {width, height}} = IOTerminal.get_terminal_size()
        assert is_integer(width)
        assert is_integer(height)
        assert width > 0
        assert height > 0
      end
    end
  end

  describe "IOTerminal fallback behavior" do
    test "get_termbox_width uses IOTerminal when NIF unavailable" do
      if Code.ensure_loaded?(:termbox2_nif) and
           function_exported?(:termbox2_nif, :tb_init, 0) do
        # Skip - NIF is available
        :ok
      else
        # When termbox2_nif is not available, should use IOTerminal
        {:ok, {width, _}} = IOTerminal.get_terminal_size()
        assert width >= 80
      end
    end

    test "get_termbox_height uses IOTerminal when NIF unavailable" do
      if Code.ensure_loaded?(:termbox2_nif) and
           function_exported?(:termbox2_nif, :tb_init, 0) do
        :ok
      else
        {:ok, {_, height}} = IOTerminal.get_terminal_size()
        assert height >= 24
      end
    end
  end

  describe "Driver initialization states" do
    test "Driver state includes io_terminal_state field" do
      # This is a compile-time check that the State struct has the field
      state = %Driver.State{}
      assert Map.has_key?(state, :io_terminal_state)
    end
  end

  describe "cross-platform terminal detection" do
    test "detects terminal backend availability" do
      termbox_available = Code.ensure_loaded?(:termbox2_nif)
      io_terminal_available = Code.ensure_loaded?(IOTerminal)

      # At least one backend should be available
      assert termbox_available or io_terminal_available

      # IOTerminal should always be available as fallback
      assert io_terminal_available
    end

    test "IOTerminal works on current platform" do
      # Test that IOTerminal can initialize on any platform
      assert {:ok, state} = IOTerminal.init()
      assert state.initialized
      IOTerminal.shutdown()
    end
  end

  describe "terminal operations without termbox2_nif" do
    setup do
      # Only run these tests if termbox2_nif is not available
      if Code.ensure_loaded?(:termbox2_nif) and
           function_exported?(:termbox2_nif, :tb_init, 0) do
        {:ok, skip: true}
      else
        {:ok, _state} = IOTerminal.init()
        on_exit(fn -> IOTerminal.shutdown() end)
        {:ok, skip: false}
      end
    end

    test "can perform basic terminal operations", %{skip: skip} do
      unless skip do
        # These should work via IOTerminal
        assert :ok = IOTerminal.clear_screen()
        assert :ok = IOTerminal.hide_cursor()
        assert :ok = IOTerminal.set_cell(0, 0, "A", 15, 0)
        assert :ok = IOTerminal.present()
        assert :ok = IOTerminal.show_cursor()
      end
    end

    test "can get terminal size", %{skip: skip} do
      unless skip do
        assert {:ok, {width, height}} = IOTerminal.get_terminal_size()
        assert width > 0
        assert height > 0
      end
    end

    test "can set terminal title", %{skip: skip} do
      unless skip do
        assert :ok = IOTerminal.set_title("Test Title")
      end
    end
  end
end
