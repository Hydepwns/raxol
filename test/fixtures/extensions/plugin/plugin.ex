defmodule Raxol.Terminal.Extension.Plugin do
  @moduledoc """
  A test plugin extension for the Raxol terminal emulator.
  """

  def get_plugin_info do
    %{
      name: "Test Plugin",
      version: "1.0.0",
      description: "A test plugin extension",
      author: "Test Author",
      license: "MIT",
      hooks: ["init", "cleanup", "update", "error"]
    }
  end

  def register_hook("init", callback) do
    # Register init hook
    {:ok, callback}
  end

  def register_hook("cleanup", callback) do
    # Register cleanup hook
    {:ok, callback}
  end

  def register_hook("update", callback) do
    # Register update hook
    {:ok, callback}
  end

  def register_hook("error", callback) do
    # Register error hook
    {:ok, callback}
  end

  def register_hook(hook, _callback) do
    {:error, :hook_not_found, "Hook '#{hook}' not found"}
  end

  def unregister_hook("init", _callback) do
    # Unregister init hook
    :ok
  end

  def unregister_hook("cleanup", _callback) do
    # Unregister cleanup hook
    :ok
  end

  def unregister_hook("update", _callback) do
    # Unregister update hook
    :ok
  end

  def unregister_hook("error", _callback) do
    # Unregister error hook
    :ok
  end

  def unregister_hook(hook, _callback) do
    {:error, :hook_not_found, "Hook '#{hook}' not found"}
  end

  def trigger_hook("init", args) do
    # Trigger init hook
    {:ok, args}
  end

  def trigger_hook("cleanup", args) do
    # Trigger cleanup hook
    {:ok, args}
  end

  def trigger_hook("update", args) do
    # Trigger update hook
    {:ok, args}
  end

  def trigger_hook("error", args) do
    # Trigger error hook
    {:ok, args}
  end

  def trigger_hook(hook, _args) do
    {:error, :hook_not_found, "Hook '#{hook}' not found"}
  end

  def get_plugin_state do
    # Return current plugin state
    {:ok,
     %{
       status: "idle",
       hooks: %{
         "init" => [],
         "cleanup" => [],
         "update" => [],
         "error" => []
       },
       last_error: nil
     }}
  end

  def update_plugin_config(config) do
    # Update plugin configuration
    {:ok, config}
  end
end
