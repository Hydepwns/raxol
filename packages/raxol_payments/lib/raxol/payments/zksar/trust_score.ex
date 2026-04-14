defmodule Raxol.Payments.Zksar.TrustScore do
  @moduledoc """
  Aggregates verified ZKSAR attestations into a 0-100 trust score
  using a diminishing-returns formula.

  Each proof type has a base weight. Proofs are sorted by weight
  descending, and each rank contributes less than the previous:

      score = sum(weight_i * diminishing(rank_i))

  where `diminishing(1) = 1.0` and `diminishing(i) = 1 / ln(i + 1)`
  for `i > 1`. This means the first proof gets full weight, the second
  gets ~91%, the third ~73%, and so on.
  """

  @type_weights %{
    non_membership: 25,
    compliance: 20,
    membership: 20,
    risk_score: 15,
    pattern: 15,
    attestation: 10
  }

  @max_score 100

  @doc """
  Compute aggregate trust score from verified proofs.

  ## Options

  - `:weights` -- override default type weights (map of type -> integer)
  - `:max_score` -- override maximum score (default: 100)
  """
  @spec aggregate([map()], keyword()) :: non_neg_integer()
  def aggregate(proofs, opts \\ [])

  def aggregate([], _opts), do: 0

  def aggregate(proofs, opts) when is_list(proofs) do
    weights = Keyword.get(opts, :weights, @type_weights)
    max = Keyword.get(opts, :max_score, @max_score)

    proofs
    |> Enum.map(fn %{type: type} -> Map.get(weights, type, 0) end)
    |> Enum.sort(:desc)
    |> Enum.with_index(1)
    |> Enum.reduce(0.0, fn {weight, rank}, acc ->
      acc + weight * diminishing(rank)
    end)
    |> round()
    |> min(max)
  end

  @doc "Default weight for a proof type."
  @spec weight(atom()) :: non_neg_integer()
  def weight(type), do: Map.get(@type_weights, type, 0)

  @doc "All default weights."
  @spec weights() :: map()
  def weights, do: @type_weights

  # -- Private --

  defp diminishing(1), do: 1.0
  defp diminishing(rank) when rank > 1, do: 1.0 / :math.log(rank + 1)
end
