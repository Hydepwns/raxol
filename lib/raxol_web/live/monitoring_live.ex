defmodule RaxolWeb.MonitoringLive do
  use RaxolWeb, :live_view
  alias Raxol.Metrics

  @impl true
  @dialyzer {:nowarn_function, mount: 3}
  def mount(_params, _session, socket) do
    if connected?(socket) do
      _ = :timer.send_interval(5000, :update_metrics)
    end

    {:ok,
     assign(socket,
       metrics: Metrics.get_current_metrics(),
       error: nil
     )}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    {:noreply, assign(socket, metrics: Metrics.get_current_metrics())}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign(socket, metrics: Metrics.get_current_metrics())}
  end
end
