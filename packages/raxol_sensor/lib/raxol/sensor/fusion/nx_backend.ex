if Code.ensure_loaded?(Nx) do
  defmodule Raxol.Sensor.Fusion.NxBackend do
    @moduledoc """
    Nx-accelerated sensor fusion operations.

    Replaces the pure-Elixir weighted averaging in `Sensor.Fusion`
    with vectorized Nx tensor operations. Only compiled when Nx is
    available as a dependency.
    """

    @epsilon 1.0e-10

    @doc """
    Compute weighted average of sensor readings using Nx tensors.

    Takes a list of value maps and a corresponding list of quality
    weights. Returns a single map of weighted-average values per key.

    Vectorized: builds a [n_readings, n_keys] matrix and a [n_readings]
    weight vector, then computes the dot product in one pass.
    """
    @spec weighted_average([map()], [number()]) :: map()
    def weighted_average([], _qualities), do: %{}

    def weighted_average(values_list, qualities) do
      total_quality = Enum.sum(qualities)

      if abs(total_quality) < @epsilon do
        hd(values_list)
      else
        keys =
          values_list
          |> Enum.flat_map(&Map.keys/1)
          |> Enum.uniq()
          |> Enum.sort()

        n = length(values_list)
        k = length(keys)

        values_matrix =
          Nx.tensor(
            Enum.map(values_list, fn vals ->
              Enum.map(keys, fn key ->
                case Map.get(vals, key) do
                  v when is_number(v) -> v * 1.0
                  _ -> 0.0
                end
              end)
            end),
            type: :f64
          )

        weights =
          qualities
          |> Nx.tensor(type: :f64)
          |> Nx.reshape({n, 1})
          |> Nx.divide(total_quality)

        # [1, k] = [1, n] @ [n, k]
        result =
          weights
          |> Nx.transpose()
          |> Nx.dot(values_matrix)
          |> Nx.reshape({k})

        keys
        |> Enum.with_index()
        |> Map.new(fn {key, i} ->
          {key, Nx.to_number(result[i])}
        end)
      end
    end
  end
end
