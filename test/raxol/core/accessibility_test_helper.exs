defmodule Raxol.Core.AccessibilityTestHelper do
  @moduledoc """
  Helper module for accessibility tests providing common test utilities and fixtures.
  """

  alias Raxol.Core.UserPreferences
  import ExUnit.Assertions
  import ExUnit.Callbacks

  def wait_for_state(condition, timeout \\ 100) do
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + timeout

    wait_for_condition(condition, end_time)
  end

  defp wait_for_condition(condition, end_time) do
    if System.monotonic_time(:millisecond) > end_time do
      flunk("Condition not met within timeout")
    end

    if condition.() do
      :ok
    else
      Process.sleep(10)
      wait_for_condition(condition, end_time)
    end
  end

  def pref_key(key), do: [:accessibility, key]

  def setup_test_preferences(prefs_name) do
    # Ensure EventManager is started
    Raxol.Core.Events.Manager.init()

    {:ok, _pid} =
      GenServer.start_link(UserPreferences, [test_mode?: true],
        name: prefs_name
      )

    Raxol.Core.UserPreferences.set(pref_key(:enabled), true, prefs_name)
    Raxol.Core.UserPreferences.set(pref_key(:screen_reader), true, prefs_name)
    Raxol.Core.UserPreferences.set(pref_key(:high_contrast), false, prefs_name)
    Raxol.Core.UserPreferences.set(pref_key(:reduced_motion), false, prefs_name)
    Raxol.Core.UserPreferences.set(pref_key(:keyboard_focus), true, prefs_name)
    Raxol.Core.UserPreferences.set(pref_key(:large_text), false, prefs_name)

    Raxol.Core.UserPreferences.set(
      pref_key(:silence_announcements),
      false,
      prefs_name
    )

    on_exit(fn ->
      if pid = Process.whereis(prefs_name), do: GenServer.stop(pid)
      Raxol.Core.Events.Manager.cleanup()
    end)

    {:ok, prefs_name: prefs_name}
  end

  def setup_test_preferences_with_events(prefs_name) do
    # Ensure EventManager is started
    Raxol.Core.Events.Manager.init()

    {:ok, pid_of_prefs} =
      GenServer.start_link(UserPreferences, [test_mode?: true],
        name: prefs_name
      )

    # Set up preferences
    Raxol.Core.UserPreferences.set(pref_key(:screen_reader), true, prefs_name)
    Raxol.Core.Accessibility.enable([], prefs_name)
    Raxol.Core.Accessibility.clear_announcements()

    on_exit(fn ->
      Raxol.Core.Accessibility.disable(prefs_name)
      if Process.alive?(pid_of_prefs), do: GenServer.stop(pid_of_prefs)
      Raxol.Core.Events.Manager.cleanup()
    end)

    {:ok, prefs_name: prefs_name, pref_pid: pid_of_prefs}
  end

  def register_test_elements do
    # Register test elements
    Raxol.Core.Accessibility.register_element_metadata("search_button", %{
      label: "Search"
    })

    Raxol.Core.Accessibility.register_element_metadata("text_input", %{
      label: "Username"
    })

    Raxol.Core.Accessibility.register_element_metadata("submit_button", %{
      label: "Submit Form"
    })

    # Return a cleanup function
    fn ->
      Raxol.Core.Accessibility.unregister_element_metadata("search_button")
      Raxol.Core.Accessibility.unregister_element_metadata("text_input")
      Raxol.Core.Accessibility.unregister_element_metadata("submit_button")
    end
  end

  def clear_test_state(prefs_name) do
    Raxol.Core.Accessibility.clear_announcements()
    Raxol.Core.Accessibility.disable(prefs_name)
    Raxol.Core.Events.Manager.cleanup()
  end
end
