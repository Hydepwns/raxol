defmodule Raxol.Core.UXRefinementTest do
  use ExUnit.Case, async: true
  
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.Events.Manager, as: EventManager
  
  setup do
    # Initialize dependencies
    EventManager.init()
    
    # Initialize UXRefinement module
    UXRefinement.init()
    
    on_exit(fn ->
      # Clean up any enabled features
      [:focus_management, :keyboard_navigation, :hints, :focus_ring, :accessibility, :perceived_performance]
      |> Enum.each(fn feature ->
        if UXRefinement.feature_enabled?(feature) do
          UXRefinement.disable_feature(feature)
        end
      end)
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
      refute UXRefinement.feature_enabled?(:perceived_performance)
    end
  end
  
  describe "enable_feature/2" do
    test "enables focus_management feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:focus_management)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:focus_management)
    end
    
    test "enables keyboard_navigation feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:keyboard_navigation)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:keyboard_navigation)
    end
    
    test "enables hints feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:hints)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:hints)
    end
    
    test "enables focus_ring feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:focus_ring)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:focus_ring)
    end
    
    test "enables accessibility feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:accessibility)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:accessibility)
    end
    
    test "enables perceived_performance feature" do
      # Enable feature
      assert :ok = UXRefinement.enable_feature(:perceived_performance)
      
      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:perceived_performance)
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
      # Enable then disable
      UXRefinement.enable_feature(:focus_management)
      assert :ok = UXRefinement.disable_feature(:focus_management)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:focus_management)
    end
    
    test "disables keyboard_navigation feature" do
      # Enable then disable
      UXRefinement.enable_feature(:keyboard_navigation)
      assert :ok = UXRefinement.disable_feature(:keyboard_navigation)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:keyboard_navigation)
    end
    
    test "disables hints feature" do
      # Enable then disable
      UXRefinement.enable_feature(:hints)
      assert :ok = UXRefinement.disable_feature(:hints)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:hints)
    end
    
    test "disables focus_ring feature" do
      # Enable then disable
      UXRefinement.enable_feature(:focus_ring)
      assert :ok = UXRefinement.disable_feature(:focus_ring)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:focus_ring)
    end
    
    test "disables accessibility feature" do
      # Enable then disable
      UXRefinement.enable_feature(:accessibility)
      assert :ok = UXRefinement.disable_feature(:accessibility)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:accessibility)
    end
    
    test "disables perceived_performance feature" do
      # Enable then disable
      UXRefinement.enable_feature(:perceived_performance)
      assert :ok = UXRefinement.disable_feature(:perceived_performance)
      
      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:perceived_performance)
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
      :ok
    end
    
    test "registers and retrieves a basic component hint" do
      # Register a basic hint
      hint_info = %{basic: "Basic hint"}
      assert :ok = UXRefinement.register_component_hint("test_component", hint_info)
      
      # Retrieve the hint
      assert UXRefinement.get_component_hint("test_component", :basic) == "Basic hint"
    end
    
    test "registers and retrieves a detailed component hint" do
      # Register a detailed hint
      hint_info = %{basic: "Basic hint", detailed: "Detailed hint"}
      assert :ok = UXRefinement.register_component_hint("test_component", hint_info)
      
      # Retrieve the detailed hint
      assert UXRefinement.get_component_hint("test_component", :detailed) == "Detailed hint"
    end
    
    test "registers and retrieves examples hint" do
      # Register a hint with examples
      hint_info = %{
        basic: "Basic hint",
        examples: "Example usage"
      }
      assert :ok = UXRefinement.register_component_hint("test_component", hint_info)
      
      # Retrieve the examples
      assert UXRefinement.get_component_hint("test_component", :examples) == "Example usage"
    end
    
    test "registers and retrieves shortcuts" do
      # Register a hint with shortcuts
      shortcuts = [{"Ctrl+S", "Save"}, {"Esc", "Cancel"}]
      hint_info = %{
        basic: "Basic hint",
        shortcuts: shortcuts
      }
      assert :ok = UXRefinement.register_component_hint("test_component", hint_info)
      
      # Retrieve the shortcuts
      assert UXRefinement.get_component_hint("test_component", :shortcuts) == shortcuts
    end
    
    test "returns nil for unknown component" do
      assert UXRefinement.get_component_hint("unknown_component", :basic) == nil
    end
    
    test "returns nil for unknown hint level" do
      # Register a basic hint
      hint_info = %{basic: "Basic hint"}
      UXRefinement.register_component_hint("test_component", hint_info)
      
      # Try to retrieve a detailed hint that doesn't exist
      assert UXRefinement.get_component_hint("test_component", :detailed) == nil
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
      assert :ok = UXRefinement.register_component_hint("test_component", "String hint")
      
      # Retrieve the hint
      assert UXRefinement.get_component_hint("test_component", :basic) == "String hint"
    end
  end
  
  describe "register_accessibility_metadata/2" do
    setup do
      UXRefinement.enable_feature(:accessibility)
      :ok
    end
    
    test "registers accessibility metadata" do
      # Register metadata
      metadata = %{
        announce: "Test component",
        role: :button,
        label: "Test"
      }
      
      assert :ok = UXRefinement.register_accessibility_metadata("test_component", metadata)
    end
    
    test "does nothing when accessibility feature is disabled" do
      # Disable accessibility
      UXRefinement.disable_feature(:accessibility)
      
      # Register metadata
      metadata = %{
        announce: "Test component",
        role: :button,
        label: "Test"
      }
      
      assert :ok = UXRefinement.register_accessibility_metadata("test_component", metadata)
    end
  end
  
  describe "announce/2" do
    setup do
      UXRefinement.enable_feature(:accessibility)
      :ok
    end
    
    test "makes an accessibility announcement" do
      assert :ok = UXRefinement.announce("Test announcement")
    end
    
    test "does nothing when accessibility feature is disabled" do
      # Disable accessibility
      UXRefinement.disable_feature(:accessibility)
      
      assert :ok = UXRefinement.announce("Test announcement")
    end
  end
  
  describe "optimize_perceived_performance/1" do
    setup do
      UXRefinement.enable_feature(:perceived_performance)
      :ok
    end
    
    test "applies performance optimizations" do
      assert :ok = UXRefinement.optimize_perceived_performance()
    end
    
    test "applies specific optimizations" do
      assert :ok = UXRefinement.optimize_perceived_performance(
        loading_indicator: true,
        background_processing: false
      )
    end
    
    test "does nothing when perceived_performance feature is disabled" do
      # Disable perceived_performance
      UXRefinement.disable_feature(:perceived_performance)
      
      assert :ok = UXRefinement.optimize_perceived_performance()
    end
  end
end 