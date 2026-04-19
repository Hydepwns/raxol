defmodule Raxol.Adaptive.Supervisor do
  @moduledoc """
  Supervisor for the adaptive UI subsystem.

  Children (started in order):
  1. BehaviorTracker -- records pilot interactions
  2. LayoutRecommender -- rule-based layout suggestions, auto-subscribes to BehaviorTracker
  3. FeedbackLoop -- accept/reject tracking, auto-subscribes to LayoutRecommender

  Subscriptions are wired automatically via `:subscribe_to` init options.
  LayoutTransition is pure functional, no process needed.
  """

  use Supervisor

  alias Raxol.Adaptive.{BehaviorTracker, FeedbackLoop, LayoutRecommender}

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

    tracker_name = Keyword.get(tracker_opts, :name, BehaviorTracker)
    recommender_name = Keyword.get(recommender_opts, :name, LayoutRecommender)

    # Auto-wire: recommender subscribes to tracker, feedback subscribes to recommender
    recommender_opts =
      Keyword.put_new(recommender_opts, :subscribe_to, tracker_name)

    feedback_opts =
      Keyword.put_new(feedback_opts, :subscribe_to, recommender_name)

    children = [
      {BehaviorTracker, tracker_opts},
      {LayoutRecommender, recommender_opts},
      {FeedbackLoop, feedback_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
