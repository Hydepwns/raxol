defmodule Raxol.Application do
  @moduledoc false
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Add supervised processes here
      {Registry, keys: :unique, name: Raxol.Registry},
      {DynamicSupervisor, name: Raxol.DynamicSupervisor, strategy: :one_for_one}
    ]
    
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end
end