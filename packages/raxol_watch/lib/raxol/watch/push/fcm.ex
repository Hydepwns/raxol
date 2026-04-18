defmodule Raxol.Watch.Push.FCM do
  @moduledoc """
  Firebase Cloud Messaging backend via Pigeon.

  Converts Raxol notification payloads to FCM format and delivers
  them via `Pigeon.FCM`. Requires Pigeon to be configured with
  valid FCM credentials.
  """

  @behaviour Raxol.Watch.Push.Backend

  @compile {:no_warn_undefined, [Pigeon.FCM, Pigeon.FCM.Notification]}

  @impl true
  def push(device_token, notification) do
    if Code.ensure_loaded?(Pigeon.FCM) do
      fcm_notification = build_notification(device_token, notification)

      case Pigeon.FCM.push(fcm_notification) do
        %{response: :success} -> :ok
        %{response: reason} -> {:error, reason}
        other -> {:error, other}
      end
    else
      {:error, :pigeon_not_available}
    end
  end

  defp build_notification(device_token, %{title: title, body: body} = notif) do
    priority = if notif[:priority] == :high, do: "high", else: "normal"

    actions =
      notif
      |> Map.get(:actions, [])
      |> Enum.map(fn %{id: id, label: label} -> %{"id" => id, "label" => label} end)

    Pigeon.FCM.Notification.new(device_token, %{
      "notification" => %{"title" => title, "body" => body},
      "android" => %{
        "priority" => priority,
        "notification" => %{
          "click_action" => Map.get(notif, :category, "raxol_alert")
        }
      },
      "data" => %{
        "category" => Map.get(notif, :category, "raxol_alert"),
        "actions" => Jason.encode!(actions)
      }
    })
  end
end
