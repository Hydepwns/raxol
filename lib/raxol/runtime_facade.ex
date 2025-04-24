defmodule Raxol.Runtime do
  @moduledoc """
  Manages the core runtime processes for a Raxol application.
  Starts and supervises the main components like EventLoop, ComponentManager, etc.

  @deprecated "Use Raxol.Core.Runtime modules instead. See migration guide for details."
  """

  require Logger

  alias Raxol.Core.Runtime.Lifecycle
  alias Raxol.Core.Runtime.Supervisor

  @doc """
  Starts a Raxol application with the given module and options.

  ## Options
    * `:title` - The window title (default: "Raxol Application")
    * `:fps` - Frames per second (default: 60)
    * `:quit_keys` - List of keys that will quit the application (default: [:ctrl_c])
    * `:debug` - Enable debug mode (default: false)

  @deprecated "Use Raxol.Core.Runtime.Lifecycle.start_application/2 instead"
  """
  def run(app_module, options \\ []) do
    IO.warn(
      "Raxol.Runtime.run/2 is deprecated. Use Raxol.Core.Runtime.Lifecycle.start_application/2 instead.",
      Macro.Env.stacktrace(__ENV__)
    )

    Lifecycle.start_application(app_module, options)
  end

  @doc """
  Sends a message to the running application.

  Returns `:ok` if the message was sent successfully,
  `{:error, :app_not_running}` if the application is not running.

  @deprecated "Use Raxol.Core.Runtime.Command module for messaging instead"
  """
  def send_msg(msg, app_name \\ :default) do
    IO.warn(
      "Raxol.Runtime.send_msg/2 is deprecated. Use Raxol.Core.Runtime.Command module for messaging instead.",
      Macro.Env.stacktrace(__ENV__)
    )

    case Lifecycle.lookup_app(app_name) do
      {:ok, pid} ->
        GenServer.cast(pid, {:msg, msg})
        :ok

      :error ->
        {:error, :app_not_running}
    end
  end

  @doc """
  Stops the running application.

  Returns `:ok` if the application was stopped successfully,
  `{:error, :app_not_running}` if the application is not running.

  @deprecated "Use Raxol.Core.Runtime.Lifecycle.stop_application/1 instead"
  """
  def stop(app_name \\ :default) do
    IO.warn(
      "Raxol.Runtime.stop/1 is deprecated. Use Raxol.Core.Runtime.Lifecycle.stop_application/1 instead.",
      Macro.Env.stacktrace(__ENV__)
    )

    Lifecycle.stop_application(app_name)
  end

  # Server callbacks and implementation - for backward compatibility with existing code

  # These are maintained to support existing applications, but delegate to the new implementation

  def start_link(opts) when is_list(opts) do
    IO.warn(
      "Raxol.Runtime.start_link/1 is deprecated. Use Raxol.Core.Runtime.Application and Lifecycle modules instead.",
      Macro.Env.stacktrace(__ENV__)
    )

    Logger.debug("[Runtime.start_link] Starting runtime via facade...")
    app_module = Keyword.fetch!(opts, :app_module)
    app_name = get_app_name(app_module)

    # Use the new implementation while maintaining backward compatibility
    GenServer.start_link(Raxol.Core.Runtime.Application, {app_module, opts}, name: via_tuple(app_name))
  end

  # Private helper functions

  defp get_app_name(app_module) do
    cond do
      function_exported?(app_module, :app_name, 0) ->
        app_module.app_name()

      true ->
        :default
    end
  end

  defp via_tuple(app_name) do
    {:via, Registry, {Raxol.Terminal.Registry, app_name}}
  end
end
