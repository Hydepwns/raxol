defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc """
  Mock implementation of the accessibility module for testing.
  """

  @behaviour Raxol.Core.Accessibility.Behaviour

  @impl Raxol.Core.Accessibility.Behaviour
  def enable(_options, _user_preferences_pid_or_name) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def disable(_user_preferences_pid_or_name) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def announce(_message, _level) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def set_large_text(_enabled, _user_preferences_pid_or_name) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_focus_history do
    []
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def enabled? do
    true
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_component_hint(_component_id, _hint_level) do
    "mock hint"
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_option(_key, default) do
    default
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def set_option(_key, _value) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def register_element_metadata(_element_id, _metadata) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_element_metadata(_element_id) do
    nil
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def register_component_style(_component_type, _style) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_component_style(_component_type) do
    %{}
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def unregister_element_metadata(_element_id) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def unregister_component_style(_component_type) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def announce(_message, _opts, _user_preferences_pid_or_name) do
    :ok
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def get_next_announcement(_user_preferences_pid_or_name) do
    nil
  end

  @impl Raxol.Core.Accessibility.Behaviour
  def clear_announcements do
    :ok
  end
end
