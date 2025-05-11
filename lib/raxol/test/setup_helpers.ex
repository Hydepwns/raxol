defmodule Raxol.Test.SetupHelpers do
  @moduledoc """
  Common test setup and teardown helpers for Raxol tests.
  Provides standardized setup for components, accessibility, preferences, and more.
  """

  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.I18n
  alias Raxol.Animation.Framework
  alias Raxol.ColorSystem

  import ExUnit.Assertions
  import ExUnit.Callbacks

  @doc """
  Sets up a test environment with common dependencies.
  Returns a context map with initialized components.
  """
  def setup_test_env(opts \\ []) do
    # Initialize core systems
    I18n.init()
    Framework.init()
    Accessibility.enable()
    ColorSystem.init()

    # Setup preferences with test-specific name
    prefs_name = Keyword.get(opts, :prefs_name, __MODULE__.TestPrefs)
    {:ok, _pid} = start_supervised({UserPreferences, [test_mode?: true, name: prefs_name]})

    # Set default preferences
    set_default_preferences(prefs_name)

    # Wait for preferences to be applied
    assert_receive {:preferences_applied}, 100

    # Return context with cleanup
    context = %{
      prefs_name: prefs_name,
      snapshots_dir: Keyword.get(opts, :snapshots_dir, "test/snapshots")
    }

    on_exit(fn ->
      cleanup_test_env(context)
    end)

    context
  end

  @doc """
  Sets up default preferences for testing.
  """
  def set_default_preferences(prefs_name) do
    UserPreferences.set([:accessibility, :enabled], true, prefs_name)
    UserPreferences.set([:accessibility, :screen_reader], true, prefs_name)
    UserPreferences.set([:accessibility, :high_contrast], false, prefs_name)
    UserPreferences.set([:accessibility, :reduced_motion], false, prefs_name)
    UserPreferences.set([:accessibility, :keyboard_focus], true, prefs_name)
    UserPreferences.set([:accessibility, :large_text], false, prefs_name)
    UserPreferences.set([:accessibility, :silence_announcements], false, prefs_name)
  end

  @doc """
  Cleans up test environment.
  """
  def cleanup_test_env(context) do
    if pid = Process.whereis(context.prefs_name), do: GenServer.stop(pid)
    Framework.stop()
    Accessibility.disable()
    ColorSystem.apply_theme(:default)
  end

  @doc """
  Sets up a component for isolated testing.
  """
  def setup_isolated_component(component, props \\ %{}) do
    {:ok, state} = component.init(props)
    test_pid = self()

    mock_event_system = fn event ->
      send(test_pid, {:event, event})
    end

    {:ok,
     %{
       module: component,
       state: state,
       subscriptions: [],
       event_handler: mock_event_system
     }}
  end

  @doc """
  Sets up a component hierarchy for testing parent-child relationships.
  """
  def setup_component_hierarchy(parent_module, child_module) do
    {:ok, parent} = setup_isolated_component(parent_module)
    {:ok, child} = setup_isolated_component(child_module)

    child = Map.put(child, :parent, parent)
    parent = Map.put(parent, :children, [child])

    {:ok, parent, child}
  end
end
