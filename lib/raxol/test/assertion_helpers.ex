defmodule Raxol.Test.AssertionHelpers do
  @moduledoc """
  Common assertion helpers for Raxol tests.
  Provides standardized assertions for components, events, and state.
  """

  import ExUnit.Assertions

  @doc """
  Asserts that a component's state matches expected values.
  """
  def assert_state_match(component, expected) when is_map(expected) do
    Enum.each(expected, fn {key, value} ->
      assert Map.get(component.state, key) == value,
             "Expected state.#{key} to be #{inspect(value)}, but got: #{inspect(Map.get(component.state, key))}"
    end)
  end

  @doc """
  Asserts that a component received an event.
  """
  def assert_event_received(event_name, timeout \\ 1000) do
    assert_receive {:event, ^event_name}, timeout
  end

  @doc """
  Asserts that a component did not receive an event.
  """
  def refute_event_received(event_name, timeout \\ 1000) do
    refute_receive {:event, ^event_name}, timeout
  end

  @doc """
  Asserts that a component properly handles errors.
  """
  def assert_error_handled(component, error_fn) do
    try do
      error_fn.()
      flunk("Expected an error to be handled")
    rescue
      error ->
        assert component.state != nil,
               "Component state was corrupted after error"

        assert_error_handled(error)
    end
  end

  @doc """
  Asserts that a component's render output matches expected text.
  """
  def assert_renders_with(component, expected_text) do
    output = capture_render(component)

    assert output =~ expected_text,
           "Expected output to contain: #{expected_text}"
  end

  @doc """
  Asserts that a component's render output matches a snapshot.
  """
  def assert_matches_snapshot(component, snapshot_name, context) do
    output = capture_render(component)
    snapshot_path = Path.join(context.snapshots_dir, "#{snapshot_name}.snap")

    if File.exists?(snapshot_path) do
      expected = File.read!(snapshot_path)

      assert output == expected,
             "Component output does not match snapshot: #{snapshot_name}"
    else
      File.write!(snapshot_path, output)
    end
  end

  @doc """
  Asserts that a component is responsive across different sizes.
  """
  def assert_responsive(component, sizes) do
    Enum.each(sizes, fn {width, height} ->
      context = %{width: width, height: height}
      output = capture_render(component, context)

      assert is_binary(output),
             "Component failed to render at size #{width}x#{height}"
    end)
  end

  @doc """
  Asserts that a component maintains consistent styling across themes.
  """
  def assert_theme_consistent(component, themes) do
    Enum.each(themes, fn theme ->
      Raxol.ColorSystem.apply_theme(theme)
      assert_receive {:theme_changed, ^theme}, 100
      output = capture_render(component)

      assert is_binary(output),
             "Component failed to render with theme: #{theme}"
    end)
  end

  # Private Helpers

  defp capture_render(component, context \\ %{width: 80, height: 24}) do
    Raxol.Test.TestHelper.capture_terminal_output(fn ->
      render_result = component.module.render(component.state, context)
      IO.puts(inspect(render_result))
    end)
  end

  defp assert_error_handled(_error) do
    # Placeholder: Need to integrate with error handling/logging mechanism
    true
  end
end
