defmodule Raxol.Terminal.Supervisor do
  @moduledoc """
  Supervisor for terminal-related processes.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Raxol.Terminal.SessionRegistry},
      {Raxol.Terminal.Registry, []},
      {DynamicSupervisor,
       name: Raxol.Terminal.DynamicSupervisor, strategy: :one_for_one},
      {Raxol.Terminal.Manager, []},
      {Raxol.Terminal.Cache.System, [
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
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
