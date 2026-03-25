defmodule Raxol.Adaptive.FeedbackLoopTest do
  use ExUnit.Case, async: true

  alias Raxol.Adaptive.FeedbackLoop

  setup do
    {:ok, pid} = FeedbackLoop.start_link(name: nil)
    %{loop: pid}
  end

  describe "accept/reject" do
    test "accepts a pending recommendation", %{loop: pid} do
      rec = %{id: "rec1", layout_changes: [], confidence: 0.8, reasoning: "test", timestamp: 0}
      FeedbackLoop.submit_recommendation(pid, rec)
      Process.sleep(10)

      assert :ok = FeedbackLoop.accept(pid, "rec1")
    end

    test "rejects a pending recommendation", %{loop: pid} do
      rec = %{id: "rec2", layout_changes: [], confidence: 0.8, reasoning: "test", timestamp: 0}
      FeedbackLoop.submit_recommendation(pid, rec)
      Process.sleep(10)

      assert :ok = FeedbackLoop.reject(pid, "rec2")
    end

    test "returns error for unknown recommendation", %{loop: pid} do
      assert {:error, :not_found} = FeedbackLoop.accept(pid, "nonexistent")
      assert {:error, :not_found} = FeedbackLoop.reject(pid, "nonexistent")
    end

    test "cannot accept same recommendation twice", %{loop: pid} do
      rec = %{id: "rec3", layout_changes: [], confidence: 0.8, reasoning: "test", timestamp: 0}
      FeedbackLoop.submit_recommendation(pid, rec)
      Process.sleep(10)

      :ok = FeedbackLoop.accept(pid, "rec3")
      assert {:error, :not_found} = FeedbackLoop.accept(pid, "rec3")
    end
  end

  describe "accuracy" do
    test "starts at 0.0", %{loop: pid} do
      assert FeedbackLoop.get_accuracy(pid) == 0.0
    end

    test "100% when all accepted", %{loop: pid} do
      for i <- 1..3 do
        id = "acc#{i}"
        FeedbackLoop.submit_recommendation(pid, %{id: id, layout_changes: [], confidence: 0.8, reasoning: "", timestamp: 0})
        Process.sleep(5)
        FeedbackLoop.accept(pid, id)
      end

      assert FeedbackLoop.get_accuracy(pid) == 1.0
    end

    test "0% when all rejected", %{loop: pid} do
      for i <- 1..3 do
        id = "rej#{i}"
        FeedbackLoop.submit_recommendation(pid, %{id: id, layout_changes: [], confidence: 0.8, reasoning: "", timestamp: 0})
        Process.sleep(5)
        FeedbackLoop.reject(pid, id)
      end

      assert FeedbackLoop.get_accuracy(pid) == 0.0
    end

    test "50% with mixed decisions", %{loop: pid} do
      FeedbackLoop.submit_recommendation(pid, %{id: "m1", layout_changes: [], confidence: 0.8, reasoning: "", timestamp: 0})
      FeedbackLoop.submit_recommendation(pid, %{id: "m2", layout_changes: [], confidence: 0.8, reasoning: "", timestamp: 0})
      Process.sleep(10)

      FeedbackLoop.accept(pid, "m1")
      FeedbackLoop.reject(pid, "m2")

      assert FeedbackLoop.get_accuracy(pid) == 0.5
    end
  end

  describe "history" do
    test "returns feedback history", %{loop: pid} do
      FeedbackLoop.submit_recommendation(pid, %{id: "h1", layout_changes: [], confidence: 0.8, reasoning: "", timestamp: 0})
      Process.sleep(10)
      FeedbackLoop.accept(pid, "h1")

      history = FeedbackLoop.get_history(pid, 10)
      assert length(history) == 1
      assert hd(history).decision == :accepted
      assert hd(history).recommendation_id == "h1"
    end
  end

  describe "force_retrain" do
    test "returns rule_based_mode stub", %{loop: pid} do
      assert {:ok, :rule_based_mode} = FeedbackLoop.force_retrain(pid)
    end
  end
end
