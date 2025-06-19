
defmodule Raxol.Terminal.DriverTestHelper do
  @moduledoc """
  Helper module for terminal driver tests providing common test utilities and fixtures.
  """

  alias Raxol.Terminal.Driver
  alias Raxol.Core.Events.Event

  def start_driver(test_pid) do
    {:ok, driver_pid} = Driver.start_link(test_pid)
    driver_pid
  end

  def wait_for_driver_ready(driver_pid, timeout \\ 500) do
    receive do
      {:driver_ready, ^driver_pid} ->
        :ok

      {:driver_ready, other_pid} ->
        assert other_pid == driver_pid

      other ->
        flunk(
          "Expected {:driver_ready, \\#{inspect(driver_pid)}}, got: \\#{inspect(other)}"
        )
    after
      timeout ->
        flunk("Timeout waiting for {:driver_ready, \\#{inspect(driver_pid)}}")
    end
  end

  def consume_initial_resize(timeout \\ 500) do
    assert_receive {:"$gen_cast", {:dispatch, %Event{type: :resize}}}, timeout
  end

  def simulate_sigwinch(driver_pid) do
    send(
      driver_pid,
      {:termbox_event, %{type: :resize, width: 90, height: 30}}
    )
  end

  def simulate_key_event(driver_pid, char, key \\ 0, mod \\ 0) do
    send(
      driver_pid,
      {:termbox_event, %{type: :key, key: key, char: char, mod: mod}}
    )
  end

  def simulate_mouse_event(driver_pid, x, y, button) do
    send(
      driver_pid,
      {:termbox_event, %{type: :mouse, x: x, y: y, button: button}}
    )
  end

  def simulate_resize_event(driver_pid, width, height) do
    send(
      driver_pid,
      {:termbox_event, %{type: :resize, width: width, height: height}}
    )
  end

  def assert_key_event(char, key \\ nil, modifiers \\ %{}) do
    modifiers =
      Map.merge(
        %{shift: false, ctrl: false, alt: false, meta: false},
        modifiers
      )

    assert_receive {:"$gen_cast",
                    {:dispatch,
                     %Event{
                       type: :key,
                       data: %{
                         char: ^char,
                         key: ^key,
                         shift: shift,
                         ctrl: ctrl,
                         alt: alt,
                         meta: meta
                       }
                     }}},
                   500

    assert shift == modifiers.shift
    assert ctrl == modifiers.ctrl
    assert alt == modifiers.alt
    assert meta == modifiers.meta
  end

  def assert_mouse_event(x, y, button) do
    assert_receive {:"$gen_cast",
                    {:dispatch,
                     %Event{type: :mouse, data: %{x: x, y: y, button: button}}}},
                   500
  end

  def assert_resize_event(width, height) do
    assert_receive {:"$gen_cast",
                    {:dispatch,
                     %Event{
                       type: :resize,
                       data: %{width: width, height: height}
                     }}},
                   500
  end

  def setup_terminal do
    original_stty =
      case System.cmd("stty", ["-g"]) do
        {output, 0} -> String.trim(output)
        {_error, _exit_code} -> nil
      end

    on_exit(fn ->
      if original_stty do
        System.cmd("stty", [original_stty])
      end
    end)

    %{original_stty: original_stty}
  end
end
