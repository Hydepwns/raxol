defmodule Raxol.Web.Supervisor do
  @moduledoc """
  Web supervisor for Raxol web interface components.

  This supervisor manages web-related processes including:
  - WebManager: Core web interface management
  - SessionBridge: Terminal-web session transitions
  - PersistentStore: Multi-tier storage for session data

  ## Child Process Strategy

  Uses `:one_for_one` strategy where each child is restarted independently
  if it crashes. This is appropriate because:
  - WebManager is independent of other processes
  - SessionBridge can recover state from PersistentStore
  - PersistentStore uses ETS/DETS which survives process crashes
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # PersistentStore should start first as other services may depend on it
      {Raxol.Web.PersistentStore, []},
      # SessionBridge manages terminal-web transitions
      {Raxol.Web.SessionBridge, []},
      # WebManager handles high-level web interface coordination
      {Raxol.Web.WebManager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
