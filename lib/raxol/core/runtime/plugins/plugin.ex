defmodule Raxol.Core.Runtime.Plugins.Plugin do
  @moduledoc """
  Defines the behaviour for Raxol plugins.

  Plugins must implement this behaviour to be loaded and managed by the PluginManager.
  """

  @type config :: map()
  @type state :: map()
  @type event :: Raxol.Core.Runtime.Events.Event.t() | term() # Adjust based on actual Event struct
  @type command :: atom() | tuple()

  @doc """
  Called when the plugin is first initialized.

  Should return `{:ok, initial_state}` or `{:error, reason}`.
  The `initial_state` will be managed by the PluginManager.
  """
  @callback init(config :: config()) :: {:ok, state()} | {:error, any()}

  @doc """
  Called when the plugin is terminated (e.g., during shutdown or unload).

  Allows the plugin to perform cleanup. The return value is ignored.
  """
  @callback terminate(reason :: any(), state :: state()) :: any()

  @doc """
  Called when the plugin is enabled after being disabled.

  Should return `{:ok, new_state}` or `{:error, reason}`.
  """
  @callback enable(state :: state()) :: {:ok, state()} | {:error, any()}

  @doc """
  Called when the plugin is disabled.

  Should return `{:ok, new_state}` or `{:error, reason}`.
  """
  @callback disable(state :: state()) :: {:ok, state()} | {:error, any()}

  @doc """
  Optional callback to filter or react to system events before they reach the application.

  Return `{:ok, event}` to pass the event through (potentially modified).
  Return `:halt` to stop the event from propagating further.
  Return any other value to indicate an error.
  """
  @callback filter_event(event :: event(), state :: state()) :: {:ok, event()} | :halt | any()

  @doc """
  Optional callback to handle commands delegated by the PluginManager.

  Should return `{:ok, new_state, result}` or `{:error, reason, new_state}`.
  The `result` can be sent back to the original command requester if needed.
  """
  @callback handle_command(command :: command(), args :: list(), state :: state()) ::
              {:ok, state(), any()} | {:error, any(), state()}

  @doc """
  Optional callback to declare commands provided by the plugin.

  Should return a list of `{namespace, command_name, function_name, arity}` tuples.
  Example: `[{:my_plugin, :do_something, :handle_do_something_command, 2}]`
  These will be registered in the CommandRegistry.
  """
  @callback get_commands() :: [{atom(), atom(), atom(), non_neg_integer()}]
end
