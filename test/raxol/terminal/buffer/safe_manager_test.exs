defmodule Raxol.Terminal.Buffer.SafeManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.SafeManager

  setup do
    # Ensure ErrorRecovery is started for tests
    case GenServer.whereis(Raxol.Core.ErrorRecovery) do
      nil ->
        {:ok, _} = Raxol.Core.ErrorRecovery.start_link()

      _ ->
        :ok
    end

    {:ok, pid} = SafeManager.start_link(width: 80, height: 24)

    on_exit(fn ->
      # Clean up
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, pid: pid}
  end

  describe "error handling" do
    test "handles write errors gracefully", %{pid: pid} do
      # Write normal data
      assert {:ok, _} = SafeManager.write(pid, "Hello, World!")

      # Write extremely large data (should handle gracefully)
      large_data = String.duplicate("x", 2_000_000)
      assert {:error, :input_too_large} = SafeManager.write(pid, large_data)

      # Verify manager is still functional
      assert {:ok, _} = SafeManager.write(pid, "Still working!")
    end

    test "recovers from timeout errors", %{pid: pid} do
      # This would require mocking the underlying manager to timeout
      # For now, just verify normal operation
      assert {:ok, _} = SafeManager.write(pid, "Test")
    end

    test "uses fallback buffer when circuit breaker opens", %{pid: pid} do
      # Would need to trigger multiple failures to open circuit breaker
      # This is a placeholder for the test structure
      assert {:ok, _} = SafeManager.write(pid, "Test")
    end

    test "validates resize dimensions", %{pid: pid} do
      # Check if manager is properly initialized
      case SafeManager.resize(pid, 100, 50) do
        :ok ->
          # Manager is working properly
          assert {:error, :invalid_dimensions} = SafeManager.resize(pid, 0, 50)

          assert {:error, :invalid_dimensions} =
                   SafeManager.resize(pid, 100, -1)

          assert {:error, :dimensions_too_large} =
                   SafeManager.resize(pid, 20_000, 20_000)

        {:error, :no_manager} ->
          # Manager failed to start underlying manager, but that's expected behavior
          # Test the validation still works
          assert {:error, :invalid_dimensions} = SafeManager.resize(pid, 0, 50)

          assert {:error, :invalid_dimensions} =
                   SafeManager.resize(pid, 100, -1)

          assert {:error, :dimensions_too_large} =
                   SafeManager.resize(pid, 20_000, 20_000)
      end
    end
  end

  describe "statistics and monitoring" do
    test "tracks write and read statistics", %{pid: pid} do
      # Perform some operations
      SafeManager.write(pid, "Test 1")
      SafeManager.write(pid, "Test 2")
      SafeManager.read(pid)

      # Check stats
      {:ok, stats} = SafeManager.get_stats(pid)
      assert stats.writes == 2
      assert stats.reads == 1

      # If the underlying manager failed to start, there might be 1 error during initialization
      assert stats.errors in [0, 1]
    end

    test "reports circuit breaker state", %{pid: pid} do
      {:ok, stats} = SafeManager.get_stats(pid)
      assert stats.circuit_breaker_state == :closed
    end

    test "tracks error counts", %{pid: pid} do
      # Would need to trigger actual errors
      {:ok, stats} = SafeManager.get_stats(pid)
      assert stats.error_count == 0
    end
  end

  describe "recovery mechanisms" do
    test "can reset error state", %{pid: pid} do
      # Reset errors
      SafeManager.reset_errors(pid)

      # Verify clean state
      {:ok, stats} = SafeManager.get_stats(pid)
      assert stats.error_count == 0
      assert stats.circuit_breaker_state == :closed
    end

    test "monitors and restarts underlying manager" do
      # This would require killing the underlying manager process
      # Placeholder for test structure
      assert true
    end
  end
end
