defmodule Raxol.MCP.CircuitBreakerTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.CircuitBreaker

  setup do
    table = CircuitBreaker.new(:"breaker_#{System.unique_integer([:positive])}")
    %{table: table}
  end

  @key {:tool, "flaky_tool"}

  describe "initial state" do
    test "starts closed with zero failures", %{table: t} do
      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.status(t, @key) == %{state: :closed, failures: 0}
    end
  end

  describe "closed state" do
    test "stays closed on success", %{table: t} do
      CircuitBreaker.record_failure(t, @key, failure_threshold: 5)
      CircuitBreaker.record_success(t, @key)

      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.status(t, @key).failures == 0
    end

    test "counts failures without opening below threshold", %{table: t} do
      for _ <- 1..4 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 5)
      end

      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.status(t, @key).failures == 4
    end

    test "transitions to open at threshold", %{table: t} do
      for _ <- 1..5 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 5)
      end

      assert CircuitBreaker.check(t, @key) == :open
      assert CircuitBreaker.status(t, @key).state == :open
    end

    test "threshold of 1 opens on first failure", %{table: t} do
      CircuitBreaker.record_failure(t, @key, failure_threshold: 1)
      assert CircuitBreaker.check(t, @key) == :open
    end
  end

  describe "open state" do
    test "blocks calls while open", %{table: t} do
      for _ <- 1..3 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 3)
      end

      # Recovery time not yet elapsed
      assert CircuitBreaker.check(t, @key, recovery_ms: 60_000) == :open
    end

    test "transitions to half_open after recovery period", %{table: t} do
      for _ <- 1..3 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 3)
      end

      # Use very short recovery so it elapses immediately
      assert CircuitBreaker.check(t, @key, recovery_ms: 0) == :half_open
    end
  end

  describe "half_open state" do
    setup %{table: t} do
      for _ <- 1..3 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 3)
      end

      # Move to half_open
      :half_open = CircuitBreaker.check(t, @key, recovery_ms: 0)
      :ok
    end

    test "successful probe resets to closed", %{table: t} do
      CircuitBreaker.record_success(t, @key)

      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.status(t, @key).failures == 0
    end

    test "failed probe re-opens circuit", %{table: t} do
      CircuitBreaker.record_failure(t, @key, failure_threshold: 3)

      assert CircuitBreaker.check(t, @key, recovery_ms: 60_000) == :open
    end
  end

  describe "reset" do
    test "manual reset clears circuit state", %{table: t} do
      for _ <- 1..5 do
        CircuitBreaker.record_failure(t, @key, failure_threshold: 5)
      end

      assert CircuitBreaker.check(t, @key, recovery_ms: 60_000) == :open

      CircuitBreaker.reset(t, @key)
      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.status(t, @key) == %{state: :closed, failures: 0}
    end

    test "reset_all clears all circuits", %{table: t} do
      key2 = {:resource, "raxol://test"}

      CircuitBreaker.record_failure(t, @key, failure_threshold: 1)
      CircuitBreaker.record_failure(t, key2, failure_threshold: 1)

      CircuitBreaker.reset_all(t)

      assert CircuitBreaker.check(t, @key) == :closed
      assert CircuitBreaker.check(t, key2) == :closed
    end
  end

  describe "independent keys" do
    test "different keys have independent circuits", %{table: t} do
      key_a = {:tool, "tool_a"}
      key_b = {:tool, "tool_b"}

      for _ <- 1..3 do
        CircuitBreaker.record_failure(t, key_a, failure_threshold: 3)
      end

      assert CircuitBreaker.check(t, key_a, recovery_ms: 60_000) == :open
      assert CircuitBreaker.check(t, key_b) == :closed
    end
  end
end
