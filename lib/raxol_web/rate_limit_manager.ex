defmodule RaxolWeb.RateLimitManager do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Create the rate limiting table
    :ets.new(:rate_limit_table, [:set, :public, :named_table])

    # Schedule cleanup every minute
    schedule_cleanup()

    Logger.info("Rate limit manager started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up old rate limit entries (older than 1 minute)
    now = System.system_time(:second)

    deleted =
      :ets.select_delete(:rate_limit_table, [
        {{:_, :_, :"$1"}, [{:<, :"$1", now - 60}], [true]}
      ])

    if deleted > 0 do
      Logger.debug("Cleaned up #{deleted} old rate limit entries")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Every minute
    Process.send_after(self(), :cleanup, 60_000)
  end
end
