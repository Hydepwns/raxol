defmodule Raxol.Web.Supervisor do
  @moduledoc """
  Supervisor for web-related processes.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Raxol.Web.Registry},
      {DynamicSupervisor,
       name: Raxol.Web.DynamicSupervisor, strategy: :one_for_one},
      Raxol.Web.WebManager,
      # Authentication Manager for handling user authentication
      Raxol.Web.Auth.AuthManager,
      # Session Manager for managing user sessions
      Raxol.Web.Session.SessionManager,
      # Add Phoenix Presence for user tracking
      {RaxolWeb.Presence, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
