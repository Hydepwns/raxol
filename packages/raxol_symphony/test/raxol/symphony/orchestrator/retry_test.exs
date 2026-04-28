defmodule Raxol.Symphony.Orchestrator.RetryTest do
  use ExUnit.Case, async: true

  alias Raxol.Symphony.Orchestrator.Retry

  describe "continuation_delay_ms/0" do
    test "returns 1000ms" do
      assert Retry.continuation_delay_ms() == 1_000
    end
  end

  describe "failure_delay_ms/2" do
    test "attempt 1 -> 10s" do
      assert Retry.failure_delay_ms(1, 300_000) == 10_000
    end

    test "attempt 2 -> 20s" do
      assert Retry.failure_delay_ms(2, 300_000) == 20_000
    end

    test "attempt 3 -> 40s" do
      assert Retry.failure_delay_ms(3, 300_000) == 40_000
    end

    test "attempt 4 -> 80s" do
      assert Retry.failure_delay_ms(4, 300_000) == 80_000
    end

    test "caps at max_retry_backoff_ms" do
      # 10000 * 2^(10-1) = 5_120_000 -> capped to 300_000
      assert Retry.failure_delay_ms(10, 300_000) == 300_000
    end

    test "respects custom cap" do
      assert Retry.failure_delay_ms(5, 50_000) == 50_000
    end
  end
end
