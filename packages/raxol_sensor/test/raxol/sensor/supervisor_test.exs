defmodule Raxol.Sensor.SupervisorTest do
  use ExUnit.Case, async: false

  alias Raxol.Sensor.{Supervisor, Feed, MockSensor}

  describe "supervisor tree" do
    test "starts all children" do
      {:ok, sup} =
        Supervisor.start_link(
          name: :"sensor_sup_#{:erlang.unique_integer([:positive])}",
          registry_name: :"sensor_reg_#{:erlang.unique_integer([:positive])}",
          dynamic_sup_name: :"sensor_dyn_#{:erlang.unique_integer([:positive])}",
          fusion: [name: :"sensor_fusion_#{:erlang.unique_integer([:positive])}"]
        )

      children = Elixir.Supervisor.which_children(sup)
      assert length(children) == 3
    end

    test "feeds can be added dynamically" do
      fusion_name = :"fusion_dyn_#{:erlang.unique_integer([:positive])}"
      dyn_name = :"dyn_sup_#{:erlang.unique_integer([:positive])}"

      {:ok, sup} =
        Supervisor.start_link(
          name: :"sup_dyn_#{:erlang.unique_integer([:positive])}",
          registry_name: :"reg_dyn_#{:erlang.unique_integer([:positive])}",
          dynamic_sup_name: dyn_name,
          fusion: [name: fusion_name]
        )

      fusion_pid = GenServer.whereis(fusion_name)

      {:ok, feed_pid} =
        DynamicSupervisor.start_child(
          dyn_name,
          {Feed,
           [
             sensor_id: :dynamic_test,
             module: MockSensor,
             sample_rate_ms: 50,
             fusion_pid: fusion_pid
           ]}
        )

      Process.sleep(100)
      assert Feed.get_status(feed_pid) == :running
      Elixir.Supervisor.stop(sup)
    end
  end
end
