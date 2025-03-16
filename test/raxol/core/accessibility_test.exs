defmodule Raxol.Core.AccessibilityTest do
  use ExUnit.Case, async: true
  
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility.ThemeIntegration
  
  setup do
    # Initialize event manager for tests
    EventManager.init()
    
    # Clean up accessibility state before and after tests
    Accessibility.disable()
    
    # Mock ThemeIntegration to avoid side effects
    :meck.new(ThemeIntegration, [:passthrough])
    :meck.expect(ThemeIntegration, :init, fn -> :ok end)
    :meck.expect(ThemeIntegration, :cleanup, fn -> :ok end)
    :meck.expect(ThemeIntegration, :apply_current_settings, fn -> :ok end)
    :meck.expect(ThemeIntegration, :get_current_colors, fn -> 
      %{
        background: :black,
        foreground: :white,
        accent: :yellow,
        focus: :white,
        button: :yellow,
        error: :red,
        success: :green,
        warning: :yellow,
        info: :cyan,
        border: :white
      }
    end)
    
    on_exit(fn ->
      Accessibility.disable()
      :meck.unload(ThemeIntegration)
    end)
    
    :ok
  end
  
  describe "enable/1" do
    test "enables accessibility features with default options" do
      assert :ok = Accessibility.enable()
      
      # Verify options are stored
      options = Process.get(:accessibility_options)
      assert options[:screen_reader] == true
      assert options[:high_contrast] == false
      assert options[:reduced_motion] == false
      assert options[:keyboard_focus] == true
      assert options[:large_text] == false
      
      # Verify announcement queue is initialized
      assert Process.get(:accessibility_announcements) == []
      
      # Verify ThemeIntegration was initialized
      assert :meck.called(ThemeIntegration, :init, [])
      assert :meck.called(ThemeIntegration, :apply_current_settings, [])
    end
    
    test "enables accessibility features with custom options" do
      assert :ok = Accessibility.enable(high_contrast: true, reduced_motion: true)
      
      # Verify options are stored
      options = Process.get(:accessibility_options)
      assert options[:screen_reader] == true
      assert options[:high_contrast] == true
      assert options[:reduced_motion] == true
    end
  end
  
  describe "disable/0" do
    test "disables accessibility features" do
      # First enable
      Accessibility.enable()
      
      # Then disable
      assert :ok = Accessibility.disable()
      
      # Verify options are removed
      assert Process.get(:accessibility_options) == nil
      assert Process.get(:accessibility_announcements) == nil
      
      # Verify ThemeIntegration was cleaned up
      assert :meck.called(ThemeIntegration, :cleanup, [])
    end
  end
  
  describe "announce/2" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "adds announcement to queue" do
      assert :ok = Accessibility.announce("Test announcement")
      
      # Check queue
      queue = Process.get(:accessibility_announcements)
      assert length(queue) == 1
      
      # Check announcement content
      [announcement] = queue
      assert announcement.message == "Test announcement"
      assert announcement.priority == :medium
      assert announcement.interrupt == false
    end
    
    test "respects priority levels" do
      # Add low priority announcement
      Accessibility.announce("Low priority", priority: :low)
      
      # Add high priority announcement
      Accessibility.announce("High priority", priority: :high)
      
      # Add medium priority announcement
      Accessibility.announce("Medium priority", priority: :medium)
      
      # Check queue ordering - should be high, medium, low
      queue = Process.get(:accessibility_announcements)
      assert length(queue) == 3
      
      [first, second, third] = queue
      assert first.message == "High priority"
      assert second.message == "Medium priority"
      assert third.message == "Low priority"
    end
    
    test "interrupt flag clears the queue" do
      # Add some announcements
      Accessibility.announce("First announcement")
      Accessibility.announce("Second announcement")
      
      # Add interrupting announcement
      Accessibility.announce("Interrupting announcement", interrupt: true)
      
      # Check queue - should only have the interrupting announcement
      queue = Process.get(:accessibility_announcements)
      assert length(queue) == 1
      
      [announcement] = queue
      assert announcement.message == "Interrupting announcement"
    end
    
    test "does nothing when screen reader is disabled" do
      # Disable screen reader
      options = Process.get(:accessibility_options)
      updated_options = Keyword.put(options, :screen_reader, false)
      Process.put(:accessibility_options, updated_options)
      
      # Clear queue
      Process.put(:accessibility_announcements, [])
      
      # Try to announce
      Accessibility.announce("Test announcement")
      
      # Queue should still be empty
      queue = Process.get(:accessibility_announcements)
      assert queue == []
    end
  end
  
  describe "get_next_announcement/0" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "returns and removes the next announcement" do
      # Add announcements
      Accessibility.announce("First announcement")
      Accessibility.announce("Second announcement")
      
      # Get next announcement
      next = Accessibility.get_next_announcement()
      assert next == "First announcement"
      
      # Queue should now only have one announcement
      queue = Process.get(:accessibility_announcements)
      assert length(queue) == 1
      assert hd(queue).message == "Second announcement"
    end
    
    test "returns nil when queue is empty" do
      # Ensure queue is empty
      Process.put(:accessibility_announcements, [])
      
      # Get next announcement
      next = Accessibility.get_next_announcement()
      assert next == nil
    end
  end
  
  describe "clear_announcements/0" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "clears the announcement queue" do
      # Add announcements
      Accessibility.announce("First announcement")
      Accessibility.announce("Second announcement")
      
      # Clear the queue
      assert :ok = Accessibility.clear_announcements()
      
      # Queue should be empty
      queue = Process.get(:accessibility_announcements)
      assert queue == []
    end
  end
  
  describe "set_high_contrast/1" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "updates high contrast setting" do
      # Store test process pid
      test_pid = self()
      
      # Mock EventManager.dispatch to capture events
      :meck.new(EventManager, [:passthrough])
      :meck.expect(EventManager, :dispatch, fn event ->
        send(test_pid, {:dispatch, event})
        :ok
      end)
      
      try do
        # Enable high contrast
        assert :ok = Accessibility.set_high_contrast(true)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:high_contrast] == true
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_high_contrast, true}}
        
        # Disable high contrast
        assert :ok = Accessibility.set_high_contrast(false)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:high_contrast] == false
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_high_contrast, false}}
      after
        :meck.unload(EventManager)
      end
    end
  end
  
  describe "set_reduced_motion/1" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "updates reduced motion setting" do
      # Store test process pid
      test_pid = self()
      
      # Mock EventManager.dispatch to capture events
      :meck.new(EventManager, [:passthrough])
      :meck.expect(EventManager, :dispatch, fn event ->
        send(test_pid, {:dispatch, event})
        :ok
      end)
      
      try do
        # Enable reduced motion
        assert :ok = Accessibility.set_reduced_motion(true)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:reduced_motion] == true
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_reduced_motion, true}}
        
        # Disable reduced motion
        assert :ok = Accessibility.set_reduced_motion(false)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:reduced_motion] == false
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_reduced_motion, false}}
      after
        :meck.unload(EventManager)
      end
    end
  end
  
  describe "set_large_text/1" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "updates large text setting" do
      # Store test process pid
      test_pid = self()
      
      # Mock EventManager.dispatch to capture events
      :meck.new(EventManager, [:passthrough])
      :meck.expect(EventManager, :dispatch, fn event ->
        send(test_pid, {:dispatch, event})
        :ok
      end)
      
      try do
        # Enable large text
        assert :ok = Accessibility.set_large_text(true)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:large_text] == true
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_large_text, true}}
        
        # Disable large text
        assert :ok = Accessibility.set_large_text(false)
        
        # Check option
        options = Process.get(:accessibility_options)
        assert options[:large_text] == false
        
        # Verify event was dispatched
        assert_received {:dispatch, {:accessibility_large_text, false}}
      after
        :meck.unload(EventManager)
      end
    end
  end
  
  describe "get_text_scale/0" do
    test "returns default text scale when not set" do
      assert Accessibility.get_text_scale() == 1.0
    end
    
    test "returns current text scale" do
      # Set text scale
      Process.put(:accessibility_text_scale, 1.5)
      
      assert Accessibility.get_text_scale() == 1.5
      
      # Clean up
      Process.delete(:accessibility_text_scale)
    end
  end
  
  describe "get_color_scheme/0" do
    test "returns current color scheme from ThemeIntegration" do
      colors = Accessibility.get_color_scheme()
      
      assert colors.background == :black
      assert colors.foreground == :white
      assert colors.accent == :yellow
      
      # Verify ThemeIntegration was called
      assert :meck.called(ThemeIntegration, :get_current_colors, [])
    end
  end
  
  describe "high_contrast_enabled?/0, reduced_motion_enabled?/0, large_text_enabled?/0" do
    test "return false by default" do
      assert Accessibility.high_contrast_enabled?() == false
      assert Accessibility.reduced_motion_enabled?() == false
      assert Accessibility.large_text_enabled?() == false
    end
    
    test "return current settings when enabled" do
      # Set options
      Process.put(:accessibility_options, [
        high_contrast: true,
        reduced_motion: true, 
        large_text: true
      ])
      
      assert Accessibility.high_contrast_enabled?() == true
      assert Accessibility.reduced_motion_enabled?() == true
      assert Accessibility.large_text_enabled?() == true
      
      # Clean up
      Process.delete(:accessibility_options)
    end
  end
  
  describe "register_element_metadata/2 and get_element_metadata/1" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "registers and retrieves element metadata" do
      # Register metadata
      metadata = %{
        announce: "Search button. Press Enter to search.",
        role: :button,
        label: "Search",
        shortcut: "Alt+S"
      }
      
      assert :ok = Accessibility.register_element_metadata("search_button", metadata)
      
      # Retrieve metadata
      retrieved = Accessibility.get_element_metadata("search_button")
      assert retrieved == metadata
    end
    
    test "returns nil for unknown elements" do
      assert Accessibility.get_element_metadata("unknown_element") == nil
    end
  end
  
  describe "get_component_style/1" do
    test "returns empty map for unknown component type" do
      assert Accessibility.get_component_style(:unknown) == %{}
    end
    
    test "returns component style when available" do
      # Set component styles
      styles = %{
        button: %{background: :blue, foreground: :white}
      }
      Process.put(:accessibility_component_styles, styles)
      
      assert Accessibility.get_component_style(:button) == %{background: :blue, foreground: :white}
      
      # Clean up
      Process.delete(:accessibility_component_styles)
    end
  end
  
  describe "handle_focus_change/2" do
    setup do
      Accessibility.enable()
      :ok
    end
    
    test "announces element when it receives focus" do
      # Register metadata with announcement
      metadata = %{
        announce: "Search button. Press Enter to search."
      }
      
      Accessibility.register_element_metadata("search_button", metadata)
      
      # Clear queue
      Process.put(:accessibility_announcements, [])
      
      # Simulate focus change
      Accessibility.handle_focus_change(nil, "search_button")
      
      # Check announcement
      queue = Process.get(:accessibility_announcements)
      assert length(queue) == 1
      assert hd(queue).message == "Search button. Press Enter to search."
    end
    
    test "does nothing when element has no announcement" do
      # Register metadata without announcement
      metadata = %{
        role: :button,
        label: "Search"
      }
      
      Accessibility.register_element_metadata("search_button", metadata)
      
      # Clear queue
      Process.put(:accessibility_announcements, [])
      
      # Simulate focus change
      Accessibility.handle_focus_change(nil, "search_button")
      
      # Check that no announcement was made
      queue = Process.get(:accessibility_announcements)
      assert queue == []
    end
  end
end 