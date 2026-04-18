defmodule Raxol.Watch.Supervisor do
  @moduledoc """
  Top-level supervisor for the watch notification bridge.

  Starts the DeviceRegistry and Notifier.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    push_backend = Keyword.get(opts, :push_backend, Raxol.Watch.Push.Noop)

    children = [
      Raxol.Watch.DeviceRegistry,
      {Raxol.Watch.Notifier, push_backend: push_backend}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
