defmodule Raxol.AccessibilityTestHelpers do
  @moduledoc """
  Test helpers for accessibility testing in Raxol applications.
  
  This module provides specialized helpers for testing accessibility features
  and compliance with Web Content Accessibility Guidelines (WCAG) where
  applicable to terminal UI applications.
  
  ## Features
  
  - Test helpers for screen reader announcements
  - Color contrast testing tools
  - Keyboard navigation test helpers
  - Focus management testing
  - High contrast mode testing
  - Reduced motion testing
  
  ## Usage
  
  ```elixir
  use ExUnit.Case
  import Raxol.AccessibilityTestHelpers
  
  test "button has proper contrast ratio" do
    assert_sufficient_contrast("#0077CC", "#FFFFFF")
  end
  
  test "screen reader announcement is made" do
    with_screen_reader_spy fn ->
      # Perform action that should trigger announcement
      click_button("Save")
      
      # Assert announcement was made
      assert_announced("File saved successfully")
    end
  end
  """
  
  alias Raxol.Core.Accessibility
  alias Raxol.Style.Colors.Utilities
  alias Raxol.Core.FocusManager
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.Events.Manager, as: EventManager
  
  @doc """
  Run a test with a spy on screen reader announcements.
  
  This function sets up a spy to capture screen reader announcements
  during the execution of the provided function, allowing you to
  assert that specific announcements were made.
  
  ## Examples
  
      with_screen_reader_spy fn ->
        # Perform action
        click_button("Save")
        
        # Assert announcement
        assert_announced("File saved successfully")
      end
  """
  def with_screen_reader_spy(fun) do
    # Initialize announcement spy
    Process.put(:accessibility_test_announcements, [])
    
    # Register spy handler
    EventManager.register_handler(:accessibility_announcement, __MODULE__, :handle_announcement_spy)
    
    try do
      # Run the provided function
      fun.()
    after
      # Clean up spy handler
      EventManager.unregister_handler(:accessibility_announcement, __MODULE__, :handle_announcement_spy)
    end
  end
  
  @doc """
  Assert that a specific announcement was made to the screen reader.
  
  ## Parameters
  
  * `expected` - The expected announcement text or pattern
  * `opts` - Additional options
  
  ## Options
  
  * `:exact` - Require exact match (default: `false`)
  * `:context` - Additional context for the error message
  
  ## Examples
  
      assert_announced("File saved")
      
      assert_announced(~r/File .* saved/, exact: false)
  """
  def assert_announced(expected, opts \\ []) do
    announcements = Process.get(:accessibility_test_announcements, [])
    
    exact = Keyword.get(opts, :exact, false)
    context = Keyword.get(opts, :context, "")
    
    if exact do
      # Check for exact match
      unless Enum.member?(announcements, expected) do
        raise ExUnit.AssertionError,
          message: "Expected screen reader announcement \"#{expected}\" was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
      end
    else
      # Check for pattern match
      if is_binary(expected) do
        # Search for substring
        unless Enum.any?(announcements, &String.contains?(&1, expected)) do
          raise ExUnit.AssertionError,
            message: "Expected screen reader announcement containing \"#{expected}\" was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        end
      else
        # Assume Regex
        unless Enum.any?(announcements, &Regex.match?(expected, &1)) do
          raise ExUnit.AssertionError,
            message: "Expected screen reader announcement matching #{inspect(expected)} was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        end
      end
    end
  end
  
  @doc """
  Assert that no announcements were made to the screen reader.
  
  ## Parameters
  
  * `opts` - Additional options
  
  ## Options
  
  * `:context` - Additional context for the error message
  
  ## Examples
  
      assert_no_announcements()
  """
  def assert_no_announcements(opts \\ []) do
    announcements = Process.get(:accessibility_test_announcements, [])
    
    context = Keyword.get(opts, :context, "")
    
    unless Enum.empty?(announcements) do
      raise ExUnit.AssertionError,
        message: "Expected no screen reader announcements, but got: #{inspect(announcements)}\n#{context}"
    end
  end
  
  @doc """
  Assert that a color combination has sufficient contrast for accessibility.
  
  ## Parameters
  
  * `foreground` - The foreground color (typically text)
  * `background` - The background color
  * `level` - The WCAG level to check against (`:aa` or `:aaa`) (default: `:aa`)
  * `size` - The text size (`:normal` or `:large`) (default: `:normal`)
  * `opts` - Additional options
  
  ## Options
  
  * `:context` - Additional context for the error message
  
  ## Examples
  
      assert_sufficient_contrast("#000000", "#FFFFFF")
      
      assert_sufficient_contrast("#777777", "#FFFFFF", :aaa, :large)
  """
  def assert_sufficient_contrast(foreground, background, level \\ :aa, size \\ :normal, opts \\ []) do
    # Calculate contrast ratio
    ratio = Utilities.contrast_ratio(foreground, background)
    
    # Determine minimum required ratio
    min_ratio = case {level, size} do
      {:aa, :normal} -> 4.5
      {:aa, :large} -> 3.0
      {:aaa, :normal} -> 7.0
      {:aaa, :large} -> 4.5
    end
    
    context = Keyword.get(opts, :context, "")
    
    unless ratio >= min_ratio do
      raise ExUnit.AssertionError,
        message: "Insufficient contrast ratio: got #{ratio}, need #{min_ratio} for #{level}/#{size}.\nForeground: #{foreground}, Background: #{background}\n#{context}"
    end
  end
  
  @doc """
  Simulate a keyboard navigation sequence.
  
  This function simulates pressing the tab key to navigate through focusable elements.
  
  ## Parameters
  
  * `count` - Number of tab key presses to simulate
  * `opts` - Additional options
  
  ## Options
  
  * `:shift` - Whether to use Shift+Tab (backward navigation) (default: `false`)
  * `:starting_element` - Element to start navigation from (default: current focus)
  
  ## Examples
  
      simulate_keyboard_navigation(3)
      
      simulate_keyboard_navigation(2, shift: true)
      
      simulate_keyboard_navigation(1, starting_element: "search_field")
  """
  def simulate_keyboard_navigation(count, opts \\ []) do
    # Get options
    shift = Keyword.get(opts, :shift, false)
    starting_element = Keyword.get(opts, :starting_element)
    
    # Set starting element if provided
    if starting_element do
      FocusManager.set_focus(starting_element)
    end
    
    # Simulate tab key presses
    Enum.each(1..count, fn _ ->
      # Get current focus
      current = FocusManager.get_current_focus()
      
      # Get next focusable
      next = if shift do
        FocusManager.get_previous_focusable(current)
      else
        FocusManager.get_next_focusable(current)
      end
      
      # Move focus
      if next do
        FocusManager.set_focus(next)
      end
    end)
  end
  
  @doc """
  Assert that the focus is on a specific element.
  
  ## Parameters
  
  * `expected` - The expected focused element
  * `opts` - Additional options
  
  ## Options
  
  * `:context` - Additional context for the error message
  
  ## Examples
  
      assert_focus_on("search_button")
  """
  def assert_focus_on(expected, opts \\ []) do
    current = FocusManager.get_current_focus()
    
    context = Keyword.get(opts, :context, "")
    
    unless current == expected do
      raise ExUnit.AssertionError,
        message: "Expected focus on \"#{expected}\", but it's on \"#{current}\"\n#{context}"
    end
  end
  
  @doc """
  Test keyboard shortcut handling.
  
  This function simulates pressing a keyboard shortcut and verifies that
  the appropriate action is triggered.
  
  ## Parameters
  
  * `shortcut` - The shortcut to test (e.g., "Ctrl+S")
  * `opts` - Additional options
  
  ## Options
  
  * `:context` - Additional context for the error message
  * `:in_context` - The context in which to test the shortcut
  
  ## Examples
  
      test_keyboard_shortcut("Ctrl+S")
      
      test_keyboard_shortcut("Ctrl+F", in_context: :editor)
  """
  def test_keyboard_shortcut(shortcut, opts \\ []) do
    # Get options
    context = Keyword.get(opts, :context, "")
    shortcut_context = Keyword.get(opts, :in_context)
    
    # Set context if provided
    if shortcut_context do
      KeyboardShortcuts.set_context(shortcut_context)
    end
    
    # Initialize action spy
    Process.put(:shortcut_action_executed, false)
    Process.put(:shortcut_action_id, nil)
    
    # Register spy handler
    EventManager.register_handler(:shortcut_executed, __MODULE__, :handle_shortcut_spy)
    
    try do
      # Simulate shortcut
      KeyboardShortcuts.handle_shortcut(shortcut)
      
      # Check if action was executed
      executed = Process.get(:shortcut_action_executed, false)
      action_id = Process.get(:shortcut_action_id)
      
      unless executed do
        raise ExUnit.AssertionError,
          message: "Keyboard shortcut \"#{shortcut}\" did not trigger any action.\n#{context}"
      end
      
      # Return the action ID for further assertions
      action_id
    after
      # Clean up spy handler
      EventManager.unregister_handler(:shortcut_executed, __MODULE__, :handle_shortcut_spy)
    end
  end
  
  @doc """
  Test high contrast mode.
  
  This function temporarily enables high contrast mode, runs the provided
  function, and then restores the previous setting.
  
  ## Examples
  
      with_high_contrast fn ->
        # Test how elements look in high contrast mode
        assert color_of("button") == "#FFFFFF"
      end
  """
  def with_high_contrast(fun) do
    # Store current setting
    previous = Accessibility.high_contrast_enabled?()
    
    # Enable high contrast
    Accessibility.set_high_contrast(true)
    
    try do
      # Run the provided function
      fun.()
    after
      # Restore previous setting
      Accessibility.set_high_contrast(previous)
    end
  end
  
  @doc """
  Test reduced motion mode.
  
  This function temporarily enables reduced motion mode, runs the provided
  function, and then restores the previous setting.
  
  ## Examples
  
      with_reduced_motion fn ->
        # Test animations with reduced motion
        refute animation_running?("focus_ring", :pulse)
      end
  """
  def with_reduced_motion(fun) do
    # Store current setting
    previous = Accessibility.reduced_motion_enabled?()
    
    # Enable reduced motion
    Accessibility.set_reduced_motion(true)
    
    try do
      # Run the provided function
      fun.()
    after
      # Restore previous setting
      Accessibility.set_reduced_motion(previous)
    end
  end
  
  @doc """
  Spy handler for screen reader announcements.
  """
  def handle_announcement_spy({:accessibility_announcement, message}) do
    # Record the announcement
    announcements = Process.get(:accessibility_test_announcements, [])
    updated_announcements = [message | announcements]
    Process.put(:accessibility_test_announcements, updated_announcements)
    
    :ok
  end
  
  @doc """
  Spy handler for shortcut execution.
  """
  def handle_shortcut_spy({:shortcut_executed, shortcut_id, _shortcut}) do
    # Record execution
    Process.put(:shortcut_action_executed, true)
    Process.put(:shortcut_action_id, shortcut_id)
    
    :ok
  end
end 