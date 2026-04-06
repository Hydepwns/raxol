defmodule Raxol.Payments.SpendingHookTest do
  use ExUnit.Case, async: false

  alias Raxol.Payments.{SpendingHook, SpendingPolicy, Ledger}
  alias Raxol.Core.Runtime.Command

  setup do
    {:ok, ledger} = Ledger.start_link(table_name: :"hook_ledger_#{:erlang.unique_integer()}")
    policy = SpendingPolicy.dev()

    SpendingHook.set_config(%{
      ledger: ledger,
      policy: policy
    })

    %{ledger: ledger, policy: policy}
  end

  describe "pre_execute/2" do
    test "allows non-payment commands" do
      command = %Command{type: :none, data: nil}
      assert {:ok, ^command} = SpendingHook.pre_execute(command, %{agent_id: :test})
    end

    test "allows async commands without payment data" do
      command = %Command{type: :async, data: fn _ -> :ok end}
      assert {:ok, ^command} = SpendingHook.pre_execute(command, %{agent_id: :test})
    end

    test "denies commands with unapproved domain" do
      config = SpendingHook.get_config()
      policy = %{config.policy | approved_domains: ["allowed.com"]}
      SpendingHook.set_config(%{config | policy: policy})

      command = %Command{
        type: :async,
        data: %{__payment__: %{amount: Decimal.new("0.01"), domain: "evil.com"}}
      }

      assert {:deny, {:domain_not_approved, "evil.com"}} =
               SpendingHook.pre_execute(command, %{agent_id: :test})
    end

    test "denies commands over per-request budget" do
      command = %Command{
        type: :async,
        data: %{__payment__: %{amount: Decimal.new("999.00"), domain: "api.test.com"}}
      }

      assert {:deny, {:over_budget, :per_request, _}} =
               SpendingHook.pre_execute(command, %{agent_id: :test})
    end
  end

  describe "post_execute/3" do
    test "records payment from data", %{ledger: ledger} do
      command = %Command{
        type: :async,
        data: %{
          __payment__: %{
            amount: Decimal.new("0.01"),
            domain: "api.test.com",
            agent_id: :test
          }
        }
      }

      assert {:ok, :result} = SpendingHook.post_execute(command, :result, %{agent_id: :test})
      :timer.sleep(10)

      entries = Ledger.get_history(ledger, :test)
      assert length(entries) == 1
    end

    test "passes through without payment data" do
      command = %Command{type: :none, data: nil}
      assert {:ok, :result} = SpendingHook.post_execute(command, :result, %{})
    end
  end
end
