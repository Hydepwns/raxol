defmodule Raxol.Terminal.Supervisor do
  @moduledoc """
  Supervisor for terminal-related processes.
  """

  use Supervisor
  alias Raxol.Core.Runtime.Log

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Raxol.Terminal.SessionRegistry},
      {Raxol.Terminal.TerminalRegistry, []},
      {DynamicSupervisor,
       name: Raxol.Terminal.DynamicSupervisor, strategy: :one_for_one},
      {Raxol.Terminal.Manager, []},
      {Raxol.Terminal.Cache.System,
       [
         max_size: 100 * 1024 * 1024,
         default_ttl: 3600,
         eviction_policy: :lru,
         namespace_configs: %{
           animation: %{max_size: 10 * 1024 * 1024},
           buffer: %{max_size: 50 * 1024 * 1024},
           scroll: %{max_size: 20 * 1024 * 1024},
           clipboard: %{max_size: 1 * 1024 * 1024},
           general: %{max_size: 19 * 1024 * 1024}
         }
       ]},
      # Event Sourcing & CQRS Components
      {Raxol.Architecture.EventSourcing.EventStore, []},
      {Raxol.Architecture.CQRS.CommandDispatcher, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Starts a new terminal with the given configuration using CQRS.
  """
  def start_terminal(terminal_config) do
    case DynamicSupervisor.start_child(
           Raxol.Terminal.DynamicSupervisor,
           {Raxol.Terminal.TerminalProcess, terminal_config}
         ) do
      {:ok, pid} ->
        Log.module_info(
          "Started terminal #{terminal_config.terminal_id} with pid #{inspect(pid)}"
        )

        {:ok, pid}

      {:error, reason} ->
        Log.module_error(
          "Failed to start terminal #{terminal_config.terminal_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Stops a terminal process using CQRS.
  """
  def stop_terminal(terminal_id) do
    case Raxol.Terminal.TerminalRegistry.lookup(terminal_id) do
      {:ok, pid} ->
        case DynamicSupervisor.terminate_child(
               Raxol.Terminal.DynamicSupervisor,
               pid
             ) do
          :ok ->
            Log.module_info("Stopped terminal #{terminal_id}")
            :ok

          {:error, reason} ->
            Log.module_error(
              "Failed to stop terminal #{terminal_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :terminal_not_found}
    end
  end
end
