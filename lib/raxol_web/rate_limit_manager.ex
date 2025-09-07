defmodule RaxolWeb.RateLimitManager do
  @moduledoc """
  Rate limiting manager for web requests.

  Manages request rate limiting across different endpoints and users
  to prevent abuse and ensure system stability.
  """
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Create the rate limiting table safely (handles race conditions)
    Raxol.Core.CompilerState.ensure_table(:rate_limit_table, [
      :set,
      :public,
      :named_table
    ])

    # Schedule cleanup every minute
    schedule_cleanup()

    Logger.info("Rate limit manager started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up old rate limit entries (older than 1 minute)
    now = System.system_time(:second)

    # Check if table exists before trying to delete
    deleted =
      case :ets.whereis(:rate_limit_table) do
        :undefined ->
          0

        _tid ->
          :ets.select_delete(:rate_limit_table, [
            {{:_, :_, :"$1"}, [{:<, :"$1", now - 60}], [true]}
          ])
      end

    case deleted > 0 do
      true ->
        Logger.debug("Cleaned up #{deleted} old rate limit entries")

      false ->
        :ok
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Every minute
    Process.send_after(self(), :cleanup, 60_000)
  end
end
