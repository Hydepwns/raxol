defmodule Raxol.Sensor.Supervisor do
  @moduledoc """
  Supervisor for the sensor fusion subsystem.

  Start order (rest_for_one):
  1. Registry -- name lookup for feeds
  2. DynamicSupervisor -- hosts Feed processes
  3. Fusion -- batches readings from all feeds
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @spec start_feed(keyword(), GenServer.server()) ::
          DynamicSupervisor.on_start_child()
  def start_feed(feed_opts, sup \\ __MODULE__) do
    fusion_name = Keyword.get(feed_opts, :fusion, Raxol.Sensor.Fusion)

    feed_opts =
      Keyword.put_new(feed_opts, :fusion_pid, GenServer.whereis(fusion_name))

    DynamicSupervisor.start_child(
      dynamic_sup_name(sup),
      {Raxol.Sensor.Feed, feed_opts}
    )
  end

  @impl true
  def init(opts) do
    fusion_opts = Keyword.get(opts, :fusion, [])
    registry_name = Keyword.get(opts, :registry_name, Raxol.Sensor.Registry)

    children = [
      {Registry, keys: :unique, name: registry_name},
      {DynamicSupervisor, name: dynamic_sup_name(opts), strategy: :one_for_one},
      {Raxol.Sensor.Fusion, fusion_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp dynamic_sup_name(opts) when is_list(opts) do
    Keyword.get(opts, :dynamic_sup_name, Raxol.Sensor.DynSup)
  end

  defp dynamic_sup_name(sup) when is_atom(sup) do
    Module.concat(sup, DynSup)
  end
end
