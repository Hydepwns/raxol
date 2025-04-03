defmodule Raxol.Terminal.Supervisor do
  @moduledoc """
  Supervisor for terminal-related processes.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Terminal Registry for managing terminal sessions
      {Registry, keys: :unique, name: Raxol.Terminal.Registry},
      # Dynamic Supervisor for terminal processes
      {DynamicSupervisor, name: Raxol.Terminal.DynamicSupervisor, strategy: :one_for_one},
      # ANSI Processor for handling ANSI escape codes
      Raxol.Terminal.ANSI.Processor,
      # Terminal Manager for coordinating terminal sessions
      Raxol.Terminal.Manager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end 