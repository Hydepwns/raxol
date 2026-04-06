defmodule Raxol.Payments.Actions.Payments.SpendingStatus do
  @compile {:no_warn_undefined, Raxol.Agent.Action}

  use Raxol.Agent.Action,
    name: "payment_spending_status",
    description: "Check current spending against budget limits",
    schema: [
      input: [],
      output: [
        session_spent: [type: :string],
        lifetime_spent: [type: :string],
        session_limit: [type: :string],
        lifetime_limit: [type: :string],
        session_remaining: [type: :string],
        lifetime_remaining: [type: :string],
        currency: [type: :string]
      ]
    ]

  alias Raxol.Payments.{Ledger, SpendingPolicy}

  @spec run(map(), map()) :: {:ok, map()} | {:error, term()}
  @impl true
  def run(_params, context) do
    case {Map.get(context, :ledger), Map.get(context, :policy)} do
      {nil, _} ->
        {:ok, no_ledger_response()}

      {_ledger, nil} ->
        {:ok, no_ledger_response()}

      {ledger, %SpendingPolicy{} = policy} ->
        agent_id = Map.get(context, :agent_id, :unknown)
        totals = Ledger.get_totals(ledger, agent_id, policy)

        {:ok,
         %{
           session_spent: Decimal.to_string(totals.session),
           lifetime_spent: Decimal.to_string(totals.lifetime),
           session_limit: Decimal.to_string(policy.session_max),
           lifetime_limit: Decimal.to_string(policy.lifetime_max),
           session_remaining: Decimal.to_string(Decimal.sub(policy.session_max, totals.session)),
           lifetime_remaining:
             Decimal.to_string(Decimal.sub(policy.lifetime_max, totals.lifetime)),
           currency: policy.currency
         }}
    end
  end

  defp no_ledger_response do
    %{
      session_spent: "0",
      lifetime_spent: "0",
      session_limit: "unlimited",
      lifetime_limit: "unlimited",
      session_remaining: "unlimited",
      lifetime_remaining: "unlimited",
      currency: "USDC"
    }
  end
end
