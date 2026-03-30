defmodule Raxol.Adaptive.LayoutRecommender do
  @moduledoc """
  Rule-based layout recommendation engine.

  Subscribes to BehaviorTracker aggregates and applies heuristic
  rules to suggest layout changes. Emits recommendations to
  subscribers when confidence exceeds threshold and cooldown
  has elapsed.

  Cold start design: pure rule-based. No Nx dependency.
  Swap in an Nx model later by replacing `apply_rules/1`.
  """

  use GenServer

  @compile {:no_warn_undefined, Raxol.Adaptive.NxModel}

  require Logger

  @default_confidence_threshold 0.7
  @default_cooldown_ms 30_000

  @type change :: %{
          pane_id: atom(),
          action: :hide | :show | :expand | :shrink,
          params: map()
        }

  @type recommendation :: %{
          id: binary(),
          layout_changes: [change()],
          confidence: float(),
          reasoning: String.t(),
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          confidence_threshold: float(),
          recommendation_cooldown_ms: pos_integer(),
          last_recommendation_at: integer() | nil,
          last_recommendation: recommendation() | nil,
          subscribers: MapSet.t(pid()),
          pane_ids: [atom()],
          model_params: map() | nil
        }

  defstruct confidence_threshold: @default_confidence_threshold,
            recommendation_cooldown_ms: @default_cooldown_ms,
            last_recommendation_at: nil,
            last_recommendation: nil,
            subscribers: MapSet.new(),
            pane_ids: [],
            model_params: nil

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec get_last_recommendation(GenServer.server()) :: recommendation() | nil
  def get_last_recommendation(server \\ __MODULE__) do
    GenServer.call(server, :get_last_recommendation)
  end

  @spec set_pane_ids(GenServer.server(), [atom()]) :: :ok
  def set_pane_ids(server \\ __MODULE__, pane_ids) do
    GenServer.cast(server, {:set_pane_ids, pane_ids})
  end

  @spec set_model_params(GenServer.server(), map()) :: :ok
  def set_model_params(server \\ __MODULE__, params) do
    GenServer.cast(server, {:set_model_params, params})
  end

  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server \\ __MODULE__) do
    GenServer.call(server, {:subscribe, self()})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    state = %__MODULE__{
      confidence_threshold:
        Keyword.get(opts, :confidence_threshold, @default_confidence_threshold),
      recommendation_cooldown_ms:
        Keyword.get(opts, :recommendation_cooldown_ms, @default_cooldown_ms),
      pane_ids: Keyword.get(opts, :pane_ids, [])
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_last_recommendation, _from, %__MODULE__{} = state) do
    {:reply, state.last_recommendation, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, %__MODULE__{} = state) do
    Process.monitor(pid)

    {:reply, :ok,
     %__MODULE__{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  @impl true
  def handle_cast({:set_pane_ids, pane_ids}, %__MODULE__{} = state) do
    {:noreply, %__MODULE__{state | pane_ids: pane_ids}}
  end

  @impl true
  def handle_cast({:set_model_params, params}, %__MODULE__{} = state) do
    {:noreply, %__MODULE__{state | model_params: params}}
  end

  @impl true
  def handle_info({:behavior_aggregate, aggregate}, %__MODULE__{} = state) do
    now = System.monotonic_time(:millisecond)

    if on_cooldown?(state, now) do
      {:noreply, state}
    else
      case apply_rules(aggregate, state) do
        {:recommend, changes, confidence, reasoning}
        when confidence >= state.confidence_threshold ->
          rec =
            %{
              id: generate_id(),
              layout_changes: changes,
              confidence: confidence,
              reasoning: reasoning,
              timestamp: now
            }
            |> maybe_attach_features(aggregate, state)

          Enum.each(state.subscribers, fn pid ->
            send(pid, {:layout_recommendation, rec})
          end)

          state = %__MODULE__{
            state
            | last_recommendation: rec,
              last_recommendation_at: now
          }

          {:noreply, state}

        _ ->
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %__MODULE__{} = state) do
    {:noreply,
     %__MODULE__{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(msg, %__MODULE__{} = state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Private: Rules --

  # Internal type for rule candidates before selecting the best one.
  @typep candidate :: %{
           change: change(),
           confidence: float(),
           reasoning: String.t()
         }

  defp apply_rules(aggregate, state) do
    dwell_times = aggregate.pane_dwell_times
    total_dwell = dwell_times |> Map.values() |> Enum.sum()

    if total_dwell == 0 do
      :no_recommendation
    else
      case apply_nx_model(aggregate, state) do
        {:recommend, _, _, _} = result -> result
        _ -> apply_rule_heuristics(dwell_times, total_dwell, aggregate)
      end
    end
  end

  defp apply_nx_model(aggregate, %__MODULE__{
         model_params: params,
         pane_ids: pane_ids
       })
       when not is_nil(params) and pane_ids != [] do
    if Code.ensure_loaded?(Raxol.Adaptive.NxModel) do
      {features, ids} =
        Raxol.Adaptive.NxModel.extract_features(aggregate, pane_ids)

      predictions = Raxol.Adaptive.NxModel.predict(params, features)

      case Raxol.Adaptive.NxModel.interpret_predictions(predictions, ids) do
        [{pane_id, action, confidence} | _] ->
          change = %{
            pane_id: pane_id,
            action: action,
            params: %{source: :nx_model}
          }

          {:recommend, [change], confidence, "Nx model: #{action} #{pane_id}"}

        [] ->
          :no_recommendation
      end
    else
      :no_recommendation
    end
  end

  defp apply_nx_model(_aggregate, _state), do: :no_recommendation

  defp apply_rule_heuristics(dwell_times, total_dwell, aggregate) do
    case find_best_candidate(dwell_times, total_dwell, aggregate) do
      nil ->
        :no_recommendation

      %{change: change, confidence: confidence, reasoning: reasoning} ->
        {:recommend, [change], confidence, reasoning}
    end
  end

  @spec find_best_candidate(map(), float(), map()) :: candidate() | nil
  defp find_best_candidate(dwell_times, total_dwell, aggregate) do
    candidates =
      hide_candidates(dwell_times, total_dwell) ++
        expand_candidates(dwell_times, total_dwell) ++
        alert_candidates(aggregate)

    candidates
    |> Enum.sort_by(& &1.confidence, :desc)
    |> List.first()
  end

  defp hide_candidates(dwell_times, total_dwell) do
    Enum.flat_map(dwell_times, fn {pane_id, dwell} ->
      pct = dwell / total_dwell

      if pct < 0.05 do
        dwell_pct = Float.round(pct * 100, 1)

        [
          %{
            change: %{
              pane_id: pane_id,
              action: :hide,
              params: %{dwell_pct: dwell_pct}
            },
            confidence: 0.8,
            reasoning: "Pane #{pane_id} used <5% of session (#{dwell_pct}%)"
          }
        ]
      else
        []
      end
    end)
  end

  defp expand_candidates(dwell_times, total_dwell) do
    Enum.flat_map(dwell_times, fn {pane_id, dwell} ->
      pct = dwell / total_dwell

      if pct > 0.40 do
        dwell_pct = Float.round(pct * 100, 1)

        [
          %{
            change: %{
              pane_id: pane_id,
              action: :expand,
              params: %{dwell_pct: dwell_pct}
            },
            confidence: 0.85,
            reasoning: "Pane #{pane_id} used >40% of session (#{dwell_pct}%)"
          }
        ]
      else
        []
      end
    end)
  end

  defp alert_candidates(%{
         avg_alert_response_ms: avg_ms,
         least_used_panes: least_used
       })
       when avg_ms > 5000 do
    Enum.map(least_used, fn pane_id ->
      %{
        change: %{
          pane_id: pane_id,
          action: :show,
          params: %{avg_response_ms: Float.round(avg_ms, 0)}
        },
        confidence: 0.9,
        reasoning: "Alert response >5s (#{round(avg_ms)}ms), showing #{pane_id}"
      }
    end)
  end

  defp alert_candidates(_aggregate), do: []

  defp on_cooldown?(%__MODULE__{last_recommendation_at: nil}, _now), do: false

  defp on_cooldown?(%__MODULE__{} = state, now) do
    now - state.last_recommendation_at < state.recommendation_cooldown_ms
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp maybe_attach_features(rec, aggregate, %__MODULE__{pane_ids: pane_ids})
       when pane_ids != [] do
    if Code.ensure_loaded?(Raxol.Adaptive.NxModel) do
      {features, _ids} =
        Raxol.Adaptive.NxModel.extract_features(aggregate, pane_ids)

      Map.put(rec, :features, features)
    else
      rec
    end
  end

  defp maybe_attach_features(rec, _aggregate, _state), do: rec
end
