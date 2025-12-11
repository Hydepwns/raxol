defmodule Raxol.Terminal.Extension.ExtensionManager do
  @moduledoc """
  Manages terminal extensions, including loading, unloading, and executing extension commands.
  """

  @type extension :: %{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          config: map(),
          commands: map(),
          events: map(),
          state: any()
        }

  @type t :: %__MODULE__{
          extensions: map(),
          event_handlers: map(),
          command_registry: map(),
          metrics: map(),
          config: map()
        }

  defstruct extensions: %{},
            event_handlers: %{},
            command_registry: %{},
            events: %{},
            commands: %{},
            metrics: %{
              extensions_loaded: 0,
              extension_loads: 0,
              extension_unloads: 0,
              events_emitted: 0,
              event_handlers: 0,
              command_executions: 0,
              commands_executed: 0,
              config_updates: 0
            },
            config: %{}

  @doc """
  Creates a new extension manager.
  """
  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @spec new(keyword() | map()) :: t()
  def new(opts) when is_list(opts) do
    %__MODULE__{
      config: Enum.into(opts, %{})
    }
  end

  def new(opts) when is_map(opts) do
    %__MODULE__{
      config: opts
    }
  end

  @doc """
  Loads an extension into the manager.
  """
  @spec load_extension(t(), map()) :: {:ok, t()} | {:error, any()}
  def load_extension(manager, extension) when is_map(extension) do
    # Use name as the identifier
    ext_name = Map.get(extension, :name) || Map.get(extension, "name")

    cond do
      ext_name == nil ->
        {:error, :invalid_extension}

      # Check for duplicate by name
      Enum.any?(manager.extensions, fn {_id, ext} ->
        (Map.get(ext, :name) || Map.get(ext, "name")) == ext_name
      end) ->
        {:error, :extension_already_loaded}

      true ->
        # Validate extension structure
        case validate_extension(extension) do
          :ok ->
            # Generate unique ID if not provided
            ext_id =
              Map.get(extension, :id) || Map.get(extension, "id") ||
                generate_extension_id(ext_name)

            # Register extension
            updated_manager = %{
              manager
              | extensions: Map.put(manager.extensions, ext_id, extension),
                metrics:
                  manager.metrics
                  |> Map.update(:extensions_loaded, 1, &(&1 + 1))
                  |> Map.update(:extension_loads, 1, &(&1 + 1))
            }

            # Register commands
            commands =
              Map.get(extension, :commands) || Map.get(extension, "commands") ||
                []

            updated_manager =
              register_extension_commands(updated_manager, ext_id, commands)

            # Register event handlers
            events =
              Map.get(extension, :events) || Map.get(extension, "events") || []

            updated_manager =
              register_extension_events(updated_manager, ext_id, events)

            {:ok, updated_manager}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Unloads an extension from the manager.
  """
  @spec unload_extension(t(), String.t()) :: {:ok, t()} | {:error, any()}
  def unload_extension(manager, extension_id) do
    if Map.has_key?(manager.extensions, extension_id) do
      # Remove extension
      updated_manager = %{
        manager
        | extensions: Map.delete(manager.extensions, extension_id),
          metrics:
            manager.metrics
            |> Map.update(:extensions_loaded, 0, &max(&1 - 1, 0))
            |> Map.update(:extension_unloads, 1, &(&1 + 1))
      }

      # Remove commands
      updated_manager =
        unregister_extension_commands(updated_manager, extension_id)

      # Remove event handlers
      updated_manager =
        unregister_extension_events(updated_manager, extension_id)

      # Clean up commands and events maps
      updated_manager = %{
        updated_manager
        | commands:
            updated_manager.commands
            |> Enum.reject(fn {_cmd, id} -> id == extension_id end)
            |> Map.new(),
          events:
            updated_manager.events
            |> Enum.reject(fn {_event, id} -> id == extension_id end)
            |> Map.new()
      }

      {:ok, updated_manager}
    else
      {:error, :extension_not_found}
    end
  end

  @doc """
  Gets an extension by ID.
  """
  @spec get_extension(t(), String.t()) :: extension() | nil
  def get_extension(manager, extension_id) do
    Map.get(manager.extensions, extension_id)
  end

  @doc """
  Lists all loaded extensions.
  """
  @spec list_extensions(t()) :: [extension()]
  def list_extensions(manager) do
    Map.values(manager.extensions)
  end

  @doc """
  Emits an event to all registered handlers.
  """
  @spec emit_event(t(), atom() | String.t()) ::
          {:ok, list(), t()} | {:error, :event_not_found}
  def emit_event(manager, event_name), do: emit_event(manager, event_name, %{})

  @spec emit_event(t(), atom() | String.t(), any()) ::
          {:ok, list(), t()} | {:error, :event_not_found}
  def emit_event(manager, event_name, data) do
    handlers = Map.get(manager.event_handlers, event_name, [])

    if handlers == [] do
      # Check if it's an error for missing event, not just missing handlers
      {:error, :event_not_found}
    else
      results =
        Enum.map(handlers, fn {ext_id, handler} ->
          case execute_handler(manager, ext_id, handler, data) do
            {:ok, result} -> {:ok, ext_id, result}
            {:error, reason} -> {:error, ext_id, reason}
          end
        end)

      updated_manager = %{
        manager
        | metrics: Map.update(manager.metrics, :events_emitted, 1, &(&1 + 1))
      }

      {:ok, results, updated_manager}
    end
  end

  @doc """
  Executes a command from an extension.
  """
  @spec execute_command(t(), String.t()) :: {:error, any()}
  def execute_command(manager, command_name),
    do: execute_command(manager, command_name, %{})

  @spec execute_command(t(), String.t(), map()) ::
          {:ok, t(), any()} | {:error, any()}
  def execute_command(manager, command_name, params) do
    case Map.get(manager.command_registry, command_name) do
      nil ->
        {:error, :command_not_found}

      {ext_id, command_handler} ->
        case execute_handler(manager, ext_id, command_handler, params) do
          {:ok, result} ->
            updated_manager = %{
              manager
              | metrics:
                  Map.update(manager.metrics, :commands_executed, 1, &(&1 + 1))
                  |> Map.update(:command_executions, 1, &(&1 + 1))
            }

            {:ok, result, updated_manager}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Updates configuration for an extension.
  """
  @spec update_extension_config(t(), String.t(), map()) ::
          {:ok, t()} | {:error, any()}
  def update_extension_config(manager, extension_id, config) do
    case Map.get(manager.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        updated_extension = Map.put(extension, :config, config)

        updated_manager = %{
          manager
          | extensions:
              Map.put(manager.extensions, extension_id, updated_extension),
            metrics: Map.update(manager.metrics, :config_updates, 1, &(&1 + 1))
        }

        {:ok, updated_manager}
    end
  end

  @doc """
  Gets current metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  # Private functions

  defp validate_extension(extension) do
    # Check for required fields
    has_name = Map.has_key?(extension, :name) or Map.has_key?(extension, "name")

    has_version =
      Map.has_key?(extension, :version) or Map.has_key?(extension, "version")

    has_description =
      Map.has_key?(extension, :description) or
        Map.has_key?(extension, "description")

    has_author =
      Map.has_key?(extension, :author) or Map.has_key?(extension, "author")

    cond do
      not has_name ->
        {:error, {:missing_fields, [:name]}}

      not (has_version and has_description and has_author) ->
        {:error, :invalid_extension}

      true ->
        :ok
    end
  end

  defp generate_extension_id(name) do
    # Generate ID from name
    String.replace(String.downcase(name), ~r/[^a-z0-9]/, "_")
  end

  defp register_extension_commands(manager, ext_id, commands)
       when is_list(commands) do
    Enum.reduce(commands, manager, fn cmd_name, acc ->
      %{
        acc
        | commands: Map.put(acc.commands, cmd_name, ext_id),
          command_registry:
            Map.put(acc.command_registry, cmd_name, {ext_id, nil})
      }
    end)
  end

  defp register_extension_commands(manager, ext_id, commands)
       when is_map(commands) do
    Enum.reduce(commands, manager, fn {cmd_name, handler}, acc ->
      %{
        acc
        | commands: Map.put(acc.commands, cmd_name, ext_id),
          command_registry:
            Map.put(acc.command_registry, cmd_name, {ext_id, handler})
      }
    end)
  end

  defp register_extension_commands(manager, _ext_id, _commands), do: manager

  defp unregister_extension_commands(manager, ext_id) do
    updated_registry =
      manager.command_registry
      |> Enum.reject(fn {_cmd, {id, _}} -> id == ext_id end)
      |> Map.new()

    %{manager | command_registry: updated_registry}
  end

  defp register_extension_events(manager, ext_id, events)
       when is_list(events) do
    updated_manager =
      Enum.reduce(events, manager, fn event_name, acc ->
        %{
          acc
          | events: Map.put(acc.events, event_name, ext_id),
            event_handlers:
              Map.update(
                acc.event_handlers,
                event_name,
                [{ext_id, nil}],
                fn handlers ->
                  [{ext_id, nil} | handlers]
                end
              )
        }
      end)

    %{
      updated_manager
      | metrics:
          Map.update(
            updated_manager.metrics,
            :event_handlers,
            length(events),
            &(&1 + length(events))
          )
    }
  end

  defp register_extension_events(manager, ext_id, events) when is_map(events) do
    Enum.reduce(events, manager, fn {event_name, handler}, acc ->
      current_handlers = Map.get(acc.event_handlers, event_name, [])
      updated_handlers = [{ext_id, handler} | current_handlers]

      %{
        acc
        | events: Map.put(acc.events, event_name, ext_id),
          event_handlers:
            Map.put(acc.event_handlers, event_name, updated_handlers)
      }
    end)
  end

  defp register_extension_events(manager, _ext_id, _events), do: manager

  defp unregister_extension_events(manager, ext_id) do
    updated_handlers =
      manager.event_handlers
      |> Enum.map(fn {event_name, handlers} ->
        filtered_handlers =
          Enum.reject(handlers, fn {id, _} -> id == ext_id end)

        {event_name, filtered_handlers}
      end)
      |> Enum.reject(fn {_event, handlers} -> handlers == [] end)
      |> Map.new()

    %{manager | event_handlers: updated_handlers}
  end

  defp execute_handler(_manager, _ext_id, nil, data) do
    # For list-based events/commands with no specific handler, just return the data
    {:ok, data}
  end

  defp execute_handler(_manager, _ext_id, handler, data)
       when is_function(handler, 1) do
    try do
      result = handler.(data)
      {:ok, result}
    rescue
      e -> {:error, {:handler_error, e}}
    end
  end

  defp execute_handler(_manager, _ext_id, _handler, _data) do
    {:error, :invalid_handler}
  end
end
