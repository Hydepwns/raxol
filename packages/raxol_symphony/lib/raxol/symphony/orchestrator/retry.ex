defmodule Raxol.Symphony.Orchestrator.Retry do
  @moduledoc """
  Retry timing math.

  Implements SPEC s8.4 (Retry and Backoff):

  - **Continuation retries** -- after a clean worker exit. A short fixed delay
    (`1000 ms`) so the orchestrator can re-check whether the issue is still
    in an active state and needs another worker session.
  - **Failure-driven retries** -- exponential backoff:
      `delay = min(10000 * 2^(attempt - 1), max_retry_backoff_ms)`
  """

  @continuation_delay_ms 1_000
  @failure_base_delay_ms 10_000

  @doc """
  Delay for a continuation retry (clean worker exit).
  """
  @spec continuation_delay_ms() :: pos_integer()
  def continuation_delay_ms, do: @continuation_delay_ms

  @doc """
  Delay for a failure-driven retry on the given attempt number (1-based).

  `max_retry_backoff_ms` caps the result.
  """
  @spec failure_delay_ms(pos_integer(), pos_integer()) :: pos_integer()
  def failure_delay_ms(attempt, max_retry_backoff_ms)
      when is_integer(attempt) and attempt >= 1 and is_integer(max_retry_backoff_ms) and
             max_retry_backoff_ms > 0 do
    raw = @failure_base_delay_ms * Bitwise.bsl(1, attempt - 1)
    min(raw, max_retry_backoff_ms)
  end
end
