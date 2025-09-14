defmodule RaxolPlayground.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RaxolPlaygroundWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:raxol_playground, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RaxolPlayground.PubSub},
      RaxolPlaygroundWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RaxolPlayground.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RaxolPlaygroundWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end