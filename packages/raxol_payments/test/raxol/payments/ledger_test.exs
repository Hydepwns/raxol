defmodule Raxol.Payments.LedgerTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.{Ledger, SpendingPolicy}

  setup do
    {:ok, ledger} = Ledger.start_link(table_name: :"ledger_#{:erlang.unique_integer()}")
    %{ledger: ledger}
  end

  describe "record_spend/4 and get_history/3" do
    test "records and retrieves spend entries", %{ledger: ledger} do
      :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.05"), %{domain: "api.test.com"})

      # Give cast time to process
      :timer.sleep(10)

      entries = Ledger.get_history(ledger, "agent_1")
      assert length(entries) == 1
      assert Decimal.equal?(hd(entries).amount, Decimal.new("0.05"))
    end

    test "returns empty list for unknown agent", %{ledger: ledger} do
      assert Ledger.get_history(ledger, "unknown") == []
    end

    test "respects limit option", %{ledger: ledger} do
      for i <- 1..5 do
        :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.01"), %{i: i})
      end

      :timer.sleep(10)

      entries = Ledger.get_history(ledger, "agent_1", limit: 3)
      assert length(entries) == 3
    end
  end

  describe "check_budget/4" do
    test "allows spend within limits", %{ledger: ledger} do
      policy = %SpendingPolicy{
        per_request_max: Decimal.new("1.00"),
        session_max: Decimal.new("10.00"),
        lifetime_max: Decimal.new("100.00"),
        session_window_ms: 3_600_000
      }

      assert :ok = Ledger.check_budget(ledger, "agent_1", Decimal.new("0.50"), policy)
    end

    test "denies per-request over limit", %{ledger: ledger} do
      policy = %SpendingPolicy{
        per_request_max: Decimal.new("0.10"),
        session_max: Decimal.new("10.00"),
        lifetime_max: Decimal.new("100.00"),
        session_window_ms: 3_600_000
      }

      assert {:over_limit, :per_request} =
               Ledger.check_budget(ledger, "agent_1", Decimal.new("0.50"), policy)
    end

    test "denies session over limit", %{ledger: ledger} do
      policy = %SpendingPolicy{
        per_request_max: Decimal.new("1.00"),
        session_max: Decimal.new("0.10"),
        lifetime_max: Decimal.new("100.00"),
        session_window_ms: 3_600_000
      }

      :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.08"), %{})
      :timer.sleep(10)

      assert {:over_limit, :session} =
               Ledger.check_budget(ledger, "agent_1", Decimal.new("0.05"), policy)
    end

    test "denies lifetime over limit", %{ledger: ledger} do
      policy = %SpendingPolicy{
        per_request_max: Decimal.new("1.00"),
        session_max: Decimal.new("100.00"),
        lifetime_max: Decimal.new("0.10"),
        session_window_ms: 3_600_000
      }

      :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.08"), %{})
      :timer.sleep(10)

      assert {:over_limit, :lifetime} =
               Ledger.check_budget(ledger, "agent_1", Decimal.new("0.05"), policy)
    end
  end

  describe "get_totals/3" do
    test "returns session and lifetime totals", %{ledger: ledger} do
      policy = %SpendingPolicy{
        per_request_max: Decimal.new("10.00"),
        session_max: Decimal.new("100.00"),
        lifetime_max: Decimal.new("1000.00"),
        session_window_ms: 3_600_000
      }

      :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.05"), %{})
      :ok = Ledger.record_spend(ledger, "agent_1", Decimal.new("0.10"), %{})
      :timer.sleep(10)

      totals = Ledger.get_totals(ledger, "agent_1", policy)
      assert Decimal.equal?(totals.session, Decimal.new("0.15"))
      assert Decimal.equal?(totals.lifetime, Decimal.new("0.15"))
    end

    test "returns zero for unknown agent", %{ledger: ledger} do
      policy = SpendingPolicy.dev()
      totals = Ledger.get_totals(ledger, "unknown", policy)
      assert Decimal.equal?(totals.session, Decimal.new("0"))
      assert Decimal.equal?(totals.lifetime, Decimal.new("0"))
    end
  end
end
