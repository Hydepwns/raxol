defmodule Raxol.Terminal.Supervisor do
  @moduledoc """
  Supervisor for terminal-related processes.
  """

  use Supervisor

  # Cache size budgets (bytes)
  @total_cache_size 100 * 1024 * 1024
  @animation_cache_size 10 * 1024 * 1024
  @buffer_cache_size 50 * 1024 * 1024
  @scroll_cache_size 20 * 1024 * 1024
  @clipboard_cache_size 1 * 1024 * 1024
  @general_cache_size 19 * 1024 * 1024
  @default_cache_ttl_s Raxol.Core.Defaults.cache_ttl_seconds()

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Raxol.Terminal.SessionRegistry},
      {DynamicSupervisor, name: Raxol.Terminal.DynamicSupervisor, strategy: :one_for_one},
      {Raxol.Terminal.Cache.System,
       [
         max_size: @total_cache_size,
         default_ttl: @default_cache_ttl_s,
         eviction_policy: :lru,
         namespace_configs: %{
           animation: %{max_size: @animation_cache_size},
           buffer: %{max_size: @buffer_cache_size},
           scroll: %{max_size: @scroll_cache_size},
           clipboard: %{max_size: @clipboard_cache_size},
           general: %{max_size: @general_cache_size}
         }
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
