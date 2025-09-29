defmodule Raxol.Plugins.Testing.Helpers do
  @moduledoc """
  Helper functions for plugin testing
  """

  @doc """
  Creates a test configuration with default values
  """
  def create_test_config(overrides \\ %{}) do
    defaults = %{
      enabled: true,
      hotkey: nil,
      panel_position: :bottom,
      panel_height: 10,
      debug: false
    }

    Map.merge(defaults, overrides)
  end

  @doc """
  Creates a mock plugin state
  """
  def create_mock_state(overrides \\ %{}) do
    defaults = %{
      terminal: nil,
      config: %{},
      panel_visible: false,
      content_cache: nil,
      last_update: nil
    }

    Map.merge(defaults, overrides)
  end

  @doc """
  Simulates terminal resize
  """
  def resize_terminal(terminal, width, height) do
    %{terminal | width: width, height: height}
  end

  @doc """
  Simulates plugin lifecycle events
  """
  def trigger_lifecycle_event(plugin_pid, event) when is_pid(plugin_pid) do
    GenServer.cast(plugin_pid, {:lifecycle, event})
  end

  @doc """
  Waits for async operations to complete
  """
  def wait_for_async(timeout \\ 100) do
    Process.sleep(timeout)
  end

  @doc """
  Captures plugin output
  """
  def capture_plugin_output(plugin_pid, fun) do
    :erlang.trace(plugin_pid, true, [:call])

    result = fun.()

    :erlang.trace(plugin_pid, false, [:call])

    result
  end

  @doc """
  Creates a mock git repository state
  """
  def create_mock_git_state do
    %{
      branch: "main",
      status: :clean,
      staged_files: [],
      unstaged_files: [],
      untracked_files: [],
      commits_ahead: 0,
      commits_behind: 0,
      last_commit: %{
        hash: "abc123",
        author: "Test User",
        message: "Initial commit",
        timestamp: DateTime.utc_now()
      }
    }
  end
end
