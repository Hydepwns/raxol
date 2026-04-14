defmodule Raxol.Payments.Req.AutoPay do
  @moduledoc """
  Req plugin that transparently handles HTTP 402 Payment Required responses.

  Intercepts 402 responses, detects the payment protocol (x402 or MPP),
  checks spending budget, signs a payment, and retries the request with
  payment credentials attached. Retries at most once per request to
  prevent infinite loops.

  ## Usage

      req =
        Req.new(url: "https://api.example.com/data")
        |> Raxol.Payments.Req.AutoPay.attach(
          wallet: Raxol.Payments.Wallets.Env,
          protocols: [:x402, :mpp],
          ledger: ledger_pid,
          policy: SpendingPolicy.dev(),
          agent_id: :my_agent
        )

      {:ok, response} = Req.get(req)

  ## Options

  - `:wallet` (required) -- module implementing `Raxol.Payments.Wallet`
  - `:protocols` -- list of protocol atoms, default `[:x402, :mpp]`
  - `:ledger` -- Ledger server for budget tracking (optional)
  - `:policy` -- `SpendingPolicy` struct (required if ledger given)
  - `:agent_id` -- identifier for ledger tracking (required if ledger given)
  """

  alias Raxol.Payments.{Protocol, Ledger, SpendingPolicy}

  @default_protocols [:x402, :mpp]

  @doc """
  Attach the auto-pay plugin to a Req request.
  """
  @spec attach(Req.Request.t(), keyword()) :: Req.Request.t()
  def attach(%Req.Request{} = req, opts) do
    Req.Request.append_response_steps(req, auto_pay: &handle_response(&1, opts))
  end

  @spec handle_response({Req.Request.t(), Req.Response.t()}, keyword()) ::
          {Req.Request.t(), Req.Response.t()}
  defp handle_response({request, %Req.Response{status: 402} = response}, opts) do
    wallet = Keyword.fetch!(opts, :wallet)
    protocols = Keyword.get(opts, :protocols, @default_protocols)
    headers = Raxol.Payments.Headers.flatten(response.headers)

    with {:ok, protocol_mod, challenge} <- detect_and_parse(protocols, headers),
         :ok <- try_spend_budget(protocol_mod, challenge, opts),
         {:ok, payment_headers} <- protocol_mod.build_payment(challenge, wallet) do
      # Build retry request: add payment headers and strip the auto_pay step
      # to prevent infinite loops if the server returns 402 again.
      retry_request =
        request
        |> add_payment_headers(payment_headers)
        |> remove_auto_pay_step()

      case Req.Request.run(retry_request) do
        {_req, %Req.Response{status: status} = paid_response} when status in 200..299 ->
          {request, paid_response}

        {_req, %Req.Response{} = failed_response} ->
          {request, failed_response}

        {:error, reason} ->
          {request, %{response | body: %{error: :payment_retry_failed, reason: reason}}}
      end
    else
      {:error, :no_matching_protocol} ->
        {request, response}

      {:error, {:over_budget, _limit_type, _amount}} = err ->
        {request, %{response | body: %{error: :budget_exceeded, details: err}}}

      {:error, reason} ->
        {request, %{response | body: %{error: :payment_failed, reason: reason}}}
    end
  end

  defp handle_response(req_response, _opts), do: req_response

  @spec detect_and_parse([atom()], Raxol.Payments.Headers.headers()) ::
          {:ok, module(), map()} | {:error, :no_matching_protocol}
  defp detect_and_parse(protocols, headers) do
    Enum.find_value(protocols, {:error, :no_matching_protocol}, fn proto_atom ->
      mod = Protocol.resolve(proto_atom)

      if mod.detect?(402, headers) do
        case mod.parse_challenge(headers) do
          {:ok, challenge} -> {:ok, mod, challenge}
          {:error, _} -> nil
        end
      end
    end)
  end

  @spec try_spend_budget(module(), map(), keyword()) :: :ok | {:error, term()}
  defp try_spend_budget(protocol_mod, challenge, opts) do
    case {Keyword.get(opts, :ledger), Keyword.get(opts, :policy)} do
      {nil, _} ->
        :ok

      {_ledger, nil} ->
        :ok

      {ledger, %SpendingPolicy{} = policy} ->
        agent_id = Keyword.get(opts, :agent_id, :unknown)
        amount = protocol_mod.amount(challenge)

        metadata = %{
          protocol: protocol_mod.name(),
          domain: "pending"
        }

        case Ledger.try_spend(ledger, agent_id, amount, policy, metadata) do
          :ok -> :ok
          {:over_limit, limit_type} -> {:error, {:over_budget, limit_type, amount}}
        end
    end
  end

  defp add_payment_headers(request, headers) do
    Enum.reduce(headers, request, fn {key, value}, req ->
      Req.Request.put_header(req, key, value)
    end)
  end

  defp remove_auto_pay_step(request) do
    steps =
      request.response_steps
      |> Enum.reject(fn {name, _fun} -> name == :auto_pay end)

    %{request | response_steps: steps}
  end
end
