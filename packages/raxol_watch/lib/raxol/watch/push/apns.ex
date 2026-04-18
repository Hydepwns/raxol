defmodule Raxol.Watch.Push.APNS do
  @moduledoc """
  Apple Push Notification Service backend via Pigeon.

  Converts Raxol notification payloads to APNS format and delivers
  them via `Pigeon.APNS`. Requires Pigeon to be configured with
  valid APNS credentials.
  """

  @behaviour Raxol.Watch.Push.Backend

  @compile {:no_warn_undefined, [Pigeon.APNS, Pigeon.APNS.Notification]}

  @impl true
  def push(device_token, notification) do
    if Code.ensure_loaded?(Pigeon.APNS) do
      apns_notification = build_notification(device_token, notification)

      case Pigeon.APNS.push(apns_notification) do
        %{response: :success} -> :ok
        %{response: reason} -> {:error, reason}
        other -> {:error, other}
      end
    else
      {:error, :pigeon_not_available}
    end
  end

  defp build_notification(device_token, %{title: title, body: body} = notif) do
    priority = if notif[:priority] == :high, do: 10, else: 5

    Pigeon.APNS.Notification.new(device_token, %{
      "aps" => %{
        "alert" => %{"title" => title, "body" => body},
        "badge" => Map.get(notif, :badge, 0),
        "category" => Map.get(notif, :category, "raxol_alert"),
        "sound" => if(notif[:priority] == :high, do: "default", else: nil)
      },
      "priority" => priority
    })
  end
end
