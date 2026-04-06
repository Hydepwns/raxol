defmodule Raxol.Payments.Xochi.Client do
  @moduledoc """
  Client for the Xochi private execution protocol.

  Xochi is the cash-positive, agent-facing intent protocol. Riddler
  solves intents behind the scenes. Agents route through Xochi for
  cross-chain transfers with tier-based fees.

  ## Endpoints

  - `quote/2` -- POST /api/intent/quote
  - `execute/2` -- POST /api/intent/execute
  - `get_status/2` -- GET /api/intent/:id/status
  - `get_history/2` -- GET /api/intent/history?wallet=

  ## Configuration

      config = %{
        base_url: "https://xochi.fi",
        auth_token: "jwt-or-api-key"
      }

      {:ok, quote} = Xochi.Client.quote(config, %QuoteRequest{...})
  """

  alias Raxol.Payments.Xochi.Schemas.{
    QuoteRequest,
    QuoteResponse,
    ExecuteRequest,
    ExecuteResponse,
    IntentStatus
  }

  @type config :: %{
          base_url: String.t(),
          auth_token: String.t()
        }

  @type error :: {:error, {:http, integer(), term()}} | {:error, term()}

  @doc "Request an intent quote."
  @spec get_quote(config(), QuoteRequest.t()) :: {:ok, QuoteResponse.t()} | error()
  def get_quote(config, %QuoteRequest{} = request) do
    config
    |> build_req()
    |> Req.post(url: "/api/intent/quote", json: QuoteRequest.to_json(request))
    |> handle_response(&QuoteResponse.from_json/1)
  end

  @doc "Execute a quoted intent with a signed payload."
  @spec execute(config(), ExecuteRequest.t()) :: {:ok, ExecuteResponse.t()} | error()
  def execute(config, %ExecuteRequest{} = request) do
    config
    |> build_req()
    |> Req.post(url: "/api/intent/execute", json: ExecuteRequest.to_json(request))
    |> handle_response(&ExecuteResponse.from_json/1)
  end

  @doc "Get intent status by ID."
  @spec get_status(config(), String.t()) :: {:ok, IntentStatus.t()} | error()
  def get_status(config, intent_id) do
    config
    |> build_req()
    |> Req.get(url: "/api/intent/#{intent_id}/status")
    |> handle_response(&IntentStatus.from_json/1)
  end

  @doc "Get intent history for a wallet."
  @spec get_history(config(), String.t(), keyword()) :: {:ok, [map()]} | error()
  def get_history(config, wallet, opts \\ []) do
    params = [wallet: wallet] ++ opts

    config
    |> build_req()
    |> Req.get(url: "/api/intent/history", params: params)
    |> handle_response(fn body ->
      Map.get(body, "intents", [])
    end)
  end

  # -- Private --

  defp build_req(config) do
    Req.new(
      base_url: config.base_url,
      headers: [{"authorization", "Bearer #{config.auth_token}"}],
      receive_timeout: 30_000
    )
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, transform)
       when status in 200..299 do
    {:ok, transform.(body)}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}, _transform) do
    {:error, {:http, status, body}}
  end

  defp handle_response({:error, reason}, _transform) do
    {:error, reason}
  end
end
