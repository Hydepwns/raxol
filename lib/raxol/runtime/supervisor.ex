defmodule Raxol.Runtime.Supervisor do
  @moduledoc """
  Supervisor for managing runtime processes in Raxol.

  This supervisor is responsible for managing the lifecycle of runtime processes,
  including the main runtime and any dynamic children that may be created.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Add any permanent children here
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
