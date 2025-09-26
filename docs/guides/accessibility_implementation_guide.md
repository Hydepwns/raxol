# Accessibility Implementation Guide

## Overview

This guide provides comprehensive strategies for implementing accessibility features in Raxol applications, ensuring your terminal and web interfaces are usable by everyone, including users with disabilities.

## Accessibility Principles

### The Four POUR Principles

1. **Perceivable**: Information must be presentable in ways users can perceive
2. **Operable**: Interface components must be operable by all users  
3. **Understandable**: Information and UI operation must be understandable
4. **Robust**: Content must be robust enough for various assistive technologies

## Core Accessibility Features

### 1. Screen Reader Support

```elixir
defmodule MyApp.AccessibleComponents do
  @moduledoc """
  Components with built-in screen reader support.
  """
  
  use Raxol.UI, framework: :liveview
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def accessible_button(assigns) do
    assigns = 
      assigns
      |> assign_new(:aria_label, fn -> nil end)
      |> assign_new(:aria_describedby, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign(:button_attrs, build_button_attrs(assigns))
    
    ~H"""
    <button 
      type="button"
      {@button_attrs}
      class="accessible-button"
    >
      <%= if assigns[:icon_only] do %>
        <span class="sr-only"><%= @aria_label || render_slot(@inner_block) %></span>
        <.icon name={@icon} />
      <% else %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </button>
    """
  end
  
  defp build_button_attrs(assigns) do
    base_attrs = [
      role: "button",
      tabindex: "0"
    ]
    
    aria_attrs = []
    
    aria_attrs = if assigns[:aria_label] do
      [{"aria-label", assigns.aria_label} | aria_attrs]
    else
      aria_attrs
    end
    
    aria_attrs = if assigns[:aria_describedby] do
      [{"aria-describedby", assigns.aria_describedby} | aria_attrs]
    else
      aria_attrs
    end
    
    aria_attrs = if assigns[:disabled] do
      [{"aria-disabled", "true"} | aria_attrs]
    else
      aria_attrs
    end
    
    base_attrs ++ aria_attrs ++ (assigns[:rest] || [])
  end
end
```

### 2. Keyboard Navigation

```elixir
defmodule MyApp.KeyboardNavigation do
  @moduledoc """
  Comprehensive keyboard navigation support for terminal applications.
  """
  
  use Raxol.UI, framework: :raw
  
  defstruct [
    :focus_index,
    :focusable_elements,
    :navigation_mode,
    :shortcuts,
    :focus_trap
  ]
  
  def new(opts \\ []) do
    %__MODULE__{
      focus_index: 0,
      focusable_elements: [],
      navigation_mode: Keyword.get(opts, :mode, :sequential),
      shortcuts: Keyword.get(opts, :shortcuts, %{}),
      focus_trap: Keyword.get(opts, :focus_trap, false)
    }
  end
  
  def handle_keypress(nav_state, key) do
    case key do
      # Tab navigation
      :tab -> move_focus(nav_state, :next)
      {:shift, :tab} -> move_focus(nav_state, :previous)
      
      # Arrow key navigation  
      :up -> move_focus(nav_state, :up)
      :down -> move_focus(nav_state, :down)
      :left -> move_focus(nav_state, :left)
      :right -> move_focus(nav_state, :right)
      
      # Enter/Space activation
      :enter -> activate_focused_element(nav_state)
      :space -> activate_focused_element(nav_state)
      
      # Escape - exit focus trap or cancel
      :escape -> handle_escape(nav_state)
      
      # Custom shortcuts
      shortcut when is_map_key(nav_state.shortcuts, shortcut) ->
        execute_shortcut(nav_state, shortcut)
        
      _ -> 
        {:unhandled, nav_state}
    end
  end
  
  defp move_focus(nav_state, direction) do
    new_index = calculate_new_focus_index(
      nav_state.focus_index,
      length(nav_state.focusable_elements),
      direction,
      nav_state.navigation_mode
    )
    
    new_state = %{nav_state | focus_index: new_index}
    
    # Announce focus change to screen reader
    element = Enum.at(nav_state.focusable_elements, new_index)
    announce_focus_change(element)
    
    {:focus_moved, new_state}
  end
  
  defp calculate_new_focus_index(current, total, direction, mode) do
    case {direction, mode} do
      {:next, :sequential} -> 
        rem(current + 1, total)
        
      {:previous, :sequential} ->
        rem(current - 1 + total, total)
        
      {:up, :grid} ->
        # Grid navigation logic
        grid_navigate(current, total, :up)
        
      {:down, :grid} ->
        grid_navigate(current, total, :down)
        
      _ -> 
        current
    end
  end
  
  defp announce_focus_change(element) do
    announcement = build_focus_announcement(element)
    Raxol.Core.Accessibility.announce(announcement, :polite)
  end
  
  defp build_focus_announcement(element) do
    case element do
      %{type: :button, label: label} ->
        "#{label}, button"
        
      %{type: :input, label: label, value: value} ->
        "#{label}, edit box, #{value}"
        
      %{type: :link, text: text} ->
        "#{text}, link"
        
      _ ->
        "Focusable element"
    end
  end
end
```

### 3. High Contrast and Theme Support

```elixir
defmodule MyApp.AccessibilityTheme do
  @moduledoc """
  Theme system with accessibility considerations.
  """
  
  @themes %{
    default: %{
      background: "#ffffff",
      foreground: "#000000", 
      accent: "#0066cc",
      contrast_ratio: 4.5
    },
    high_contrast: %{
      background: "#000000",
      foreground: "#ffffff",
      accent: "#ffff00", 
      contrast_ratio: 21.0
    },
    dark_high_contrast: %{
      background: "#000000",
      foreground: "#ffffff",
      accent: "#00ff00",
      contrast_ratio: 15.3
    },
    low_vision: %{
      background: "#1a1a1a",
      foreground: "#e6e6e6",
      accent: "#ff6b35",
      contrast_ratio: 7.0
    }
  }
  
  def get_theme(theme_name, accessibility_preferences \\ %{}) do
    base_theme = Map.get(@themes, theme_name, @themes.default)
    
    base_theme
    |> apply_contrast_preference(accessibility_preferences)
    |> apply_color_blindness_adjustments(accessibility_preferences)
    |> apply_font_size_preference(accessibility_preferences)
  end
  
  defp apply_contrast_preference(theme, preferences) do
    case Map.get(preferences, :contrast_preference) do
      :high -> force_high_contrast(theme)
      :maximum -> force_maximum_contrast(theme)
      _ -> theme
    end
  end
  
  defp force_high_contrast(theme) do
    %{
      theme |
      background: "#000000",
      foreground: "#ffffff",
      accent: "#ffff00",
      contrast_ratio: 21.0
    }
  end
  
  defp apply_color_blindness_adjustments(theme, preferences) do
    case Map.get(preferences, :color_blindness_type) do
      :protanopia -> adjust_for_protanopia(theme)
      :deuteranopia -> adjust_for_deuteranopia(theme)
      :tritanopia -> adjust_for_tritanopia(theme)
      _ -> theme
    end
  end
  
  defp adjust_for_protanopia(theme) do
    # Adjust red-green color blindness
    %{
      theme |
      accent: "#0080ff",  # Blue accent instead of red/green
      warning: "#ff8800", # Orange instead of red
      success: "#0080ff"  # Blue instead of green
    }
  end
  
  def calculate_contrast_ratio(foreground, background) do
    fg_luminance = calculate_luminance(foreground)
    bg_luminance = calculate_luminance(background)
    
    lighter = max(fg_luminance, bg_luminance)
    darker = min(fg_luminance, bg_luminance)
    
    (lighter + 0.05) / (darker + 0.05)
  end
  
  defp calculate_luminance(color_hex) do
    # Convert hex to RGB and calculate relative luminance
    {r, g, b} = hex_to_rgb(color_hex)
    
    # Apply gamma correction
    r_linear = if r <= 0.03928, do: r / 12.92, else: :math.pow((r + 0.055) / 1.055, 2.4)
    g_linear = if g <= 0.03928, do: g / 12.92, else: :math.pow((g + 0.055) / 1.055, 2.4)
    b_linear = if b <= 0.03928, do: b / 12.92, else: :math.pow((b + 0.055) / 1.055, 2.4)
    
    # Calculate luminance
    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end
  
  defp hex_to_rgb(hex) do
    hex = String.trim_leading(hex, "#")
    <<r::size(16), g::size(16), b::size(16)>> = Base.decode16!(hex, case: :mixed)
    {r / 255.0, g / 255.0, b / 255.0}
  end
end
```

### 4. Screen Reader Announcements

```elixir
defmodule Raxol.Core.Accessibility.Announcer do
  @moduledoc """
  Screen reader announcement system for terminal applications.
  """
  
  use GenServer
  
  @announcement_types [:polite, :assertive, :off]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    state = %{
      enabled: true,
      announcement_queue: :queue.new(),
      current_announcement: nil,
      settings: %{
        rate: :normal,
        voice: :default,
        volume: :normal
      }
    }
    
    {:ok, state}
  end
  
  @doc """
  Announce text to screen reader.
  
  ## Options
  - `:priority` - :polite (default), :assertive, or :off
  - `:interrupt` - whether to interrupt current announcement
  - `:delay` - delay before announcement in milliseconds
  """
  def announce(text, options \\ []) do
    GenServer.cast(__MODULE__, {:announce, text, options})
  end
  
  def set_enabled(enabled) when is_boolean(enabled) do
    GenServer.cast(__MODULE__, {:set_enabled, enabled})
  end
  
  def configure(settings) do
    GenServer.cast(__MODULE__, {:configure, settings})
  end
  
  def handle_cast({:announce, text, options}, state) do
    if state.enabled do
      priority = Keyword.get(options, :priority, :polite)
      interrupt = Keyword.get(options, :interrupt, false)
      delay = Keyword.get(options, :delay, 0)
      
      announcement = %{
        text: text,
        priority: priority,
        timestamp: System.monotonic_time(:millisecond),
        delay: delay
      }
      
      new_state = 
        if interrupt and priority == :assertive do
          # Clear queue and announce immediately
          %{state | 
            announcement_queue: :queue.from_list([announcement]),
            current_announcement: nil
          }
        else
          # Add to queue
          new_queue = :queue.in(announcement, state.announcement_queue)
          %{state | announcement_queue: new_queue}
        end
      
      # Process queue if not currently announcing
      new_state = 
        if new_state.current_announcement == nil do
          process_announcement_queue(new_state)
        else
          new_state
        end
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  def handle_cast({:set_enabled, enabled}, state) do
    new_state = %{state | enabled: enabled}
    
    # Clear queue if disabling
    new_state = 
      if not enabled do
        %{new_state | 
          announcement_queue: :queue.new(),
          current_announcement: nil
        }
      else
        new_state
      end
    
    {:noreply, new_state}
  end
  
  def handle_info(:process_next_announcement, state) do
    new_state = process_announcement_queue(state)
    {:noreply, new_state}
  end
  
  def handle_info({:announcement_complete, announcement}, state) do
    if state.current_announcement == announcement do
      new_state = %{state | current_announcement: nil}
      new_state = process_announcement_queue(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  defp process_announcement_queue(state) do
    case :queue.out(state.announcement_queue) do
      {{:value, announcement}, new_queue} ->
        # Send announcement to screen reader
        send_to_screen_reader(announcement, state.settings)
        
        # Schedule completion callback
        Process.send_after(
          self(),
          {:announcement_complete, announcement},
          calculate_announcement_duration(announcement, state.settings)
        )
        
        %{state |
          announcement_queue: new_queue,
          current_announcement: announcement
        }
        
      {:empty, _} ->
        state
    end
  end
  
  defp send_to_screen_reader(announcement, settings) do
    # Platform-specific screen reader integration
    case detect_screen_reader() do
      :nvda -> send_to_nvda(announcement, settings)
      :jaws -> send_to_jaws(announcement, settings)
      :voice_over -> send_to_voice_over(announcement, settings)
      :orca -> send_to_orca(announcement, settings)
      _ -> fallback_announcement(announcement, settings)
    end
  end
  
  defp detect_screen_reader do
    cond do
      System.get_env("NVDA_RUNNING") -> :nvda
      System.get_env("JAWS_RUNNING") -> :jaws
      :os.type() == {:unix, :darwin} -> :voice_over
      System.get_env("DISPLAY") && System.find_executable("orca") -> :orca
      true -> :generic
    end
  end
  
  defp send_to_nvda(announcement, _settings) do
    # Use NVDA's speech API
    text = announcement.text
    priority_flag = if announcement.priority == :assertive, do: "--interrupt", else: ""
    
    System.cmd("nvda-speak", [priority_flag, text], stderr_to_stdout: true)
  end
  
  defp send_to_voice_over(announcement, _settings) do
    # Use macOS VoiceOver
    applescript = """
    tell application "VoiceOver Utility"
        output "#{String.replace(announcement.text, "\"", "\\\"")}"
    end tell
    """
    
    System.cmd("osascript", ["-e", applescript])
  end
  
  defp fallback_announcement(announcement, _settings) do
    # Terminal bell + status output as fallback
    IO.write("\a")  # Bell character
    IO.puts("ANNOUNCE: #{announcement.text}")
  end
  
  defp calculate_announcement_duration(announcement, settings) do
    # Estimate based on text length and speech rate
    word_count = length(String.split(announcement.text))
    
    base_wpm = case settings.rate do
      :slow -> 120
      :normal -> 180
      :fast -> 250
      _ -> 180
    end
    
    # Add buffer time
    round((word_count / base_wpm) * 60 * 1000) + 500
  end
end
```

### 5. Focus Management

```elixir
defmodule MyApp.FocusManager do
  @moduledoc """
  Advanced focus management for complex UI interactions.
  """
  
  use GenServer
  
  defstruct [
    :focus_stack,
    :focus_trap,
    :auto_focus,
    :focus_visible,
    :skip_links
  ]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    state = %__MODULE__{
      focus_stack: [],
      focus_trap: nil,
      auto_focus: true,
      focus_visible: false,
      skip_links: []
    }
    
    {:ok, state}
  end
  
  # Focus trap for modal dialogs
  def trap_focus(container_id, opts \\ []) do
    GenServer.call(__MODULE__, {:trap_focus, container_id, opts})
  end
  
  def release_focus_trap do
    GenServer.call(__MODULE__, :release_focus_trap)
  end
  
  # Focus stack for nested components
  def push_focus(element_id) do
    GenServer.call(__MODULE__, {:push_focus, element_id})
  end
  
  def pop_focus do
    GenServer.call(__MODULE__, :pop_focus)
  end
  
  # Skip links for keyboard navigation
  def add_skip_link(target, label) do
    GenServer.cast(__MODULE__, {:add_skip_link, target, label})
  end
  
  def handle_call({:trap_focus, container_id, opts}, _from, state) do
    focus_trap = %{
      container: container_id,
      first_element: Keyword.get(opts, :first_element),
      last_element: Keyword.get(opts, :last_element),
      return_focus: get_current_focus()
    }
    
    # Focus first element in trap
    if focus_trap.first_element do
      focus_element(focus_trap.first_element)
    end
    
    new_state = %{state | focus_trap: focus_trap}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:release_focus_trap, _from, state) do
    if state.focus_trap do
      # Return focus to element that had focus before trap
      if state.focus_trap.return_focus do
        focus_element(state.focus_trap.return_focus)
      end
    end
    
    new_state = %{state | focus_trap: nil}
    {:reply, :ok, new_state}
  end
  
  def handle_call({:push_focus, element_id}, _from, state) do
    current_focus = get_current_focus()
    new_stack = [current_focus | state.focus_stack]
    
    focus_element(element_id)
    
    new_state = %{state | focus_stack: new_stack}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:pop_focus, _from, state) do
    case state.focus_stack do
      [previous_focus | rest] ->
        focus_element(previous_focus)
        new_state = %{state | focus_stack: rest}
        {:reply, {:ok, previous_focus}, new_state}
        
      [] ->
        {:reply, {:error, :empty_stack}, state}
    end
  end
  
  def handle_cast({:add_skip_link, target, label}, state) do
    skip_link = %{target: target, label: label}
    new_skip_links = [skip_link | state.skip_links]
    new_state = %{state | skip_links: new_skip_links}
    
    {:noreply, new_state}
  end
  
  # Focus management utilities
  defp get_current_focus do
    # Platform-specific implementation to get currently focused element
    case :os.type() do
      {:unix, :darwin} ->
        # macOS implementation
        get_macos_focus()
      {:win32, _} ->
        # Windows implementation  
        get_windows_focus()
      _ ->
        # Linux/generic implementation
        get_linux_focus()
    end
  end
  
  defp focus_element(element_id) do
    # Send focus command to terminal/UI
    Raxol.Terminal.send_command({:focus, element_id})
    
    # Announce focus change
    Raxol.Core.Accessibility.Announcer.announce(
      "Focused #{element_id}",
      priority: :polite
    )
  end
  
  # Skip link rendering helper
  def render_skip_links(assigns) do
    skip_links = get_skip_links()
    
    ~H"""
    <div class="skip-links" aria-label="Skip links">
      <%= for skip_link <- skip_links do %>
        <a 
          href={"##{skip_link.target}"}
          class="skip-link"
          tabindex="0"
        >
          Skip to <%= skip_link.label %>
        </a>
      <% end %>
    </div>
    """
  end
  
  defp get_skip_links do
    GenServer.call(__MODULE__, :get_skip_links)
  end
end
```

## Accessibility Testing

### Automated Accessibility Testing

```elixir
defmodule MyApp.AccessibilityTest do
  @moduledoc """
  Automated accessibility testing for Raxol components.
  """
  
  use ExUnit.Case
  
  describe "accessibility compliance" do
    test "components have proper ARIA labels" do
      html = render_component(MyApp.Components.Button, %{}, do: "Click me")
      
      # Check for required ARIA attributes
      assert html =~ ~r/aria-label|aria-labelledby/
      assert html =~ ~r/role="button"/
      
      # Verify button is focusable
      assert html =~ ~r/tabindex="0"/
    end
    
    test "color contrast meets WCAG AA standards" do
      theme = MyApp.AccessibilityTheme.get_theme(:default)
      
      contrast_ratio = MyApp.AccessibilityTheme.calculate_contrast_ratio(
        theme.foreground,
        theme.background
      )
      
      # WCAG AA requires 4.5:1 for normal text
      assert contrast_ratio >= 4.5
    end
    
    test "keyboard navigation works correctly" do
      {:ok, nav_state} = MyApp.KeyboardNavigation.new()
      
      # Add focusable elements
      nav_state = add_focusable_elements(nav_state, [
        %{id: "button1", type: :button, label: "First Button"},
        %{id: "input1", type: :input, label: "Text Input"},
        %{id: "button2", type: :button, label: "Second Button"}
      ])
      
      # Test tab navigation
      {:focus_moved, nav_state} = MyApp.KeyboardNavigation.handle_keypress(nav_state, :tab)
      assert nav_state.focus_index == 1
      
      {:focus_moved, nav_state} = MyApp.KeyboardNavigation.handle_keypress(nav_state, :tab)
      assert nav_state.focus_index == 2
      
      # Test wrap-around
      {:focus_moved, nav_state} = MyApp.KeyboardNavigation.handle_keypress(nav_state, :tab)
      assert nav_state.focus_index == 0
    end
    
    test "screen reader announcements work" do
      # Start announcer
      {:ok, _pid} = Raxol.Core.Accessibility.Announcer.start_link()
      
      # Test announcement
      Raxol.Core.Accessibility.Announcer.announce("Test announcement", priority: :polite)
      
      # Verify announcement was processed (in real test, this would check output)
      Process.sleep(100)
      
      # Test interrupting announcement
      Raxol.Core.Accessibility.Announcer.announce("Important message", 
        priority: :assertive, 
        interrupt: true
      )
    end
    
    test "focus management handles trapping correctly" do
      {:ok, _pid} = MyApp.FocusManager.start_link()
      
      # Create modal with focus trap
      :ok = MyApp.FocusManager.trap_focus("modal-dialog", 
        first_element: "modal-close-button"
      )
      
      # Verify focus is trapped within modal
      # (In real implementation, this would test actual focus behavior)
      
      # Release focus trap
      :ok = MyApp.FocusManager.release_focus_trap()
    end
  end
  
  describe "assistive technology compatibility" do
    test "works with screen readers" do
      # Test compatibility with major screen readers
      for screen_reader <- [:nvda, :jaws, :voice_over, :orca] do
        assert_screen_reader_compatible(screen_reader)
      end
    end
    
    test "supports high contrast mode" do
      high_contrast_theme = MyApp.AccessibilityTheme.get_theme(:high_contrast)
      
      # Verify high contrast ratios
      assert high_contrast_theme.contrast_ratio >= 21.0
      
      # Test component rendering with high contrast
      html = render_component_with_theme(MyApp.Components.Card, high_contrast_theme)
      
      assert html =~ "high-contrast"
    end
    
    test "supports reduced motion preferences" do
      # Test with reduced motion preference
      preferences = %{reduce_motion: true}
      
      component_html = render_component(MyApp.Components.AnimatedButton, %{
        preferences: preferences
      })
      
      # Should not include animation classes when reduced motion is preferred
      refute component_html =~ "animate-"
      refute component_html =~ "transition-"
    end
  end
  
  # Helper functions
  defp render_component_with_theme(component, theme) do
    assigns = %{theme: theme, content: "Test content"}
    render_component(component, assigns)
  end
  
  defp assert_screen_reader_compatible(screen_reader) do
    # Platform-specific screen reader compatibility tests
    case screen_reader do
      :nvda ->
        assert System.find_executable("nvda-speak") != nil
      :voice_over ->
        assert :os.type() == {:unix, :darwin}
      :orca ->
        assert System.find_executable("orca") != nil
      _ ->
        :ok
    end
  end
end
```

### Manual Testing Checklist

```elixir
defmodule MyApp.AccessibilityChecklist do
  @moduledoc """
  Manual accessibility testing checklist and utilities.
  """
  
  @keyboard_tests [
    "Can navigate entire application using only keyboard",
    "Tab order is logical and follows visual layout", 
    "All interactive elements are keyboard accessible",
    "Focus indicators are clearly visible",
    "Escape key works to close modals/dropdowns",
    "Arrow keys work for grid/list navigation",
    "Enter/Space activate buttons and links",
    "Keyboard shortcuts don't conflict with assistive technology"
  ]
  
  @screen_reader_tests [
    "All images have appropriate alt text",
    "Headings create logical document structure", 
    "Form fields have proper labels",
    "Error messages are announced",
    "Dynamic content changes are announced",
    "Tables have proper headers and captions",
    "Lists are properly marked up",
    "Links have descriptive text"
  ]
  
  @visual_tests [
    "Text has sufficient color contrast (4.5:1 minimum)",
    "UI works at 200% zoom level",
    "High contrast mode is supported",
    "Information isn't conveyed by color alone",
    "Focus indicators are visible and clear",
    "Text can be resized without horizontal scrolling",
    "Interface works without custom fonts",
    "Animation can be disabled/reduced"
  ]
  
  @motor_tests [
    "Large enough click targets (44px minimum)",
    "Sufficient spacing between interactive elements",
    "Drag and drop has keyboard alternatives",
    "Time limits can be extended/disabled",
    "No seizure-triggering flashing content",
    "Gestures have single-point alternatives",
    "Interface works with assistive pointing devices",
    "Voice control compatible"
  ]
  
  def run_checklist(category) do
    tests = get_tests_for_category(category)
    
    IO.puts("\n=== #{String.upcase(to_string(category))} ACCESSIBILITY TESTS ===\n")
    
    Enum.with_index(tests, 1)
    |> Enum.map(fn {test, index} ->
      IO.puts("#{index}. #{test}")
      
      case get_user_input("   Pass? (y/n/skip): ") do
        "y" -> {:pass, test}
        "n" -> 
          issue = get_user_input("   Describe issue: ")
          {:fail, test, issue}
        _ -> {:skip, test}
      end
    end)
    |> generate_report(category)
  end
  
  defp get_tests_for_category(category) do
    case category do
      :keyboard -> @keyboard_tests
      :screen_reader -> @screen_reader_tests  
      :visual -> @visual_tests
      :motor -> @motor_tests
    end
  end
  
  defp get_user_input(prompt) do
    IO.gets(prompt) |> String.trim() |> String.downcase()
  end
  
  defp generate_report(results, category) do
    passed = Enum.count(results, fn {status, _, _} -> status == :pass end)
    failed = Enum.count(results, fn {status, _, _} -> status == :fail end)  
    skipped = Enum.count(results, fn {status, _, _} -> status == :skip end)
    total = length(results)
    
    IO.puts("\n=== #{String.upcase(to_string(category))} TEST RESULTS ===")
    IO.puts("Passed: #{passed}/#{total}")
    IO.puts("Failed: #{failed}/#{total}")
    IO.puts("Skipped: #{skipped}/#{total}")
    
    if failed > 0 do
      IO.puts("\nISSUES TO FIX:")
      
      results
      |> Enum.filter(fn {status, _, _} -> status == :fail end)
      |> Enum.each(fn {:fail, test, issue} ->
        IO.puts("- #{test}: #{issue}")
      end)
    end
    
    pass_rate = passed / total * 100
    
    IO.puts("\nPass rate: #{:io_lib.format("~.1f", [pass_rate])}%")
    
    if pass_rate >= 80 do
      IO.puts("[OK] Good accessibility compliance")
    else
      IO.puts("[FAIL] Accessibility needs improvement")
    end
    
    %{
      category: category,
      passed: passed,
      failed: failed,
      skipped: skipped,
      total: total,
      pass_rate: pass_rate,
      issues: Enum.filter(results, fn {status, _, _} -> status == :fail end)
    }
  end
end
```

## Accessibility Configuration

### User Preferences System

```elixir
defmodule MyApp.AccessibilityPreferences do
  @moduledoc """
  User accessibility preferences management.
  """
  
  use GenServer
  
  @default_preferences %{
    # Visual preferences
    high_contrast: false,
    dark_mode: false,
    font_size: :normal,  # :small, :normal, :large, :extra_large
    reduce_motion: false,
    color_blindness_type: nil,  # :protanopia, :deuteranopia, :tritanopia
    
    # Audio preferences  
    screen_reader_enabled: false,
    speech_rate: :normal,  # :slow, :normal, :fast
    sound_effects: true,
    
    # Motor preferences
    sticky_keys: false,
    slow_keys: false,
    mouse_keys: false,
    click_assistance: false,
    
    # Cognitive preferences
    reading_guide: false,
    simplified_ui: false,
    extra_time: false,
    focus_enhancement: false
  }
  
  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via_tuple(user_id))
  end
  
  def init(user_id) do
    preferences = load_user_preferences(user_id) || @default_preferences
    {:ok, %{user_id: user_id, preferences: preferences}}
  end
  
  def get_preferences(user_id) do
    GenServer.call(via_tuple(user_id), :get_preferences)
  end
  
  def update_preference(user_id, key, value) do
    GenServer.call(via_tuple(user_id), {:update_preference, key, value})
  end
  
  def apply_preferences(user_id, component_assigns) do
    preferences = get_preferences(user_id)
    apply_preferences_to_assigns(component_assigns, preferences)
  end
  
  def handle_call(:get_preferences, _from, state) do
    {:reply, state.preferences, state}
  end
  
  def handle_call({:update_preference, key, value}, _from, state) do
    new_preferences = Map.put(state.preferences, key, value)
    
    # Save to persistent storage
    save_user_preferences(state.user_id, new_preferences)
    
    # Broadcast preference change
    broadcast_preference_change(state.user_id, key, value)
    
    new_state = %{state | preferences: new_preferences}
    {:reply, :ok, new_state}
  end
  
  defp apply_preferences_to_assigns(assigns, preferences) do
    assigns
    |> apply_visual_preferences(preferences)
    |> apply_motion_preferences(preferences)  
    |> apply_audio_preferences(preferences)
    |> apply_motor_preferences(preferences)
  end
  
  defp apply_visual_preferences(assigns, preferences) do
    assigns = 
      if preferences.high_contrast do
        Map.put(assigns, :theme, :high_contrast)
      else
        assigns
      end
    
    assigns = 
      if preferences.font_size != :normal do
        Map.put(assigns, :font_size_class, "font-size-#{preferences.font_size}")
      else
        assigns
      end
    
    assigns = 
      if preferences.color_blindness_type do
        Map.put(assigns, :color_blind_theme, preferences.color_blindness_type)
      else
        assigns
      end
    
    assigns
  end
  
  defp apply_motion_preferences(assigns, preferences) do
    if preferences.reduce_motion do
      Map.update(assigns, :class, "", fn class ->
        "#{class} reduce-motion"
      end)
    else
      assigns
    end
  end
  
  defp via_tuple(user_id) do
    {:via, Registry, {MyApp.AccessibilityRegistry, user_id}}
  end
  
  defp load_user_preferences(user_id) do
    # Load from database, file, or other persistent storage
    case MyApp.UserPreferences.get(user_id) do
      {:ok, preferences} -> preferences
      {:error, :not_found} -> nil
    end
  end
  
  defp save_user_preferences(user_id, preferences) do
    MyApp.UserPreferences.save(user_id, preferences)
  end
  
  defp broadcast_preference_change(user_id, key, value) do
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "user_preferences:#{user_id}",
      {:preference_changed, key, value}
    )
  end
end
```

## Platform-Specific Accessibility

### macOS Accessibility Integration

```elixir
defmodule MyApp.MacOSAccessibility do
  @moduledoc """
  macOS-specific accessibility features and VoiceOver integration.
  """
  
  def enable_accessibility_apis do
    # Check if accessibility permissions are granted
    case System.cmd("osascript", ["-e", "tell application \"System Events\" to get processes"]) do
      {_output, 0} ->
        {:ok, "Accessibility permissions granted"}
      {_output, _exit_code} ->
        {:error, "Accessibility permissions required. Please grant in System Preferences."}
    end
  end
  
  def send_to_voiceover(text, options \\ []) do
    priority = Keyword.get(options, :priority, :polite)
    
    applescript = case priority do
      :assertive ->
        """
        tell application "VoiceOver Utility"
            output "#{escape_applescript_string(text)}" with interrupt
        end tell
        """
      _ ->
        """
        tell application "VoiceOver Utility"  
            output "#{escape_applescript_string(text)}"
        end tell
        """
    end
    
    System.cmd("osascript", ["-e", applescript])
  end
  
  def get_voiceover_enabled do
    applescript = """
    tell application "System Preferences"
        reveal pane "com.apple.preference.universalaccess"
        delay 1
        tell application "System Events"
            tell process "System Preferences"
                get value of checkbox "Enable VoiceOver" of tab group 1 of window "Accessibility"
            end tell
        end tell
    end tell
    """
    
    case System.cmd("osascript", ["-e", applescript]) do
      {"true\n", 0} -> true
      _ -> false
    end
  end
  
  defp escape_applescript_string(text) do
    text
    |> String.replace("\"", "\\\"")
    |> String.replace("\\", "\\\\")
  end
end
```

### Windows Accessibility Integration

```elixir
defmodule MyApp.WindowsAccessibility do
  @moduledoc """
  Windows-specific accessibility features and screen reader integration.
  """
  
  def detect_screen_reader do
    cond do
      System.get_env("NVDA_RUNNING") -> :nvda
      System.get_env("JAWS_RUNNING") -> :jaws
      System.get_env("DRAGON_RUNNING") -> :dragon
      registry_check("NVDA") -> :nvda
      registry_check("JAWS") -> :jaws
      true -> nil
    end
  end
  
  def send_to_nvda(text, options \\ []) do
    interrupt = Keyword.get(options, :interrupt, false)
    
    args = if interrupt do
      ["--interrupt", text]
    else
      [text]
    end
    
    case System.cmd("nvda-speak", args) do
      {_output, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end
  
  def send_to_jaws(text, _options \\ []) do
    # JAWS integration via COM interface would go here
    # For now, use a simple approach
    temp_file = Path.join(System.tmp_dir!(), "jaws_speech.txt")
    File.write!(temp_file, text)
    
    System.cmd("jfw", ["/say", temp_file])
  end
  
  def get_high_contrast_enabled do
    # Check Windows high contrast mode
    case System.cmd("reg", ["query", "HKCU\\Control Panel\\Accessibility\\HighContrast", "/v", "Flags"]) do
      {output, 0} ->
        # Parse registry output to check if high contrast is enabled
        String.contains?(output, "0x1")
      _ ->
        false
    end
  end
  
  defp registry_check(program) do
    case System.cmd("tasklist", ["/FI", "IMAGENAME eq #{program}.exe"]) do
      {output, 0} -> String.contains?(output, "#{program}.exe")
      _ -> false
    end
  end
end
```

## Best Practices Summary

### Accessibility Development Checklist

- [ ] **Semantic Markup**
  - [ ] Use proper HTML elements (button, input, etc.)
  - [ ] Include ARIA labels and roles where needed
  - [ ] Maintain logical heading structure
  - [ ] Provide alternative text for images

- [ ] **Keyboard Accessibility**
  - [ ] All functionality available via keyboard
  - [ ] Logical tab order
  - [ ] Visible focus indicators
  - [ ] Keyboard shortcuts don't conflict

- [ ] **Screen Reader Support**
  - [ ] Meaningful announcements for state changes
  - [ ] Proper form field labeling
  - [ ] Error messages are announced
  - [ ] Dynamic content changes communicated

- [ ] **Visual Accessibility**
  - [ ] Sufficient color contrast (4.5:1 minimum)
  - [ ] Information not conveyed by color alone
  - [ ] Responsive to zoom levels up to 200%
  - [ ] Support for high contrast modes

- [ ] **Motor Accessibility**
  - [ ] Large enough touch targets (44px minimum)  
  - [ ] Sufficient spacing between elements
  - [ ] Alternative input methods supported
  - [ ] Timeout extensions available

- [ ] **Cognitive Accessibility**
  - [ ] Clear and consistent navigation
  - [ ] Simple language and instructions
  - [ ] Error prevention and clear error messages
  - [ ] Consistent UI patterns

## Further Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Accessible Rich Internet Applications (ARIA)](https://www.w3.org/WAI/ARIA/apg/)
- [Raxol Accessibility Testing](../../test/accessibility/)
- [Platform Accessibility APIs](./platform_accessibility.md)
- [Screen Reader Testing Guide](./screen_reader_testing.md)

---

*Accessibility is an ongoing commitment. This guide evolves with new standards, technologies, and user feedback. Contribute improvements and real-world accessibility patterns.*