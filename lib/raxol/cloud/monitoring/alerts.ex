# Alerts implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Alerts do
  @moduledoc false


  def init(config) do
    alerts_state = %{
      config: config
    }

    Raxol.Cloud.Monitoring.Server.init_alerts(alerts_state)
    :ok
  end

  def process(alert, opts \\ []) do
    opts = normalize_opts(opts)
    alerts_state = get_alerts_state()

    # Check if we should notify
    notify = Keyword.get(opts, :notify, true)

    handle_notification(notify, alert, alerts_state.config)
    :ok
  end

  defp handle_notification(true, alert, config) do
    send_notifications(alert, config)
  end

  defp handle_notification(false, _alert, _config) do
    :ok
  end

  # Private helpers

  defp get_alerts_state() do
    Raxol.Cloud.Monitoring.Server.get_alerts() || %{config: %{}}
  end

  defp send_notifications(_alert, _config) do
    # Send notifications
    :ok
  end

  defp normalize_opts(opts) when is_map(opts), do: Enum.into(opts, [])
  defp normalize_opts(opts), do: opts
end
