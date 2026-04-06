defmodule Raxol.Payments.SpendingPolicyTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.SpendingPolicy

  describe "dev/0" do
    test "returns sensible dev defaults" do
      policy = SpendingPolicy.dev()
      assert Decimal.equal?(policy.per_request_max, Decimal.new("0.10"))
      assert Decimal.equal?(policy.session_max, Decimal.new("1.00"))
      assert Decimal.equal?(policy.lifetime_max, Decimal.new("10.00"))
      assert policy.currency == "USDC"
    end
  end

  describe "unrestricted/0" do
    test "returns high limits" do
      policy = SpendingPolicy.unrestricted()
      assert Decimal.compare(policy.per_request_max, Decimal.new("1000000")) == :gt
    end
  end

  describe "domain_approved?/2" do
    test "approves all domains when list is nil" do
      policy = %SpendingPolicy{approved_domains: nil}
      assert SpendingPolicy.domain_approved?(policy, "anything.com")
    end

    test "approves matching domain" do
      policy = %SpendingPolicy{approved_domains: ["api.example.com"]}
      assert SpendingPolicy.domain_approved?(policy, "api.example.com")
    end

    test "approves subdomain matching" do
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      assert SpendingPolicy.domain_approved?(policy, "api.example.com")
    end

    test "rejects non-matching domain" do
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      refute SpendingPolicy.domain_approved?(policy, "evil.com")
    end
  end

  describe "requires_confirmation?/2" do
    test "returns false when threshold is nil" do
      policy = %SpendingPolicy{require_confirmation_above: nil}
      refute SpendingPolicy.requires_confirmation?(policy, Decimal.new("100"))
    end

    test "returns false when amount is below threshold" do
      policy = %SpendingPolicy{require_confirmation_above: Decimal.new("5.00")}
      refute SpendingPolicy.requires_confirmation?(policy, Decimal.new("3.00"))
    end

    test "returns true when amount exceeds threshold" do
      policy = %SpendingPolicy{require_confirmation_above: Decimal.new("5.00")}
      assert SpendingPolicy.requires_confirmation?(policy, Decimal.new("10.00"))
    end

    test "returns false when amount equals threshold" do
      policy = %SpendingPolicy{require_confirmation_above: Decimal.new("5.00")}
      refute SpendingPolicy.requires_confirmation?(policy, Decimal.new("5.00"))
    end
  end
end
