defmodule Raxol.Adaptive.FeedbackLoop do
  @moduledoc """
  Tracks pilot accept/reject decisions on layout recommendations.

  Maintains a feedback history and computes acceptance accuracy.
  When accuracy drops below threshold and enough training data
  exists, triggers async NxModel retrain and broadcasts new params
  to the LayoutRecommender.
  """

  use GenServer

  @compile {:no_warn_undefined, Raxol.Adaptive.NxModel}

  require Logger

  @default_accuracy_window 100
  @max_training_examples 500
  @retrain_accuracy_threshold 0.6
  @retrain_min_examples 20

  @type feedback :: %{
          recommendation_id: binary(),
          decision: :accepted | :rejected,
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          feedback_history: [feedback()],
          pending_recommendations: %{binary() => map()},
          accuracy_window: pos_integer(),
          training_examples: [{term(), term()}],
          retrain_in_progress: boolean(),
          recommender_server: GenServer.server() | nil
        }

  defstruct feedback_history: [],
            pending_recommendations: %{},
            accuracy_window: @default_accuracy_window,
            training_examples: [],
            retrain_in_progress: false,
            recommender_server: nil

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec submit_recommendation(GenServer.server(), map()) :: :ok
  def submit_recommendation(server \\ __MODULE__, recommendation) do
    GenServer.cast(server, {:submit_recommendation, recommendation})
  end

  @spec accept(GenServer.server(), binary()) :: :ok | {:error, :not_found}
  def accept(server \\ __MODULE__, recommendation_id) do
    GenServer.call(server, {:accept, recommendation_id})
  end

  @spec reject(GenServer.server(), binary()) :: :ok | {:error, :not_found}
  def reject(server \\ __MODULE__, recommendation_id) do
    GenServer.call(server, {:reject, recommendation_id})
  end

  @spec get_accuracy(GenServer.server()) :: float()
  def get_accuracy(server \\ __MODULE__) do
    GenServer.call(server, :get_accuracy)
  end

  @spec get_history(GenServer.server(), pos_integer()) :: [feedback()]
  def get_history(server \\ __MODULE__, count \\ 20) do
    GenServer.call(server, {:get_history, count})
  end

  @spec force_retrain(GenServer.server()) ::
          {:ok, :rule_based_mode}
          | {:ok, :trained, map()}
          | {:ok, :insufficient_data}
  def force_retrain(server \\ __MODULE__) do
    GenServer.call(server, :force_retrain, 120_000)
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    accuracy_window =
      Keyword.get(opts, :accuracy_window, @default_accuracy_window)

    state = %__MODULE__{accuracy_window: accuracy_window}

    case Keyword.get(opts, :subscribe_to) do
      nil -> {:ok, state}
      target -> {:ok, state, {:continue, {:subscribe_to, target}}}
    end
  end

  @impl true
  def handle_continue({:subscribe_to, target}, %__MODULE__{} = state) do
    Raxol.Adaptive.LayoutRecommender.subscribe(target)
    {:noreply, %__MODULE__{state | recommender_server: target}}
  end

  @impl true
  def handle_call({:accept, rec_id}, _from, %__MODULE__{} = state) do
    record_decision(state, rec_id, :accepted)
  end

  @impl true
  def handle_call({:reject, rec_id}, _from, %__MODULE__{} = state) do
    record_decision(state, rec_id, :rejected)
  end

  @impl true
  def handle_call(:get_accuracy, _from, %__MODULE__{} = state) do
    accuracy = compute_accuracy(state.feedback_history)
    {:reply, accuracy, state}
  end

  @impl true
  def handle_call({:get_history, count}, _from, %__MODULE__{} = state) do
    {:reply, Enum.take(state.feedback_history, count), state}
  end

  @impl true
  def handle_call(:force_retrain, _from, %__MODULE__{} = state) do
    if Code.ensure_loaded?(Raxol.Adaptive.NxModel) do
      case state.training_examples do
        [_, _, _, _, _ | _] = examples ->
          Logger.info(
            "FeedbackLoop: training Nx model on #{length(examples)} examples"
          )

          params = Raxol.Adaptive.NxModel.train(examples)
          {:reply, {:ok, :trained, params}, state}

        _ ->
          Logger.info("FeedbackLoop: insufficient training data")
          {:reply, {:ok, :insufficient_data}, state}
      end
    else
      Logger.info("FeedbackLoop: rule-based mode, no model to train")
      {:reply, {:ok, :rule_based_mode}, state}
    end
  end

  @impl true
  def handle_cast({:submit_recommendation, rec}, %__MODULE__{} = state) do
    pending = Map.put(state.pending_recommendations, rec.id, rec)
    {:noreply, %__MODULE__{state | pending_recommendations: pending}}
  end

  @impl true
  def handle_info({:retrain_complete, params}, %__MODULE__{} = state) do
    Logger.info("FeedbackLoop: retrain complete, broadcasting new model params")

    if state.recommender_server do
      Raxol.Adaptive.LayoutRecommender.set_model_params(
        state.recommender_server,
        params
      )
    end

    {:noreply, %__MODULE__{state | retrain_in_progress: false}}
  end

  @impl true
  def handle_info({:layout_recommendation, rec}, %__MODULE__{} = state) do
    pending = Map.put(state.pending_recommendations, rec.id, rec)
    {:noreply, %__MODULE__{state | pending_recommendations: pending}}
  end

  @impl true
  def handle_info(msg, %__MODULE__{} = state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Private --

  defp record_decision(%__MODULE__{} = state, rec_id, decision) do
    case Map.pop(state.pending_recommendations, rec_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {rec, pending} ->
        feedback = %{
          recommendation_id: rec_id,
          decision: decision,
          timestamp: System.monotonic_time(:millisecond)
        }

        history =
          [feedback | state.feedback_history]
          |> Enum.take(state.accuracy_window)

        training_examples =
          maybe_add_training_example(
            state.training_examples,
            rec,
            decision
          )
          |> Enum.take(@max_training_examples)

        state = %__MODULE__{
          state
          | feedback_history: history,
            pending_recommendations: pending,
            training_examples: training_examples
        }

        state = maybe_trigger_retrain(state, history, training_examples)

        {:reply, :ok, state}
    end
  end

  defp maybe_trigger_retrain(
         %__MODULE__{retrain_in_progress: true} = state,
         _history,
         _examples
       ),
       do: state

  defp maybe_trigger_retrain(%__MODULE__{} = state, history, examples) do
    accuracy = compute_accuracy(history)

    if accuracy < @retrain_accuracy_threshold and
         length(examples) >= @retrain_min_examples and
         Code.ensure_loaded?(Raxol.Adaptive.NxModel) do
      parent = self()

      {:ok, _pid} =
        Task.start(fn ->
          Logger.info(
            "FeedbackLoop: auto-retrain triggered (accuracy=#{Float.round(accuracy * 100, 1)}%)"
          )

          params = Raxol.Adaptive.NxModel.train(examples)
          send(parent, {:retrain_complete, params})
        end)

      %__MODULE__{state | retrain_in_progress: true}
    else
      state
    end
  end

  defp maybe_add_training_example(examples, rec, decision) do
    with true <- Code.ensure_loaded?(Raxol.Adaptive.NxModel),
         features when not is_nil(features) <- Map.get(rec, :features) do
      action =
        if decision == :accepted,
          do: rec.layout_changes |> List.first() |> Map.get(:action, :none),
          else: :none

      label = Raxol.Adaptive.NxModel.action_to_one_hot(action)
      [{features, label} | examples]
    else
      _ -> examples
    end
  end

  defp compute_accuracy([]), do: 0.0

  defp compute_accuracy(history) do
    accepted = Enum.count(history, fn f -> f.decision == :accepted end)
    accepted / length(history)
  end
end
