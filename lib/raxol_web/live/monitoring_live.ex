defmodule RaxolWeb.MonitoringLive do
  use RaxolWeb, :live_view
  alias Raxol.Metrics

  @impl Phoenix.LiveView
  @dialyzer {:nowarn_function, mount: 3}
  def mount(_params, _session, socket) do
    case connected?(socket) do
      true ->
        _ = :timer.send_interval(5000, :update_metrics)

      false ->
        :ok
    end

    {:ok,
     assign(socket,
       metrics: Metrics.get_current_metrics(),
       error: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_info(:update_metrics, socket) do
    {:noreply, assign(socket, metrics: Metrics.get_current_metrics())}
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    {:noreply, assign(socket, metrics: Metrics.get_current_metrics())}
  end
end
