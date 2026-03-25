defmodule Raxol.Adaptive.FeedbackLoop do
  @moduledoc """
  Tracks pilot accept/reject decisions on layout recommendations.

  Maintains a feedback history and computes acceptance accuracy.
  Rule-based mode -- `force_retrain/1` is a stub for future Nx
  integration.
  """

  use GenServer

  require Logger

  @default_accuracy_window 100

  @type feedback :: %{
          recommendation_id: binary(),
          decision: :accepted | :rejected,
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          feedback_history: [feedback()],
          pending_recommendations: %{binary() => map()},
          accuracy_window: pos_integer()
        }

  defstruct feedback_history: [],
            pending_recommendations: %{},
            accuracy_window: @default_accuracy_window

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

  @spec force_retrain(GenServer.server()) :: {:ok, :rule_based_mode}
  def force_retrain(server \\ __MODULE__) do
    GenServer.call(server, :force_retrain)
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    accuracy_window =
      Keyword.get(opts, :accuracy_window, @default_accuracy_window)

    {:ok, %__MODULE__{accuracy_window: accuracy_window}}
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
    Logger.info("FeedbackLoop: rule-based mode, no model to train")
    {:reply, {:ok, :rule_based_mode}, state}
  end

  @impl true
  def handle_cast({:submit_recommendation, rec}, %__MODULE__{} = state) do
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

      {_rec, pending} ->
        feedback = %{
          recommendation_id: rec_id,
          decision: decision,
          timestamp: System.monotonic_time(:millisecond)
        }

        history =
          [feedback | state.feedback_history]
          |> Enum.take(state.accuracy_window)

        state = %__MODULE__{
          state
          | feedback_history: history,
            pending_recommendations: pending
        }

        {:reply, :ok, state}
    end
  end

  defp compute_accuracy([]), do: 0.0

  defp compute_accuracy(history) do
    accepted = Enum.count(history, fn f -> f.decision == :accepted end)
    accepted / length(history)
  end
end
