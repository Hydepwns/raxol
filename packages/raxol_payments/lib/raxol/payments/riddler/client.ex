defmodule Raxol.Payments.Riddler.Client do
  @moduledoc """
  Elixir client for the Riddler Commerce API (stub).

  Will mirror the TypeScript SDK with endpoints:
  - `get_chains/1` -- GET /commerce/chains
  - `get_routes/1` -- GET /commerce/routes
  - `get_quote/2` -- GET /commerce/quote
  - `submit_order/2` -- POST /commerce/order
  - `get_status/2` -- GET /commerce/status/{order_id}

  This will be implemented in Phase B of the payments roadmap.
  """

  @type config :: %{
          base_url: String.t(),
          api_key: String.t()
        }

  @doc "List supported chains."
  @spec get_chains(config()) :: {:ok, list()} | {:error, term()}
  def get_chains(_config), do: {:error, :not_implemented}

  @doc "List supported routes."
  @spec get_routes(config()) :: {:ok, list()} | {:error, term()}
  def get_routes(_config), do: {:error, :not_implemented}

  @doc "Get a cross-chain transfer quote."
  @spec get_quote(config(), map()) :: {:ok, map()} | {:error, term()}
  def get_quote(_config, _params), do: {:error, :not_implemented}

  @doc "Submit a signed order."
  @spec submit_order(config(), map()) :: {:ok, map()} | {:error, term()}
  def submit_order(_config, _params), do: {:error, :not_implemented}

  @doc "Get order status by ID."
  @spec get_status(config(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_status(_config, _order_id), do: {:error, :not_implemented}
end
