defmodule Raxol.Adaptive.SupervisorTest do
  use ExUnit.Case, async: false

  alias Raxol.Adaptive.Supervisor, as: AdaptiveSup

  describe "supervisor tree" do
    test "starts all children" do
      {:ok, sup} =
        AdaptiveSup.start_link(
          name: :"adaptive_sup_#{:erlang.unique_integer([:positive])}",
          behavior_tracker: [name: :"tracker_#{:erlang.unique_integer([:positive])}"],
          layout_recommender: [name: :"recommender_#{:erlang.unique_integer([:positive])}"],
          feedback_loop: [name: :"feedback_#{:erlang.unique_integer([:positive])}"]
        )

      children = Elixir.Supervisor.which_children(sup)
      assert length(children) == 3

      Elixir.Supervisor.stop(sup)
    end

    test "children are accessible after start" do
      tracker_name = :"tracker_acc_#{:erlang.unique_integer([:positive])}"
      feedback_name = :"feedback_acc_#{:erlang.unique_integer([:positive])}"

      {:ok, sup} =
        AdaptiveSup.start_link(
          name: :"adaptive_sup_acc_#{:erlang.unique_integer([:positive])}",
          behavior_tracker: [name: tracker_name],
          layout_recommender: [name: :"recommender_acc_#{:erlang.unique_integer([:positive])}"],
          feedback_loop: [name: feedback_name]
        )

      # Verify children respond
      events = Raxol.Adaptive.BehaviorTracker.get_recent_events(tracker_name, 5)
      assert events == []

      accuracy = Raxol.Adaptive.FeedbackLoop.get_accuracy(feedback_name)
      assert accuracy == 0.0

      Elixir.Supervisor.stop(sup)
    end
  end
end
