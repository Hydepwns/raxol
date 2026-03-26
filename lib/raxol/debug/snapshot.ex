defmodule Raxol.Debug.Snapshot do
  @moduledoc """
  A single point-in-time capture of a TEA update cycle.

  Stores the message that triggered the update, the model before and after,
  and a monotonic timestamp for ordering. Provides a recursive map diff
  utility for inspecting what changed between any two models.
  """

  defstruct [
    :index,
    :timestamp_us,
    :message,
    :model_before,
    :model_after
  ]

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          timestamp_us: integer(),
          message: term(),
          model_before: map(),
          model_after: map()
        }

  @type change ::
          {:changed, [term()], old :: term(), new :: term()}
          | {:added, [term()], term()}
          | {:removed, [term()], term()}

  @doc "Creates a new snapshot."
  @spec new(non_neg_integer(), term(), map(), map()) :: t()
  def new(index, message, model_before, model_after) do
    %__MODULE__{
      index: index,
      timestamp_us: System.monotonic_time(:microsecond),
      message: message,
      model_before: model_before,
      model_after: model_after
    }
  end

  @doc """
  Computes the diff between two models (or two snapshots).

  Returns a list of `{:changed, path, old, new}`, `{:added, path, val}`,
  and `{:removed, path, val}` tuples where `path` is a list of map keys.

      iex> Snapshot.diff(%{a: 1, b: 2}, %{a: 1, b: 3, c: 4})
      [{:changed, [:b], 2, 3}, {:added, [:c], 4}]
  """
  @spec diff(map() | t(), map() | t()) :: [change()]
  def diff(%__MODULE__{model_after: a}, %__MODULE__{model_after: b}) do
    diff_maps(a, b, [])
  end

  def diff(%__MODULE__{} = snap, %{} = model) do
    diff_maps(snap.model_after, model, [])
  end

  def diff(%{} = a, %{} = b) do
    diff_maps(a, b, [])
  end

  @doc "Returns a compact summary string for a snapshot."
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{} = snap) do
    msg_str = inspect_short(snap.message, 60)
    changes = diff_maps(snap.model_before, snap.model_after, [])
    "##{snap.index} #{msg_str} (#{length(changes)} changes)"
  end

  @doc "Returns true if the model changed in this snapshot."
  @spec changed?(t()) :: boolean()
  def changed?(%__MODULE__{model_before: a, model_after: b}), do: a !== b

  # -- Private: recursive map diff --

  defp diff_maps(a, b, path) when is_map(a) and is_map(b) do
    all_keys = MapSet.union(map_keys(a), map_keys(b))

    Enum.flat_map(all_keys, fn key ->
      has_a = Map.has_key?(a, key)
      has_b = Map.has_key?(b, key)
      diff_key(has_a, has_b, key, a, b, path)
    end)
  end

  defp diff_maps(a, b, path) do
    if a === b, do: [], else: [{:changed, Enum.reverse(path), a, b}]
  end

  defp diff_key(true, true, key, a, b, path) do
    va = Map.get(a, key)
    vb = Map.get(b, key)

    if is_map(va) and is_map(vb) and not is_struct(va) and not is_struct(vb) do
      diff_maps(va, vb, [key | path])
    else
      if va === vb, do: [], else: [{:changed, Enum.reverse([key | path]), va, vb}]
    end
  end

  defp diff_key(true, false, key, a, _b, path) do
    [{:removed, Enum.reverse([key | path]), Map.get(a, key)}]
  end

  defp diff_key(false, true, key, _a, b, path) do
    [{:added, Enum.reverse([key | path]), Map.get(b, key)}]
  end

  defp map_keys(%{__struct__: _} = map), do: MapSet.new(Map.keys(Map.from_struct(map)))
  defp map_keys(map), do: MapSet.new(Map.keys(map))

  defp inspect_short(term, max_len) do
    str = inspect(term, limit: 5, printable_limit: max_len)

    if String.length(str) > max_len do
      String.slice(str, 0, max_len - 3) <> "..."
    else
      str
    end
  end
end
