defmodule Raxol.Payments.Riddler.Client do
  @moduledoc """
  Elixir client for the Riddler Commerce API.

  Wraps the five Commerce endpoints with typed request/response schemas:
  - `get_chains/1` -- GET /commerce/chains
  - `get_routes/1` -- GET /commerce/routes
  - `get_quote/2` -- GET /commerce/quote
  - `submit_order/2` -- POST /commerce/order
  - `get_status/2` -- GET /commerce/status/{order_id}

  ## Configuration

      config = %{
        base_url: "https://riddler.example.com",
        api_key: "bearer-token-here"
      }

      {:ok, chains} = Riddler.Client.get_chains(config)
  """

  alias Raxol.Payments.Riddler.Schemas.{
    Chain,
    Route,
    QuoteRequest,
    QuoteResponse,
    OrderRequest,
    OrderStatus
  }

  @type config :: %{
          base_url: String.t(),
          api_key: String.t()
        }

  @type error :: {:error, {:http, integer(), term()}} | {:error, term()}

  @doc "List supported chains."
  @spec get_chains(config()) :: {:ok, [Chain.t()]} | error()
  def get_chains(config) do
    config
    |> build_req()
    |> Req.get(url: "/commerce/chains")
    |> handle_response(fn body ->
      body
      |> Map.get("data", [])
      |> Enum.map(&Chain.from_json/1)
    end)
  end

  @doc "List supported routes."
  @spec get_routes(config()) :: {:ok, [Route.t()]} | error()
  def get_routes(config) do
    config
    |> build_req()
    |> Req.get(url: "/commerce/routes")
    |> handle_response(fn body ->
      body
      |> Map.get("data", [])
      |> Enum.map(&Route.from_json/1)
    end)
  end

  @doc "Get a cross-chain transfer quote."
  @spec get_quote(config(), QuoteRequest.t()) :: {:ok, QuoteResponse.t()} | error()
  def get_quote(config, %QuoteRequest{} = request) do
    with :ok <- QuoteRequest.validate(request) do
      config
      |> build_req()
      |> Req.get(url: "/commerce/quote", params: QuoteRequest.to_query(request))
      |> handle_response(&QuoteResponse.from_json/1)
    end
  end

  @doc "Submit a signed order."
  @spec submit_order(config(), OrderRequest.t()) :: {:ok, map()} | error()
  def submit_order(config, %OrderRequest{} = request) do
    config
    |> build_req()
    |> Req.post(url: "/commerce/order", json: OrderRequest.to_json(request))
    |> handle_response(& &1)
  end

  @doc "Get order status by ID."
  @spec get_status(config(), String.t()) :: {:ok, OrderStatus.t()} | error()
  def get_status(config, order_id) do
    config
    |> build_req()
    |> Req.get(url: "/commerce/status/#{order_id}")
    |> handle_response(&OrderStatus.from_json/1)
  end

  # -- Private --

  defp build_req(config) do
    validate_base_url!(config.base_url)

    Req.new(
      base_url: config.base_url,
      headers: [{"authorization", "Bearer #{config.api_key}"}],
      receive_timeout: 15_000
    )
  end

  defp validate_base_url!("https://" <> _), do: :ok
  defp validate_base_url!("http://localhost" <> _), do: :ok
  defp validate_base_url!("http://127.0.0.1" <> _), do: :ok

  defp validate_base_url!(url) do
    raise ArgumentError, "Riddler client requires HTTPS base_url, got: #{inspect(url)}"
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
