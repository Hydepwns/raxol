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
      {Registry, keys: :unique, name: Raxol.Terminal.Registry},
      {DynamicSupervisor,
       name: Raxol.Terminal.DynamicSupervisor, strategy: :one_for_one},
      Raxol.Terminal.ANSI.Processor,
      {Raxol.Terminal.Manager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
