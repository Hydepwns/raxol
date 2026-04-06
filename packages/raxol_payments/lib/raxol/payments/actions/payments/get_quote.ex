defmodule Raxol.Payments.Actions.Payments.GetQuote do
  @compile {:no_warn_undefined, Raxol.Agent.Action}

  use Raxol.Agent.Action,
    name: "payment_get_quote",
    description: "Probe a URL to check if it requires payment and get pricing",
    schema: [
      input: [
        url: [type: :string, required: true, description: "URL to probe for 402 pricing"],
        method: [type: :string, description: "HTTP method (default: GET)"]
      ],
      output: [
        requires_payment: [type: :boolean],
        price: [type: :string],
        currency: [type: :string],
        network: [type: :string],
        protocol: [type: :string]
      ]
    ]

  @spec run(map(), map()) :: {:ok, map()} | {:error, term()}
  @impl true
  def run(%{url: url} = params, _context) do
    method = Map.get(params, :method, "GET")

    case probe_url(url, method) do
      {:ok, :free} ->
        {:ok, %{requires_payment: false, price: nil, currency: nil, network: nil, protocol: nil}}

      {:ok, {protocol_mod, challenge}} ->
        {:ok,
         %{
           requires_payment: true,
           price: to_string(protocol_mod.amount(challenge)),
           currency: Map.get(challenge, :currency, "USDC"),
           network: Map.get(challenge, :network),
           protocol: protocol_mod.name()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp probe_url(url, method) do
    if Code.ensure_loaded?(Req) do
      req_method = String.downcase(method) |> String.to_existing_atom()

      case apply(Req, req_method, url: url) do
        {:ok, %{status: 402} = response} ->
          headers = Raxol.Payments.Headers.flatten(response.headers)
          detect_protocol(headers)

        {:ok, %{status: status}} when status in 200..299 ->
          {:ok, :free}

        {:ok, %{status: status}} ->
          {:error, {:unexpected_status, status}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    else
      {:error, :req_not_available}
    end
  end

  defp detect_protocol(headers) do
    protocols = [:x402, :mpp]

    Enum.find_value(protocols, {:error, :unknown_402_protocol}, fn proto_atom ->
      mod = Raxol.Payments.Protocol.resolve(proto_atom)

      if mod.detect?(402, headers) do
        case mod.parse_challenge(headers) do
          {:ok, challenge} -> {:ok, {mod, challenge}}
          _ -> nil
        end
      end
    end)
  end
end
