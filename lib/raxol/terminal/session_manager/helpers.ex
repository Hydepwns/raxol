defmodule Raxol.Terminal.SessionManager.Helpers do
  @moduledoc """
  Helper functions for SessionManager operations.

  Provides utilities for session cleanup, timing, and other session management tasks.
  """

  @doc """
  Starts a cleanup timer for periodic session maintenance.

  ## Parameters
    - interval: Time interval in milliseconds for cleanup

  ## Returns
    Timer reference
  """
  @spec start_cleanup_timer(non_neg_integer()) :: reference()
  def start_cleanup_timer(interval)
      when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :cleanup_sessions, interval)
  end

  def start_cleanup_timer(_interval) do
    # Default to 30 seconds if invalid interval provided
    Process.send_after(self(), :cleanup_sessions, 30_000)
  end

  @doc """
  Cancels a cleanup timer.

  ## Parameters
    - timer_ref: Timer reference to cancel

  ## Returns
    - :ok if timer was canceled
    - {:error, :not_found} if timer doesn't exist
  """
  @spec cancel_cleanup_timer(reference() | nil) :: :ok | {:error, :not_found}
  def cancel_cleanup_timer(nil), do: :ok

  def cancel_cleanup_timer(timer_ref) when is_reference(timer_ref) do
    case Process.cancel_timer(timer_ref) do
      false -> {:error, :not_found}
      _ -> :ok
    end
  end

  @doc """
  Checks if a session has expired based on last activity.

  ## Parameters
    - last_activity: Timestamp of last activity
    - timeout: Timeout duration in milliseconds

  ## Returns
    Boolean indicating if session is expired
  """
  @spec session_expired?(integer(), non_neg_integer()) :: boolean()
  def session_expired?(last_activity, timeout)
      when is_integer(last_activity) and is_integer(timeout) do
    current_time = System.monotonic_time(:millisecond)
    current_time - last_activity > timeout
  end

  def session_expired?(_last_activity, _timeout), do: false

  @doc """
  Generates a unique session ID.

  ## Returns
    String session ID
  """
  @spec generate_session_id() :: String.t()
  def generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
    |> String.replace(["+", "/"], fn
      "+" -> "-"
      "/" -> "_"
    end)
  end

  @doc """
  Validates session configuration.

  ## Parameters
    - config: Session configuration map

  ## Returns
    - {:ok, config} if valid
    - {:error, reason} if invalid
  """
  @spec validate_session_config(map()) :: {:ok, map()} | {:error, atom()}
  def validate_session_config(config) when is_map(config) do
    with :ok <- validate_dimensions(config),
         :ok <- validate_timeout(config) do
      {:ok, config}
    end
  end

  def validate_session_config(_config), do: {:error, :invalid_config}

  defp validate_dimensions(%{width: w, height: h})
       when is_integer(w) and w > 0 and is_integer(h) and h > 0,
       do: :ok

  # Dimensions are optional
  defp validate_dimensions(%{}), do: :ok
  defp validate_dimensions(_), do: {:error, :invalid_dimensions}

  defp validate_timeout(%{timeout: t}) when is_integer(t) and t > 0, do: :ok
  # Timeout is optional
  defp validate_timeout(%{}), do: :ok
  defp validate_timeout(_), do: {:error, :invalid_timeout}

  @doc """
  Merges session options with defaults.

  ## Parameters
    - opts: User-provided options
    - defaults: Default options

  ## Returns
    Merged options map
  """
  @spec merge_session_options(Keyword.t() | map(), map()) :: map()
  def merge_session_options(opts, defaults) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> merge_session_options(defaults)
  end

  def merge_session_options(opts, defaults)
      when is_map(opts) and is_map(defaults) do
    Map.merge(defaults, opts)
  end

  def merge_session_options(_opts, defaults), do: defaults

  @doc """
  Formats session info for display.

  ## Parameters
    - session: Session data map

  ## Returns
    Formatted string
  """
  @spec format_session_info(map()) :: String.t()
  def format_session_info(
        %{id: id, created_at: created, active: active} = session
      ) do
    status = if active, do: "active", else: "inactive"
    dimensions = get_dimensions_string(session)

    "Session #{id} (#{status}) - Created: #{format_timestamp(created)}#{dimensions}"
  end

  def format_session_info(_), do: "Invalid session"

  defp get_dimensions_string(%{width: w, height: h}), do: " - Size: #{w}x#{h}"
  defp get_dimensions_string(_), do: ""

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    timestamp
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_string()
  end

  defp format_timestamp(_), do: "unknown"
end
