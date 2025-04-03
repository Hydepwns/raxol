defmodule Raxol.Web.Supervisor do
  @moduledoc """
  Supervisor for web-related processes.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # WebSocket Registry for managing WebSocket connections
      {Registry, keys: :unique, name: Raxol.Web.Registry},
      # Dynamic Supervisor for WebSocket processes
      {DynamicSupervisor, name: Raxol.Web.DynamicSupervisor, strategy: :one_for_one},
      # Web Interface Manager for coordinating web sessions
      Raxol.Web.Manager,
      # Authentication Manager for handling user authentication
      Raxol.Web.Auth.Manager,
      # Session Manager for managing user sessions
      Raxol.Web.Session.Manager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end 