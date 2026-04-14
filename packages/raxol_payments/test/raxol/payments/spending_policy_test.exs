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

    test "approves exact domain match" do
      policy = %SpendingPolicy{approved_domains: ["api.example.com"]}
      assert SpendingPolicy.domain_approved?(policy, "api.example.com")
    end

    test "approves subdomain of approved domain" do
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      assert SpendingPolicy.domain_approved?(policy, "api.example.com")
    end

    test "rejects non-matching domain" do
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      refute SpendingPolicy.domain_approved?(policy, "evil.com")
    end

    test "rejects domain that shares suffix but not boundary" do
      # evil-example.com should NOT match example.com
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      refute SpendingPolicy.domain_approved?(policy, "evil-example.com")
    end

    test "rejects domain that is a prefix of approved domain" do
      policy = %SpendingPolicy{approved_domains: ["api.example.com"]}
      refute SpendingPolicy.domain_approved?(policy, "example.com")
    end

    test "matching is case-insensitive" do
      policy = %SpendingPolicy{approved_domains: ["Example.Com"]}
      assert SpendingPolicy.domain_approved?(policy, "API.EXAMPLE.COM")
    end

    test "rejects empty string domain" do
      policy = %SpendingPolicy{approved_domains: ["example.com"]}
      refute SpendingPolicy.domain_approved?(policy, "")
    end

    test "empty approved list rejects all" do
      policy = %SpendingPolicy{approved_domains: []}
      refute SpendingPolicy.domain_approved?(policy, "example.com")
    end

    test "empty string in approved list is ignored" do
      policy = %SpendingPolicy{approved_domains: [""]}
      refute SpendingPolicy.domain_approved?(policy, "anything.com")
    end

    test "works with production domains" do
      policy = %SpendingPolicy{approved_domains: ["xochi.fi", "axol.io", "raxol.io"]}

      assert SpendingPolicy.domain_approved?(policy, "xochi.fi")
      assert SpendingPolicy.domain_approved?(policy, "api.xochi.fi")
      assert SpendingPolicy.domain_approved?(policy, "axol.io")
      assert SpendingPolicy.domain_approved?(policy, "payments.axol.io")
      assert SpendingPolicy.domain_approved?(policy, "raxol.io")
      assert SpendingPolicy.domain_approved?(policy, "mcp.raxol.io")

      refute SpendingPolicy.domain_approved?(policy, "evil-xochi.fi")
      refute SpendingPolicy.domain_approved?(policy, "notaxol.io")
      refute SpendingPolicy.domain_approved?(policy, "fakeraxol.io")
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
