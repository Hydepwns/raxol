defmodule Raxol.Core.UXRefinementTest do
  @moduledoc """
  Tests for the UX refinement system, including feature enablement,
  hint registration, and component hint management.
  """
  use ExUnit.Case, async: true
  import Mox

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.UXRefinement

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Configure the accessibility module to use the mock
    Application.put_env(:raxol, :accessibility_impl, AccessibilityMock)
    # Configure the focus manager to use the real module
    Application.put_env(:raxol, :focus_manager_impl, Raxol.Core.FocusManager)

    # Initialize dependencies
    EventManager.init()
    UXRefinement.init()

    on_exit(fn ->
      # Clean up any enabled features
      [
        :focus_management,
        :keyboard_navigation,
        :hints,
        :focus_ring,
        :accessibility
      ]
      |> Enum.each(fn feature ->
        if UXRefinement.feature_enabled?(feature) do
          UXRefinement.disable_feature(feature)
        end
      end)

      # Clean up EventManager
      if Process.whereis(EventManager), do: EventManager.cleanup()
    end)

    :ok
  end

  describe "init/0" do
    test "initializes UXRefinement state" do
      # Re-init to ensure clean state
      UXRefinement.init()

      # Verify no features are enabled
      refute UXRefinement.feature_enabled?(:focus_management)
      refute UXRefinement.feature_enabled?(:keyboard_navigation)
      refute UXRefinement.feature_enabled?(:hints)
      refute UXRefinement.feature_enabled?(:focus_ring)
      refute UXRefinement.feature_enabled?(:accessibility)
    end
  end

  describe "enable_feature/1" do
    test "enables focus_management feature" do
      assert :ok = UXRefinement.enable_feature(:focus_management)
      assert UXRefinement.feature_enabled?(:focus_management)
    end

    test "enables keyboard_navigation feature" do
      assert :ok = UXRefinement.enable_feature(:keyboard_navigation)
      assert UXRefinement.feature_enabled?(:keyboard_navigation)
    end

    test "enables hints feature" do
      # Allow HintDisplay.init to run
      assert :ok = UXRefinement.enable_feature(:hints)
      assert UXRefinement.feature_enabled?(:hints)
    end

    test "enables focus_ring feature" do
      assert :ok = UXRefinement.enable_feature(:focus_ring)
      assert UXRefinement.feature_enabled?(:focus_ring)
    end

    test "enables accessibility feature" do
      stub(AccessibilityMock, :enable, fn _opts,
                                          _user_preferences_pid_or_name ->
        :ok
      end)

      assert :ok = UXRefinement.enable_feature(:accessibility)
      assert UXRefinement.feature_enabled?(:accessibility)
    end

    test "enables multiple features" do
      # Enable features
      UXRefinement.enable_feature(:focus_management)
      UXRefinement.enable_feature(:keyboard_navigation)

      # Verify features are enabled
      assert UXRefinement.feature_enabled?(:focus_management)
      assert UXRefinement.feature_enabled?(:keyboard_navigation)
    end

    test "does nothing if feature is already enabled" do
      # Enable feature twice
      UXRefinement.enable_feature(:focus_management)
      assert :ok = UXRefinement.enable_feature(:focus_management)

      # Verify feature is still enabled
      assert UXRefinement.feature_enabled?(:focus_management)
    end
  end

  describe "disable_feature/1" do
    test "disables focus_management feature" do
      UXRefinement.enable_feature(:focus_management)
      assert :ok = UXRefinement.disable_feature(:focus_management)
      refute UXRefinement.feature_enabled?(:focus_management)
    end

    test "disables keyboard_navigation feature" do
      UXRefinement.enable_feature(:keyboard_navigation)
      assert :ok = UXRefinement.disable_feature(:keyboard_navigation)
      refute UXRefinement.feature_enabled?(:keyboard_navigation)
    end

    test "disables hints feature" do
      # Allow HintDisplay.init to run
      UXRefinement.enable_feature(:hints)
      assert :ok = UXRefinement.disable_feature(:hints)
      refute UXRefinement.feature_enabled?(:hints)
    end

    test "disables focus_ring feature" do
      UXRefinement.enable_feature(:focus_ring)
      assert :ok = UXRefinement.disable_feature(:focus_ring)
      refute UXRefinement.feature_enabled?(:focus_ring)
    end

    test "disables accessibility feature" do
      stub(AccessibilityMock, :enable, fn _opts,
                                          _user_preferences_pid_or_name ->
        :ok
      end)

      stub(AccessibilityMock, :disable, fn _user_preferences_pid_or_name ->
        :ok
      end)

      UXRefinement.enable_feature(:accessibility)
      assert :ok = UXRefinement.disable_feature(:accessibility)
      refute UXRefinement.feature_enabled?(:accessibility)
    end

    test "does nothing if feature is already disabled" do
      # Disable without enabling
      assert :ok = UXRefinement.disable_feature(:focus_management)

      # Verify feature is still disabled
      refute UXRefinement.feature_enabled?(:focus_management)
    end
  end

  describe "register_hint/2 and get_hint/1" do
    setup do
      UXRefinement.enable_feature(:hints)
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      :ok
    end

    test "registers and retrieves a hint" do
      # Register a hint
      assert :ok = UXRefinement.register_hint("test_component", "Test hint")

      # Retrieve the hint
      assert UXRefinement.get_hint("test_component") == "Test hint"
    end

    test "returns nil for unknown component" do
      assert UXRefinement.get_hint("unknown_component") == nil
    end

    test "does nothing when hints feature is disabled" do
      # Register a hint with hints enabled
      UXRefinement.register_hint("test_component", "Test hint")

      # Disable hints
      UXRefinement.disable_feature(:hints)

      # Trying to get hint should return nil
      assert UXRefinement.get_hint("test_component") == nil
    end
  end

  describe "register_component_hint/2 and get_component_hint/2" do
    setup do
      UXRefinement.enable_feature(:hints)
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      :ok
    end

    test "registers and retrieves a basic component hint" do
      # Register a basic hint
      hint_info = %{basic: "Basic hint"}

      assert :ok =
               UXRefinement.register_component_hint("test_component", hint_info)

      # Retrieve the hint
      assert UXRefinement.get_component_hint("test_component", :basic) ==
               "Basic hint"
    end

    test "registers and retrieves a detailed component hint" do
      # Register a detailed hint
      hint_info = %{basic: "Basic hint", detailed: "Detailed hint"}

      assert :ok =
               UXRefinement.register_component_hint("test_component", hint_info)

      # Retrieve the detailed hint
      assert UXRefinement.get_component_hint("test_component", :detailed) ==
               "Detailed hint"
    end

    test "registers and retrieves examples hint" do
      # Register a hint with examples
      hint_info = %{
        basic: "Basic hint",
        examples: "Example usage"
      }

      assert :ok =
               UXRefinement.register_component_hint("test_component", hint_info)

      # Retrieve the examples
      assert UXRefinement.get_component_hint("test_component", :examples) ==
               "Example usage"
    end

    test "register_component_hint/2 and get_component_hint/2 returns basic hint for unknown hint level" do
      # Register only a basic hint
      hint_info = %{basic: "Basic hint"}

      assert :ok =
               UXRefinement.register_component_hint("test_component", hint_info)

      # Getting detailed should return basic hint
      assert UXRefinement.get_component_hint("test_component", :detailed) ==
               "Basic hint"
    end

    test "returns nil for unknown component" do
      assert UXRefinement.get_component_hint("unknown_component", :basic) == nil
    end

    test "does nothing when hints feature is disabled" do
      # Register a hint with hints enabled
      hint_info = %{basic: "Basic hint"}
      UXRefinement.register_component_hint("test_component", hint_info)

      # Disable hints
      UXRefinement.disable_feature(:hints)

      # Trying to get hint should return nil
      assert UXRefinement.get_component_hint("test_component", :basic) == nil
    end

    test "normalizes string hint to basic hint" do
      # Register a string hint
      assert :ok =
               UXRefinement.register_component_hint(
                 "test_component",
                 "String hint"
               )

      # Retrieve the hint
      assert UXRefinement.get_component_hint("test_component", :basic) ==
               "String hint"
    end
  end

  describe "feature_enabled?/1" do
    test "returns true for enabled feature" do
      # Enable feature
      UXRefinement.enable_feature(:focus_management)

      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:focus_management)
    end

    test "returns false for disabled feature" do
      # Disable feature
      UXRefinement.disable_feature(:focus_management)

      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:focus_management)
    end
  end
end
