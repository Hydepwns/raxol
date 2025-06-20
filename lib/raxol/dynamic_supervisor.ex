defmodule Raxol.DynamicSupervisor do
  @moduledoc """
  A dynamic supervisor for dynamically starting Raxol application processes.
  """
  use DynamicSupervisor
  @behaviour DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
