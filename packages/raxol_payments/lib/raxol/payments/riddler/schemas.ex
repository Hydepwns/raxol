defmodule Raxol.Payments.Riddler.Schemas do
  @moduledoc """
  Request/response schemas for the Riddler Commerce API (stub).

  Will define typed structs for quotes, orders, and status responses.
  This will be implemented in Phase B of the payments roadmap.
  """

  defmodule QuoteRequest do
    @moduledoc false
    defstruct [
      :refund_address,
      :input_token,
      :input_chain_id,
      :output_address,
      :output_token,
      :output_chain_id,
      :input_amount,
      :gasless_or_deposit_address,
      :expires,
      fallback: "refund"
    ]
  end

  defmodule QuoteResponse do
    @moduledoc false
    defstruct [
      :quote_id,
      :output_amount,
      :quote_expires,
      :request,
      :deposit_address,
      :gasless
    ]
  end

  defmodule OrderRequest do
    @moduledoc false
    defstruct [:order_id, :quote_id, :signed_object, :signature]
  end

  defmodule OrderStatus do
    @moduledoc false
    defstruct [:order_id, :status, :tx_hash, :output_amount, :settled_at]
  end
end
