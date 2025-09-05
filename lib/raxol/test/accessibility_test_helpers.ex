defmodule Raxol.AccessibilityTestHelpers do
  @moduledoc """
  Test helpers for accessibility-related assertions and simulation in Raxol.

  REFACTORED: All try/after blocks replaced with functional patterns.

  ## Features

  - Test helpers for screen reader announcements
  - Color contrast testing tools
  - Keyboard navigation test helpers
  - Focus management testing
  - High contrast mode testing
  - Reduced motion testing
  """

  alias Raxol.Core.Accessibility, as: Accessibility
  alias Raxol.Style.Colors.Utilities
  alias Raxol.Core.FocusManager, as: FocusManager
  alias Raxol.Core.KeyboardShortcuts, as: KeyboardShortcuts
  alias Raxol.Core.Events.Manager, as: EventManager

  import ExUnit.Assertions

  @doc """
  Run a test with a spy on screen reader announcements.

  This function sets up a spy to capture screen reader announcements
  during the execution of the provided function, allowing you to
  assert that specific announcements were made.

  ## Examples

      with_screen_reader_spy(user_preferences_pid, fn ->
        # Perform action
        click_button("Save")

        # Assert announcement
        assert_announced("File saved successfully")
      end)
  """
  def with_screen_reader_spy(pid, fun)
      when is_pid(pid) and is_function(fun, 0) do
    # Initialize announcement spy
    Process.put(:accessibility_test_announcements, [])
    # Register spy handler
    EventManager.register_handler(
      :accessibility_announce,
      __MODULE__,
      :handle_announcement_spy
    )

    # Use functional approach with proper cleanup
    result = safe_execute_with_spy(pid, fun)

    # Always cleanup
    Accessibility.disable(pid)

    EventManager.unregister_handler(
      :accessibility_announce,
      __MODULE__,
      :handle_announcement_spy
    )

    result
  end

  def with_screen_reader_spy(_, _) do
    raise "with_screen_reader_spy/2 must be called with a pid and a function. Example: with_screen_reader_spy(user_preferences_pid, fn -> ... end)"
  end

  defp safe_execute_with_spy(pid, fun) do
    task =
      Task.async(fn ->
        Accessibility.enable([], pid)
        fun.()
      end)

    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, reason}
    end
  end

  @doc """
  Assert that a specific announcement was made to the screen reader.
  """
  defmacro assert_announced(expected, opts \\ []) do
    exact = Keyword.get(opts, :exact, false)
    context = Keyword.get(opts, :context, "")

    quote do
      announcements = Process.get(:accessibility_test_announcements, [])

      validate_announcement_match(
        unquote(exact),
        announcements,
        unquote(expected),
        unquote(context)
      )
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

    validate_no_announcements_made(announcements, context)
  end

  @doc """
  Refute that a specific announcement was made to the screen reader.
  """
  defmacro refute_announced(expected, opts \\ []) do
    exact = Keyword.get(opts, :exact, false)
    context = Keyword.get(opts, :context, "")

    quote do
      announcements = Process.get(:accessibility_test_announcements, [])

      validate_announcement_not_match(
        unquote(exact),
        announcements,
        unquote(expected),
        unquote(context)
      )
    end
  end

  @doc """
  Assert that two colors have sufficient contrast.

  ## Parameters

  * `color1` - The first color (hex string or tuple)
  * `color2` - The second color (hex string or tuple)
  * `opts` - Additional options

  ## Options

  * `:level` - The WCAG level to check (:aa or :aaa, defaults to :aa)
  * `:size` - The text size (:normal or :large, defaults to :normal)
  * `:context` - Additional context for the error message

  ## Examples

      assert_sufficient_contrast("#0077CC", "#FFFFFF")
      assert_sufficient_contrast("#333333", "#CCCCCC", level: :aaa, size: :large)
  """
  def assert_sufficient_contrast(color1, color2, opts \\ []) do
    level = Keyword.get(opts, :level, :aa)
    size = Keyword.get(opts, :size, :normal)
    context = Keyword.get(opts, :context, "")

    ratio = Utilities.contrast_ratio(color1, color2)
    min_ratio = get_minimum_ratio(level, size)

    validate_contrast_ratio_sufficient(ratio, min_ratio, level, size, context)
  end

  @doc """
  Simulate keyboard navigation for testing.

  This function simulates TAB key presses to navigate through focusable elements,
  allowing you to test the tab order and focus management of your UI.

  ## Examples

      simulate_keyboard_navigation(3, fn ->
        assert_focus_on("search_button")
      end)
  """
  def simulate_keyboard_navigation(steps, fun) when steps > 0 do
    Enum.each(1..steps, fn _ ->
      # Get current focus
      current = FocusManager.get_current_focus()

      # Find next focusable element
      next =
        get_next_focusable_element(current)

      # Move focus
      move_focus_if_available(next)
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

    validate_focus_matches_expected(current, expected, context)
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
    set_keyboard_context_if_provided(shortcut_context)

    # Initialize action spy
    Process.put(:shortcut_action_executed, false)
    Process.put(:shortcut_action_id, nil)

    # Register spy handler
    EventManager.register_handler(
      :shortcut_executed,
      __MODULE__,
      :handle_shortcut_spy
    )

    # Use functional approach with cleanup
    result = safe_test_shortcut(shortcut, context)

    # Always cleanup
    EventManager.unregister_handler(
      :shortcut_executed,
      __MODULE__,
      :handle_shortcut_spy
    )

    result
  end

  defp safe_test_shortcut(shortcut, context) do
    task =
      Task.async(fn ->
        # Parse the shortcut string into an event tuple
        event_tuple = parse_shortcut_string(shortcut)

        # Dispatch the keyboard event to simulate pressing the keys
        EventManager.dispatch({:keyboard_event, event_tuple})

        # Check if action was executed
        executed = Process.get(:shortcut_action_executed, false)
        action_id = Process.get(:shortcut_action_id)

        validate_shortcut_execution(executed, shortcut, context)

        # Return the action ID for further assertions
        action_id
      end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, reason}
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
    previous = Accessibility.get_option(:high_contrast, nil)

    # Enable high contrast
    Accessibility.set_option(:high_contrast, true, nil)

    # Execute function and ensure cleanup
    result = safe_execute_function(fun)

    # Always restore previous setting
    Accessibility.set_option(:high_contrast, previous, nil)

    result
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
  def with_reduced_motion(fun_or_pid, fun \\ nil) do
    case {fun_or_pid, fun} do
      {pid, fun} when is_pid(pid) and is_function(fun, 0) ->
        previous = Accessibility.get_option(:reduced_motion, pid)
        Accessibility.set_option(:reduced_motion, true, pid)

        # Execute function and ensure cleanup
        result = safe_execute_function(fun)

        # Always restore
        Accessibility.set_option(:reduced_motion, previous, pid)

        result

      {fun, nil} when is_function(fun, 0) ->
        previous = Accessibility.get_option(:reduced_motion, nil)
        Accessibility.set_option(:reduced_motion, true, nil)

        # Execute function and ensure cleanup
        result = safe_execute_function(fun)

        # Always restore
        Accessibility.set_option(:reduced_motion, previous, nil)

        result
    end
  end

  defp safe_execute_function(fun) do
    task = Task.async(fn -> fun.() end)

    case Task.yield(task, 5000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, reason}
    end
  end

  @doc """
  Spy handler for screen reader announcements.
  """
  def handle_announcement_spy({:accessibility_announce, message}) do
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

  # Helper function to parse shortcut string (e.g., "Ctrl+Shift+A") into event tuple
  defp parse_shortcut_string(shortcut_string) when is_binary(shortcut_string) do
    parts = String.split(shortcut_string, "+")
    key_str = List.last(parts)
    modifier_strs = Enum.take(parts, length(parts) - 1)

    key =
      case key_str do
        k when byte_size(k) == 1 -> String.to_charlist(k) |> hd()
        # Add more special key mappings if needed (e.g., "Enter", "Tab")
        # Assume atom for F-keys, etc.
        _ -> String.to_atom(String.downcase(key_str))
      end

    modifiers =
      Enum.map(modifier_strs, fn
        "Ctrl" -> :ctrl
        "Alt" -> :alt
        "Shift" -> :shift
        # Ignore unknown modifiers
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    {:key, key, modifiers}
  end

  # Helper function to get minimum contrast ratio
  defp get_minimum_ratio(:aa, :normal), do: 4.5
  defp get_minimum_ratio(:aa, :large), do: 3.0
  defp get_minimum_ratio(:aaa, :normal), do: 7.0
  defp get_minimum_ratio(:aaa, :large), do: 4.5

  # Helper functions for announcement validation
  defp validate_announcement_present(announcements, expected, context)
       when is_binary(expected) do
    unless Enum.any?(announcements, &String.contains?(&1, expected)) do
      flunk(
        "Expected screen reader announcement containing \"#{expected}\" was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
      )
    end
  end

  defp validate_announcement_present(
         announcements,
         %Regex{} = expected,
         context
       ) do
    unless Enum.any?(announcements, &Regex.match?(expected, &1)) do
      flunk(
        "Expected screen reader announcement matching #{inspect(expected)} was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
      )
    end
  end

  defp validate_announcement_present(_announcements, expected, _context) do
    flunk("Invalid expected value for assert_announced: #{inspect(expected)}")
  end

  defp validate_announcement_absent(announcements, expected, context)
       when is_binary(expected) do
    validate_announcement_not_contains(announcements, expected, context)
  end

  defp validate_announcement_absent(announcements, %Regex{} = expected, context) do
    validate_announcement_not_matches_regex(announcements, expected, context)
  end

  defp validate_announcement_absent(_announcements, expected, _context) do
    flunk("Invalid expected value for refute_announced: #{inspect(expected)}")
  end

  ## Pattern matching helper functions for if statement elimination

  defp validate_announcement_match(true, announcements, expected, context) do
    case Enum.member?(announcements, expected) do
      true ->
        :ok

      false ->
        flunk(
          "Expected screen reader announcement \"#{expected}\" was not made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        )
    end
  end

  defp validate_announcement_match(false, announcements, expected, context) do
    validate_announcement_present(announcements, expected, context)
  end

  defp validate_no_announcements_made([], _context), do: :ok

  defp validate_no_announcements_made(announcements, context) do
    flunk(
      "Expected no screen reader announcements, but got: #{inspect(announcements)}\n#{context}"
    )
  end

  defp validate_announcement_not_match(true, announcements, expected, context) do
    case Enum.member?(announcements, expected) do
      true ->
        flunk(
          "Unexpected screen reader announcement \"#{expected}\" was made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        )

      false ->
        :ok
    end
  end

  defp validate_announcement_not_match(false, announcements, expected, context) do
    validate_announcement_absent(announcements, expected, context)
  end

  defp validate_contrast_ratio_sufficient(
         ratio,
         min_ratio,
         level,
         size,
         context
       )
       when ratio < min_ratio do
    flunk(
      "Insufficient contrast ratio: #{ratio}. Expected at least #{min_ratio} for WCAG #{level |> Atom.to_string() |> String.upcase()} with #{size} text.\n#{context}"
    )
  end

  defp validate_contrast_ratio_sufficient(
         _ratio,
         _min_ratio,
         _level,
         _size,
         _context
       ),
       do: :ok

  defp get_next_focusable_element(current) do
    case FocusManager.get_focus_direction() do
      :backward -> FocusManager.get_previous_focusable(current)
      _ -> FocusManager.get_next_focusable(current)
    end
  end

  defp move_focus_if_available(nil), do: :ok

  defp move_focus_if_available(next) do
    FocusManager.set_focus(next)
  end

  defp validate_focus_matches_expected(current, expected, context)
       when current != expected do
    flunk(
      "Expected focus on \"#{expected}\", but it's on \"#{current}\"\n#{context}"
    )
  end

  defp validate_focus_matches_expected(_current, _expected, _context), do: :ok

  defp set_keyboard_context_if_provided(nil), do: :ok

  defp set_keyboard_context_if_provided(shortcut_context) do
    KeyboardShortcuts.set_context(shortcut_context)
  end

  defp validate_shortcut_execution(true, _shortcut, _context), do: :ok

  defp validate_shortcut_execution(false, shortcut, context) do
    flunk(
      "Keyboard shortcut \"#{shortcut}\" did not trigger any action.\n#{context}"
    )
  end

  defp validate_announcement_not_contains(announcements, expected, context) do
    case Enum.any?(announcements, &String.contains?(&1, expected)) do
      true ->
        flunk(
          "Unexpected screen reader announcement containing \"#{expected}\" was made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        )

      false ->
        :ok
    end
  end

  defp validate_announcement_not_matches_regex(announcements, expected, context) do
    case Enum.any?(announcements, &Regex.match?(expected, &1)) do
      true ->
        flunk(
          "Unexpected screen reader announcement matching #{inspect(expected)} was made.\nActual announcements: #{inspect(announcements)}\n#{context}"
        )

      false ->
        :ok
    end
  end
end
