defmodule Raxol.Payments.Actions.Payments.Transfer do
  @compile {:no_warn_undefined, Raxol.Agent.Action}

  use Raxol.Agent.Action,
    name: "payment_transfer",
    description: "Transfer funds to an address (explicit payment, not auto-pay)",
    schema: [
      input: [
        to: [type: :string, required: true, description: "Recipient address (0x...)"],
        amount: [type: :string, required: true, description: "Amount to send"],
        currency: [type: :string, description: "Currency (default: USDC)"]
      ],
      output: [
        status: [type: :string],
        from: [type: :string],
        to: [type: :string],
        amount: [type: :string]
      ]
    ]

  alias Raxol.Payments.{Ledger, SpendingPolicy}

  @spec run(map(), map()) :: {:ok, map()} | {:error, term()}
  @impl true
  def run(%{to: to, amount: amount_str} = params, context) do
    case Map.fetch(context, :wallet) do
      {:ok, wallet} ->
        do_transfer(wallet, to, amount_str, params, context)

      :error ->
        {:error, :missing_wallet}
    end
  end

  defp do_transfer(wallet, to, amount_str, params, context) do
    currency = Map.get(params, :currency, "USDC")
    amount = Decimal.new(amount_str)

    with :ok <- check_budget(amount, context) do
      # Record the spend
      if ledger = Map.get(context, :ledger) do
        agent_id = Map.get(context, :agent_id, :unknown)

        Ledger.record_spend(ledger, agent_id, amount, %{
          to: to,
          currency: currency,
          type: :explicit_transfer
        })
      end

      {:ok,
       %{
         status: "pending",
         from: wallet.address(),
         to: to,
         amount: amount_str
       }}
    end
  end

  defp check_budget(amount, context) do
    case {Map.get(context, :ledger), Map.get(context, :policy)} do
      {nil, _} ->
        :ok

      {_ledger, nil} ->
        :ok

      {ledger, %SpendingPolicy{} = policy} ->
        agent_id = Map.get(context, :agent_id, :unknown)

        case Ledger.check_budget(ledger, agent_id, amount, policy) do
          :ok -> :ok
          {:over_limit, limit_type} -> {:error, {:over_budget, limit_type}}
        end
    end
  end
end
