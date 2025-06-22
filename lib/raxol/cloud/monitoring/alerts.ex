# Alerts implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Alerts do
  import Raxol.Guards

  @moduledoc false

  # Process dictionary key for alerts
  @alerts_key :raxol_monitoring_alerts

  def init(config) do
    alerts_state = %{
      config: config
    }

    Process.put(@alerts_key, alerts_state)
    :ok
  end

  def process(alert, opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
    alerts_state = get_alerts_state()

    # Check if we should notify
    notify = Keyword.get(opts, :notify, true)

    if notify do
      # Send notifications
      send_notifications(alert, alerts_state.config)
    end

    :ok
  end

  # Private helpers

  defp get_alerts_state() do
    Process.get(@alerts_key) || %{config: %{}}
  end

  defp send_notifications(_alert, _config) do
    # Send notifications
    :ok
  end
end
