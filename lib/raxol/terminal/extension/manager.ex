defmodule Raxol.Terminal.Extension.Manager do
  @moduledoc '''
  Manages terminal extensions with advanced features:
  - Extension loading and unloading
  - Extension lifecycle management
  - Extension API and event system
  - Extension configuration and state management
  '''

  @type extension :: %{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          author: String.t(),
          events: [String.t()],
          commands: [String.t()],
          config: map(),
          state: map()
        }

  @type event :: %{
          name: String.t(),
          handler: function(),
          priority: integer()
        }

  @type command :: %{
          name: String.t(),
          handler: function(),
          description: String.t(),
          usage: String.t()
        }

  @type t :: %__MODULE__{
          extensions: %{String.t() => extension()},
          events: %{String.t() => [event()]},
          commands: %{String.t() => command()},
          config: map(),
          metrics: %{
            extension_loads: integer(),
            extension_unloads: integer(),
            event_handlers: integer(),
            command_executions: integer(),
            config_updates: integer()
          }
        }

  defstruct [
    :extensions,
    :events,
    :commands,
    :config,
    :metrics
  ]

  @doc '''
  Creates a new extension manager with the given options.
  '''
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      extensions: %{},
      events: %{},
      commands: %{},
      config: Map.new(opts),
      metrics: %{
        extension_loads: 0,
        extension_unloads: 0,
        event_handlers: 0,
        command_executions: 0,
        config_updates: 0
      }
    }
  end

  @doc '''
  Loads an extension into the manager.
  '''
  @spec load_extension(t(), extension()) :: {:ok, t()} | {:error, term()}
  def load_extension(manager, extension) do
    with :ok <- validate_extension(extension),
         :ok <- check_extension_conflicts(manager, extension) do
      updated_extensions =
        Map.put(manager.extensions, extension.name, extension)

      updated_events = register_extension_events(manager.events, extension)

      updated_commands =
        register_extension_commands(manager.commands, extension)

      updated_manager = %{
        manager
        | extensions: updated_extensions,
          events: updated_events,
          commands: updated_commands,
          metrics: update_metrics(manager.metrics, :extension_loads)
      }

      {:ok, updated_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Unloads an extension from the manager.
  '''
  @spec unload_extension(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def unload_extension(manager, extension_name) do
    case Map.get(manager.extensions, extension_name) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        updated_extensions = Map.delete(manager.extensions, extension_name)
        updated_events = unregister_extension_events(manager.events, extension)

        updated_commands =
          unregister_extension_commands(manager.commands, extension)

        updated_manager = %{
          manager
          | extensions: updated_extensions,
            events: updated_events,
            commands: updated_commands,
            metrics: update_metrics(manager.metrics, :extension_unloads)
        }

        {:ok, updated_manager}
    end
  end

  @doc '''
  Emits an event to all registered handlers.
  '''
  @spec emit_event(t(), String.t(), [term()]) ::
          {:ok, [term()], t()} | {:error, term()}
  def emit_event(manager, event_name, args \\ []) do
    case Map.get(manager.events, event_name) do
      nil ->
        {:error, :event_not_found}

      events ->
        results =
          Enum.map(events, fn event ->
            apply_event_handler(event, args)
          end)

        updated_manager = %{
          manager
          | metrics: update_metrics(manager.metrics, :event_handlers)
        }

        {:ok, results, updated_manager}
    end
  end

  @doc '''
  Executes an extension command.
  '''
  @spec execute_command(t(), String.t(), [term()]) ::
          {:ok, term(), t()} | {:error, term()}
  def execute_command(manager, command_name, args \\ []) do
    case Map.get(manager.commands, command_name) do
      nil ->
        {:error, :command_not_found}

      command ->
        result = apply_command_handler(command, args)

        updated_manager = %{
          manager
          | metrics: update_metrics(manager.metrics, :command_executions)
        }

        {:ok, result, updated_manager}
    end
  end

  @doc '''
  Updates the configuration for an extension.
  '''
  @spec update_extension_config(t(), String.t(), map()) ::
          {:ok, t()} | {:error, term()}
  def update_extension_config(manager, extension_name, config) do
    case Map.get(manager.extensions, extension_name) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        updated_extension = %{
          extension
          | config: Map.merge(extension.config, config)
        }

        updated_extensions =
          Map.put(manager.extensions, extension_name, updated_extension)

        updated_manager = %{
          manager
          | extensions: updated_extensions,
            metrics: update_metrics(manager.metrics, :config_updates)
        }

        {:ok, updated_manager}
    end
  end

  @doc '''
  Gets the current extension metrics.
  '''
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  # Private helper functions

  defp validate_extension(extension) do
    required_fields = [
      :name,
      :version,
      :description,
      :author,
      :events,
      :commands,
      :config,
      :state
    ]

    if Enum.all?(required_fields, &Map.has_key?(extension, &1)) do
      :ok
    else
      {:error, :invalid_extension}
    end
  end

  defp check_extension_conflicts(manager, extension) do
    if Map.has_key?(manager.extensions, extension.name) do
      {:error, :extension_already_loaded}
    else
      :ok
    end
  end

  defp register_extension_events(events, extension) do
    Enum.reduce(extension.events, events, fn event_name, acc ->
      event = %{
        name: event_name,
        handler: &apply_event_handler/2,
        priority: 0
      }

      Map.update(acc, event_name, [event], &[event | &1])
    end)
  end

  defp unregister_extension_events(events, extension) do
    Enum.reduce(extension.events, events, fn event_name, acc ->
      Map.update(
        acc,
        event_name,
        [],
        &Enum.reject(&1, fn e -> e.name == extension.name end)
      )
    end)
  end

  defp register_extension_commands(commands, extension) do
    Enum.reduce(extension.commands, commands, fn command_name, acc ->
      command = %{
        name: command_name,
        handler: &apply_command_handler/2,
        description: "Command from #{extension.name}",
        usage: "#{command_name} [args]"
      }

      Map.put(acc, command_name, command)
    end)
  end

  defp unregister_extension_commands(commands, extension) do
    Enum.reduce(extension.commands, commands, fn command_name, acc ->
      Map.delete(acc, command_name)
    end)
  end

  defp apply_event_handler(event, args) do
    try do
      event.handler.(args)
    rescue
      e -> {:error, {:event_handler_error, e}}
    end
  end

  defp apply_command_handler(command, args) do
    try do
      command.handler.(args)
    rescue
      e -> {:error, {:command_handler_error, e}}
    end
  end

  defp update_metrics(metrics, :extension_loads) do
    update_in(metrics.extension_loads, &(&1 + 1))
  end

  defp update_metrics(metrics, :extension_unloads) do
    update_in(metrics.extension_unloads, &(&1 + 1))
  end

  defp update_metrics(metrics, :event_handlers) do
    update_in(metrics.event_handlers, &(&1 + 1))
  end

  defp update_metrics(metrics, :command_executions) do
    update_in(metrics.command_executions, &(&1 + 1))
  end

  defp update_metrics(metrics, :config_updates) do
    update_in(metrics.config_updates, &(&1 + 1))
  end
end
