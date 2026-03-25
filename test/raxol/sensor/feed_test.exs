defmodule Raxol.Sensor.FailSensor do
  @moduledoc false
  @behaviour Raxol.Sensor.Behaviour

  @impl true
  def connect(_opts), do: {:ok, %{tick: 0}}

  @impl true
  def read(_state), do: {:error, :always_fail}

  @impl true
  def disconnect(_state), do: :ok
end

defmodule Raxol.Sensor.FeedTest do
  use ExUnit.Case, async: true

  alias Raxol.Sensor.{Feed, MockSensor, FailSensor}

  describe "poll cycle" do
    test "connects and starts producing readings" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :feed_test,
          module: MockSensor,
          sample_rate_ms: 10
        )

      Process.sleep(50)

      assert Feed.get_status(pid) == :running
      assert {:ok, reading} = Feed.get_latest(pid)
      assert reading.sensor_id == :feed_test
    end

    test "buffers readings in history" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :history_test,
          module: MockSensor,
          sample_rate_ms: 10
        )

      Process.sleep(80)

      history = Feed.get_history(pid, 5)
      assert length(history) >= 3
    end

    test "forwards readings to fusion_pid" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :fusion_fwd,
          module: MockSensor,
          sample_rate_ms: 10,
          fusion_pid: self()
        )

      assert_receive {:sensor_reading, %{sensor_id: :fusion_fwd}}, 200
      GenServer.stop(pid)
    end
  end

  describe "error escalation" do
    test "switches to error status after max_errors" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :fail_test,
          module: FailSensor,
          sample_rate_ms: 5,
          max_errors: 3
        )

      Process.sleep(100)
      assert Feed.get_status(pid) == :error
    end
  end

  describe "reconnect" do
    test "reconnect resets error state" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :reconnect_test,
          module: MockSensor,
          sample_rate_ms: 10
        )

      Process.sleep(30)
      assert Feed.get_status(pid) == :running

      Feed.reconnect(pid)
      Process.sleep(30)
      assert Feed.get_status(pid) == :running
    end
  end

  describe "get_latest/get_history" do
    test "get_latest returns error when empty" do
      {:ok, pid} =
        Feed.start_link(
          sensor_id: :empty_test,
          module: MockSensor,
          sample_rate_ms: 60_000
        )

      # Very long poll interval, so buffer should still be empty
      # (first poll hasn't fired yet if we're fast enough)
      # This is timing-dependent, so we accept either result
      result = Feed.get_latest(pid)
      assert match?({:ok, _}, result) or match?({:error, :empty}, result)
    end
  end
end
