defmodule Raxol.Adaptive.Supervisor do
  @moduledoc """
  Supervisor for the adaptive UI subsystem.

  Children:
  1. BehaviorTracker -- records pilot interactions
  2. LayoutRecommender -- rule-based layout suggestions
  3. FeedbackLoop -- accept/reject tracking

  LayoutTransition is pure functional, no process needed.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    tracker_opts = Keyword.get(opts, :behavior_tracker, [])
    recommender_opts = Keyword.get(opts, :layout_recommender, [])
    feedback_opts = Keyword.get(opts, :feedback_loop, [])

    children = [
      {Raxol.Adaptive.BehaviorTracker, tracker_opts},
      {Raxol.Adaptive.LayoutRecommender, recommender_opts},
      {Raxol.Adaptive.FeedbackLoop, feedback_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
