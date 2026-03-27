if Code.ensure_loaded?(Axon) do
  defmodule Raxol.Adaptive.NxModel do
    @moduledoc """
    Axon MLP for layout recommendation inference and training.

    Replaces the rule-based `LayoutRecommender.apply_rules/2` with a
    small neural network when Axon is available. The model processes
    per-pane features and predicts the best layout action.

    ## Features (per pane)

    - `dwell_pct` -- fraction of total dwell time spent on this pane
    - `is_most_used` -- 1.0 if this pane has the highest dwell time
    - `is_least_used` -- 1.0 if this pane is in the least-used set
    - `alert_response_norm` -- normalized average alert response time

    ## Actions

    `:hide`, `:show`, `:expand`, `:shrink`, `:none`
    """

    @feature_size 4
    @num_actions 5
    @actions [:hide, :show, :expand, :shrink, :none]

    @doc "Returns the ordered list of action atoms."
    @spec actions() :: [atom()]
    def actions, do: @actions

    @doc "Returns the number of input features per pane."
    @spec feature_size() :: pos_integer()
    def feature_size, do: @feature_size

    @doc """
    Build the Axon model graph.

    Architecture: input(4) -> dense(16, relu) -> dense(5, softmax)
    """
    @spec build_model() :: Axon.t()
    def build_model do
      Axon.input("features", shape: {nil, @feature_size})
      |> Axon.dense(16, activation: :relu)
      |> Axon.dense(@num_actions, activation: :softmax)
    end

    @doc "Returns the compiled {init_fn, predict_fn} pair, cached via persistent_term."
    @spec compiled_model() :: {function(), function()}
    def compiled_model do
      case :persistent_term.get({__MODULE__, :compiled}, nil) do
        nil ->
          compiled = Axon.build(build_model())
          :persistent_term.put({__MODULE__, :compiled}, compiled)
          compiled

        compiled ->
          compiled
      end
    end

    @doc "Initialize random model parameters."
    @spec init_params() :: map()
    def init_params do
      {init_fn, _predict_fn} = compiled_model()
      template = %{"features" => Nx.template({1, @feature_size}, :f32)}
      init_fn.(template, %{})
    end

    @doc "Run inference on feature tensor, returns action probabilities."
    @spec predict(map(), Nx.Tensor.t()) :: Nx.Tensor.t()
    def predict(params, features) do
      {_init_fn, predict_fn} = compiled_model()
      predict_fn.(params, %{"features" => features})
    end

    @doc """
    Extract per-pane feature tensors from a behavior aggregate.

    Returns `{features_tensor, pane_ids}` where features_tensor has
    shape `[n_panes, 4]`.
    """
    @spec extract_features(map(), [atom()]) :: {Nx.Tensor.t(), [atom()]}
    def extract_features(aggregate, pane_ids) do
      dwell_times = aggregate.pane_dwell_times
      total_dwell = dwell_times |> Map.values() |> Enum.sum()
      alert_ms = Map.get(aggregate, :avg_alert_response_ms, 0.0)
      alert_norm = min(alert_ms / 10_000.0, 1.0)
      least_used = Map.get(aggregate, :least_used_panes, [])

      {most_used_pane, _} =
        if map_size(dwell_times) > 0 do
          Enum.max_by(dwell_times, fn {_k, v} -> v end)
        else
          {nil, 0}
        end

      features_list =
        Enum.map(pane_ids, fn pane_id ->
          dwell = Map.get(dwell_times, pane_id, 0)
          dwell_pct = if total_dwell > 0, do: dwell / total_dwell, else: 0.0
          is_most = if pane_id == most_used_pane, do: 1.0, else: 0.0
          is_least = if pane_id in least_used, do: 1.0, else: 0.0
          [dwell_pct * 1.0, is_most, is_least, alert_norm * 1.0]
        end)

      {Nx.tensor(features_list, type: :f32), pane_ids}
    end

    @doc """
    Interpret model output into ranked pane action recommendations.

    Returns a list of `{pane_id, action, confidence}` tuples sorted
    by confidence descending, excluding `:none` actions.
    """
    @spec interpret_predictions(Nx.Tensor.t(), [atom()]) :: [
            {atom(), atom(), float()}
          ]
    def interpret_predictions(predictions, pane_ids) do
      pane_ids
      |> Enum.with_index()
      |> Enum.map(fn {pane_id, i} ->
        probs =
          predictions
          |> Nx.slice_along_axis(i, 1, axis: 0)
          |> Nx.reshape({@num_actions})

        action_idx = probs |> Nx.argmax() |> Nx.to_number()
        confidence = Nx.to_number(probs[action_idx])
        action = Enum.at(@actions, action_idx)
        {pane_id, action, confidence}
      end)
      |> Enum.reject(fn {_, action, _} -> action == :none end)
      |> Enum.sort_by(fn {_, _, conf} -> conf end, :desc)
    end

    @doc """
    Encode an action atom as a one-hot tensor of shape `{@num_actions}`.
    """
    @spec action_to_one_hot(atom()) :: Nx.Tensor.t()
    def action_to_one_hot(action) do
      idx = Enum.find_index(@actions, &(&1 == action)) || @num_actions - 1
      Nx.equal(Nx.iota({@num_actions}), idx) |> Nx.as_type(:f32)
    end

    @doc """
    Train the model on accumulated feedback data.

    `training_data` is a list of `{features_tensor, label_tensor}` tuples
    where features is `{1, 4}` and label is `{5}` (one-hot).

    Returns trained model parameters.
    """
    @spec train([{Nx.Tensor.t(), Nx.Tensor.t()}], keyword()) :: map()
    def train([_ | _] = training_data, opts \\ []) do
      epochs = Keyword.get(opts, :epochs, 50)
      batch_size = Keyword.get(opts, :batch_size, 8)

      model = build_model()
      n = length(training_data)
      actual_batch = min(batch_size, n)

      data_stream =
        Stream.repeatedly(fn ->
          batch = Enum.take_random(training_data, actual_batch)
          {features_list, labels_list} = Enum.unzip(batch)

          {
            %{"features" => Nx.concatenate(features_list, axis: 0)},
            Nx.stack(labels_list)
          }
        end)

      model
      |> Axon.Loop.trainer(
        :categorical_cross_entropy,
        Polaris.Optimizers.adam(learning_rate: 0.01)
      )
      |> Axon.Loop.run(data_stream, %{}, epochs: 1, iterations: epochs)
    end
  end
end
