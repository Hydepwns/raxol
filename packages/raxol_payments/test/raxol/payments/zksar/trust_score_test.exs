defmodule Raxol.Payments.Zksar.TrustScoreTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Zksar.TrustScore

  defp verified(type),
    do: %{type: type, subject: "0x", issuer: "0x", issued_at: 0, expires_at: 0, valid: true}

  describe "aggregate/1" do
    test "empty list returns 0" do
      assert TrustScore.aggregate([]) == 0
    end

    test "single non_membership returns 25" do
      assert TrustScore.aggregate([verified(:non_membership)]) == 25
    end

    test "single compliance returns 20" do
      assert TrustScore.aggregate([verified(:compliance)]) == 20
    end

    test "single attestation returns 10" do
      assert TrustScore.aggregate([verified(:attestation)]) == 10
    end

    test "two proofs: second contributes less" do
      # non_membership (25) + membership (20 / ln(3) ~= 18.2) = ~43
      score = TrustScore.aggregate([verified(:non_membership), verified(:membership)])
      assert score == 43
    end

    test "diminishing returns: contributions decrease with rank" do
      one = TrustScore.aggregate([verified(:non_membership)])
      two = TrustScore.aggregate([verified(:non_membership), verified(:compliance)])

      three =
        TrustScore.aggregate([
          verified(:non_membership),
          verified(:compliance),
          verified(:membership)
        ])

      # Each addition contributes less
      delta_2 = two - one
      delta_3 = three - two
      assert delta_2 > delta_3
    end

    test "all six types produce score capped at 100" do
      all = [
        verified(:non_membership),
        verified(:compliance),
        verified(:membership),
        verified(:risk_score),
        verified(:pattern),
        verified(:attestation)
      ]

      score = TrustScore.aggregate(all)
      assert score > 0
      assert score <= 100
    end

    test "custom weights override defaults" do
      proofs = [verified(:compliance)]
      assert TrustScore.aggregate(proofs, weights: %{compliance: 50}) == 50
    end

    test "custom max_score caps result" do
      proofs = [verified(:non_membership), verified(:compliance), verified(:membership)]
      assert TrustScore.aggregate(proofs, max_score: 30) == 30
    end
  end

  describe "weight/1" do
    test "returns known weight for type" do
      assert TrustScore.weight(:non_membership) == 25
      assert TrustScore.weight(:compliance) == 20
      assert TrustScore.weight(:attestation) == 10
    end

    test "returns 0 for unknown type" do
      assert TrustScore.weight(:bogus) == 0
    end
  end
end
