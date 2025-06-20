defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc """
  Mock implementation of the accessibility module for testing.
  """

  @behaviour Raxol.Core.Accessibility.Behaviour

  @impl true
  def announce(_message, _level) do
    :ok
  end

  @impl true
  def set_large_text(_enabled, _user_preferences_pid_or_name) do
    :ok
  end

  @impl true
  def get_focus_history do
    []
  end

  @impl true
  def enabled? do
    true
  end

  @impl true
  def get_component_hint(_component_id, _hint_level) do
    "mock hint"
  end

  @impl true
  def get_option(_key, default) do
    default
  end

  @impl true
  def set_option(_key, _value) do
    :ok
  end
end
