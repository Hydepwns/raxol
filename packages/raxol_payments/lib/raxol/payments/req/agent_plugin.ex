defmodule Raxol.Payments.Req.AgentPlugin do
  @moduledoc """
  Builds a Req plugin function for use with `Raxol.Agent.Backend.HTTP`.

  Returns a function that attaches `AutoPay` to a Req request, suitable
  for passing as a `:req_plugins` entry to the agent backend.

  ## Usage

      alias Raxol.Payments.Req.AgentPlugin
      alias Raxol.Payments.{SpendingPolicy, Ledger}

      {:ok, ledger} = Ledger.start_link()

      plugin = AgentPlugin.auto_pay(
        wallet: Raxol.Payments.Wallets.Env,
        ledger: ledger,
        policy: SpendingPolicy.dev(),
        agent_id: :my_agent
      )

      # Pass to agent backend
      backend_opts = [
        api_key: "sk-...",
        req_plugins: [plugin]
      ]
  """

  alias Raxol.Payments.Req.AutoPay

  @doc """
  Build a Req plugin function that attaches auto-pay to HTTP requests.

  The returned function has the signature `(Req.Request.t() -> Req.Request.t())`
  and can be passed in the `:req_plugins` list to `Backend.HTTP`.

  ## Options

  Same as `Raxol.Payments.Req.AutoPay.attach/2`:

  - `:wallet` (required) -- module implementing `Raxol.Payments.Wallet`
  - `:protocols` -- list of protocol atoms, default `[:x402, :mpp]`
  - `:ledger` -- Ledger server for budget tracking (optional)
  - `:policy` -- `SpendingPolicy` struct (required if ledger given)
  - `:agent_id` -- identifier for ledger tracking (required if ledger given)
  """
  @spec auto_pay(keyword()) :: (Req.Request.t() -> Req.Request.t())
  def auto_pay(opts) do
    fn req -> AutoPay.attach(req, opts) end
  end
end
