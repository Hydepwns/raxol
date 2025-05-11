defmodule Raxol.Core.AccessibilityTestHelper do
  @moduledoc """
  Helper module for accessibility tests providing common test utilities and fixtures.
  """

  alias Raxol.Core.UserPreferences

  def wait_for_state(condition, timeout \\ 100) do
    ref = make_ref()
    send(self(), {:state_check, ref, condition})
    assert_receive {:state_check, ^ref, true}, timeout
  end

  def pref_key(key), do: [:accessibility, key]

  def setup_test_preferences(prefs_name) do
    {:ok, _pid} =
      GenServer.start_link(UserPreferences, [test_mode?: true],
        name: prefs_name
      )

    UserPreferences.set(pref_key(:enabled), true, prefs_name)
    UserPreferences.set(pref_key(:screen_reader), true, prefs_name)
    UserPreferences.set(pref_key(:high_contrast), false, prefs_name)
    UserPreferences.set(pref_key(:reduced_motion), false, prefs_name)
    UserPreferences.set(pref_key(:keyboard_focus), true, prefs_name)
    UserPreferences.set(pref_key(:large_text), false, prefs_name)
    UserPreferences.set(pref_key(:silence_announcements), false, prefs_name)

    on_exit(fn ->
      if pid = Process.whereis(prefs_name), do: GenServer.stop(pid)
    end)

    {:ok, prefs_name: prefs_name}
  end

  def setup_test_preferences_with_events(prefs_name) do
    {:ok, pid_of_prefs} =
      GenServer.start_link(UserPreferences, [test_mode?: true],
        name: prefs_name
      )

    # Ensure EventManager is started
    Raxol.Core.Events.Manager.init()

    # Set up preferences
    UserPreferences.set(pref_key(:screen_reader), true, prefs_name)
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
    Raxol.Core.Accessibility.register_element_metadata("search_button", %{
      label: "Search"
    })
    Raxol.Core.Accessibility.register_element_metadata("text_input", %{
      label: "Username"
    })
    Raxol.Core.Accessibility.register_element_metadata("submit_button", %{
      label: "Submit Form"
    })
  end

  def clear_test_state(prefs_name) do
    Raxol.Core.Accessibility.clear_announcements()
    Raxol.Core.Accessibility.disable(prefs_name)
  end
end
