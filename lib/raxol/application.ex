defmodule Raxol.Application do
  @moduledoc """
  The main application module for Raxol.
  
  This module is responsible for starting and supervising all the core components
  of the Raxol application, including:
  - Telemetry system
  - PubSub system
  - Web endpoint
  - Terminal supervisor
  - Web interface supervisor
  - Database repository
  - Metrics system
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RaxolWeb.Telemetry,
      
      # Start the PubSub system
      {Phoenix.PubSub, name: Raxol.PubSub},
      
      # Start the Endpoint (http/https)
      RaxolWeb.Endpoint,
      
      # Start the Terminal Supervisor
      Raxol.Terminal.Supervisor,
      
      # Start the Web Interface Supervisor
      Raxol.Web.Supervisor,
      
      # Start the Metrics system
      Raxol.Metrics,
      
      # Start the Runtime supervisor
      Raxol.Runtime.Supervisor,
      
      # Start the Ecto repository
      Raxol.Repo
    ]
    
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RaxolWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end