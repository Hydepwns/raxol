defmodule Raxol.RateLimit do
  @moduledoc """
  Rate limiting utilities for Raxol.

  Provides token bucket rate limiting for API endpoints and actions.

  ## Example

      case Raxol.RateLimit.check(:login, user_ip) do
        :ok -> process_login()
        {:error, :rate_limited} -> {:error, "Too many attempts"}
      end
  """

  use Agent

  @default_limits %{
    login: {5, 60_000},
    api: {100, 60_000},
    command: {10, 1_000}
  }

  @doc """
  Start the rate limiter agent.

  Usually started automatically by the application supervisor.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Check if an action is allowed under rate limits.

  ## Example

      case Raxol.RateLimit.check(:login, user_ip) do
        :ok -> process_login()
        {:error, :rate_limited} -> reject_request()
      end
  """
  @spec check(atom(), String.t(), keyword()) :: :ok | {:error, :rate_limited}
  def check(action, identifier, opts \\ []) do
    _ = ensure_started()

    {limit, window} = get_limit(action, opts)
    key = "#{action}:#{identifier}"
    now = System.monotonic_time(:millisecond)

    Agent.get_and_update(__MODULE__, fn state ->
      bucket = Map.get(state, key, %{count: 0, window_start: now})

      cond do
        # Window expired, reset
        now - bucket.window_start > window ->
          new_bucket = %{count: 1, window_start: now}
          {:ok, Map.put(state, key, new_bucket)}

        # Under limit
        bucket.count < limit ->
          new_bucket = %{bucket | count: bucket.count + 1}
          {:ok, Map.put(state, key, new_bucket)}

        # Over limit
        true ->
          {{:error, :rate_limited}, state}
      end
    end)
  end

  @doc """
  Get remaining requests in the current window.

  ## Example

      remaining = Raxol.RateLimit.remaining(:api, user_id)
      # => 95
  """
  @spec remaining(atom(), String.t(), keyword()) :: non_neg_integer()
  def remaining(action, identifier, opts \\ []) do
    _ = ensure_started()

    {limit, window} = get_limit(action, opts)
    key = "#{action}:#{identifier}"
    now = System.monotonic_time(:millisecond)

    Agent.get(__MODULE__, fn state ->
      case Map.get(state, key) do
        nil ->
          limit

        bucket ->
          if now - bucket.window_start > window do
            limit
          else
            max(0, limit - bucket.count)
          end
      end
    end)
  end

  @doc """
  Reset rate limit for an identifier.

  ## Example

      :ok = Raxol.RateLimit.reset(:login, user_ip)
  """
  @spec reset(atom(), String.t()) :: :ok
  def reset(action, identifier) do
    _ = ensure_started()
    key = "#{action}:#{identifier}"

    Agent.update(__MODULE__, fn state ->
      Map.delete(state, key)
    end)
  end

  @doc """
  Configure custom limits for an action.

  ## Example

      Raxol.RateLimit.configure(:custom_action, limit: 50, window: 30_000)
  """
  @dialyzer {:nowarn_function, configure: 2}
  @spec configure(atom(), keyword()) :: :ok
  def configure(action, opts) do
    limit = Keyword.get(opts, :limit, 100)
    window = Keyword.get(opts, :window, 60_000)

    Application.put_env(:raxol, {:rate_limit, action}, {limit, window})
    :ok
  end

  @doc """
  Get time until rate limit resets.

  ## Example

      ms = Raxol.RateLimit.reset_in(:login, user_ip)
      # => 45000 (milliseconds)
  """
  @spec reset_in(atom(), String.t(), keyword()) :: non_neg_integer()
  def reset_in(action, identifier, opts \\ []) do
    _ = ensure_started()

    {_limit, window} = get_limit(action, opts)
    key = "#{action}:#{identifier}"
    now = System.monotonic_time(:millisecond)

    Agent.get(__MODULE__, fn state ->
      case Map.get(state, key) do
        nil -> 0
        bucket -> max(0, window - (now - bucket.window_start))
      end
    end)
  end

  # Private helpers

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _pid -> :ok
    end
  end

  @dialyzer {:nowarn_function, get_limit: 2}
  defp get_limit(action, opts) do
    custom_limit = Keyword.get(opts, :limit)
    custom_window = Keyword.get(opts, :window)

    cond do
      custom_limit && custom_window ->
        {custom_limit, custom_window}

      true ->
        Application.get_env(:raxol, {:rate_limit, action}) ||
          Map.get(@default_limits, action, {100, 60_000})
    end
  end
end
