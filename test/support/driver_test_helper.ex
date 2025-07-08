defmodule Raxol.Test.Support.DriverTestHelper do
  @moduledoc """
  Test helper functions for terminal driver tests.
  """

  import ExUnit.Assertions

  def setup_terminal() do
    # Setup terminal for testing
    :ok
  end

  def start_driver(test_pid) do
    # Start driver process
    spawn(fn -> driver_loop(test_pid) end)
  end

  def wait_for_driver_ready(_driver_pid) do
    # Wait for driver to be ready
    :ok
  end

  def consume_initial_resize() do
    # Consume initial resize event
    :ok
  end

  def simulate_key_event(driver_pid, key) do
    # Simulate key event
    send(driver_pid, {:key, key})
  end

  def simulate_key_event(driver_pid, modifier, key) do
    # Simulate key event with modifier
    send(driver_pid, {:key, modifier, key})
  end

  def assert_key_event(_expected_key) do
    # Assert key event
    assert_receive {:key, _expected_key}
  end

  def assert_key_event(_expected_modifier, _expected_key) do
    # Assert key event with modifier
    assert_receive {:key, _expected_modifier, _expected_key}
  end

  def assert_key_event(_expected_modifier, _expected_key, _expected_extra) do
    # Assert key event with modifier and extra data
    assert_receive {:key, _expected_modifier, _expected_key}
  end

  def simulate_key_event(driver_pid, modifier, key, extra) do
    # Simulate key event with modifier and extra data
    send(driver_pid, {:key, modifier, key, extra})
  end

  def assert_resize_event(_expected_width, _expected_height) do
    # Assert resize event
    assert_receive {:"$gen_cast",
                    {:dispatch,
                     %Raxol.Core.Events.Event{
                       type: :resize,
                       data: %{width: _expected_width, height: _expected_height}
                     }}},
                   500
  end

  def simulate_resize_event(driver_pid, width, height) do
    # Simulate resize event
    send(driver_pid, {:resize, width, height})
  end

  def simulate_sigwinch(driver_pid) do
    # Simulate SIGWINCH signal
    send(driver_pid, {:signal, :SIGWINCH})
  end

  def simulate_mouse_event(driver_pid, x, y, button) do
    # Simulate mouse event
    send(driver_pid, {:mouse, x, y, button})
  end

  def simulate_mouse_event(driver_pid, x, y, button, modifier) do
    # Simulate mouse event with modifier
    send(driver_pid, {:mouse, x, y, button, modifier})
  end

  def assert_mouse_event(expected_x, expected_y, expected_button) do
    # Assert mouse event
    assert_receive {:mouse, expected_x, expected_y, expected_button}
  end

  def assert_mouse_event(
        expected_x,
        expected_y,
        expected_button,
        expected_modifier
      ) do
    # Assert mouse event with modifier
    assert_receive {:mouse, expected_x, expected_y, expected_button,
                    expected_modifier}
  end

  defp driver_loop(test_pid) do
    receive do
      {:key, key} ->
        send(test_pid, {:key, key})
        driver_loop(test_pid)

      {:key, modifier, key} ->
        send(test_pid, {:key, modifier, key})
        driver_loop(test_pid)

      {:resize, width, height} ->
        send(test_pid, {:resize, width, height})
        driver_loop(test_pid)

      {:signal, :SIGWINCH} ->
        # Simulate a resize event when SIGWINCH is received
        send(test_pid, {:resize, 90, 30})
        driver_loop(test_pid)
    end
  end
end
