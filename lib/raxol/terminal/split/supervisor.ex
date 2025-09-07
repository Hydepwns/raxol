defmodule Raxol.Terminal.Split.Supervisor do
  @moduledoc """
  Supervisor for the terminal split management system.
  """

  use DynamicSupervisor

  def start_link(init_arg \\ []) do
    opts =
      case is_map(init_arg) do
        true -> Enum.into(init_arg, [])
        false -> init_arg
      end

    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
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
