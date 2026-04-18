defmodule Raxol.Watch.Push.Backend do
  @moduledoc """
  Behaviour for push notification backends.

  Implementations deliver notification payloads to specific device tokens
  via platform-specific push services (APNS, FCM).
  """

  @doc "Push a notification to a device."
  @callback push(device_token :: String.t(), notification :: map()) :: :ok | {:error, term()}
end
