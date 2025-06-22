defmodule Raxol.Terminal.Split.Supervisor do
  @moduledoc """
  Supervisor for the terminal split management system.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_split_manager(opts \\ []) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Raxol.Terminal.Split.Manager, opts}
    )
  end

  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 3,
      max_seconds: 5
    )
  end
end
