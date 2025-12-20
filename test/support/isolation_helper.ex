defmodule Raxol.Test.IsolationHelper do
  @moduledoc """
  Provides test isolation by resetting global state between tests.

  This module helps ensure that tests don't interfere with each other by
  resetting shared global state (AccessibilityServer, EventManager, UserPreferences)
  to their default states.

  ## Usage

  Call `reset_global_state/0` in your test setup:

      setup do
        Raxol.Test.IsolationHelper.reset_global_state()
        :ok
      end

  Or use `Raxol.Test.IsolatedCase` which does this automatically.
  """

  @doc """
  Resets all global state to ensure test isolation.
  """
  def reset_global_state do
    reset_accessibility_server()
    reset_event_manager()
    reset_user_preferences()
    reset_theme_state()
    reset_ets_caches()
    :ok
  end

  defp reset_accessibility_server do
    case Process.whereis(Raxol.Core.Accessibility.AccessibilityServer) do
      nil -> :ok
      _pid -> Raxol.Core.Accessibility.AccessibilityServer.reset()
    end
  end

  defp reset_event_manager do
    case Process.whereis(Raxol.Core.Events.EventManager) do
      nil -> :ok
      _pid -> Raxol.Core.Events.EventManager.clear_handlers()
    end
  end

  defp reset_user_preferences do
    case Process.whereis(Raxol.Core.UserPreferences) do
      nil -> :ok
      _pid -> Raxol.Core.UserPreferences.reset_to_defaults_for_test!()
    end
  end

  defp reset_theme_state do
    # Clear accumulated themes from Application env
    Application.delete_env(:raxol, :themes)
    Application.delete_env(:raxol, :current_theme)
  end

  defp reset_ets_caches do
    # Clear style/theme caches if ETSCacheManager is running
    case Process.whereis(Raxol.Performance.ETSCacheManager) do
      nil ->
        :ok

      _pid ->
        Raxol.Performance.ETSCacheManager.clear_cache(:style)
        Raxol.Performance.ETSCacheManager.clear_cache(:layout)
        Raxol.Performance.ETSCacheManager.clear_cache(:theme_cache)
    end
  end
end
