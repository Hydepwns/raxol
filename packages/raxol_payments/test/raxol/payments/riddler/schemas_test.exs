defmodule Raxol.Payments.Riddler.SchemasTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Riddler.Schemas.{
    Chain,
    Route,
    QuoteRequest,
    QuoteResponse,
    OrderRequest,
    OrderStatus
  }

  describe "Chain.from_json/1" do
    test "parses chain data" do
      chain = Chain.from_json(%{"chainName" => "Base", "chainId" => 8453})
      assert chain.chain_name == "Base"
      assert chain.chain_id == 8453
    end
  end

  describe "Route.from_json/1" do
    test "parses route data" do
      route =
        Route.from_json(%{
          "fromChainId" => 1,
          "toChainId" => 8453,
          "fromAsset" => "0xA0b8",
          "toAsset" => "0x8335"
        })

      assert route.from_chain_id == 1
      assert route.to_chain_id == 8453
    end
  end

  describe "QuoteRequest.to_query/1" do
    test "converts to camelCase query params" do
      req = %QuoteRequest{
        refund_address: "0xabc",
        input_token: "0xA0b8",
        input_chain_id: 1,
        output_address: "0xdef",
        output_token: "0x8335",
        output_chain_id: 8453,
        input_amount: "1000000",
        gasless_or_deposit_address: "erc3009",
        expires: 1_700_000_000
      }

      query = QuoteRequest.to_query(req)

      assert Keyword.get(query, :refundAddress) == "0xabc"
      assert Keyword.get(query, :inputChainId) == 1
      assert Keyword.get(query, :outputChainId) == 8453
      assert Keyword.get(query, :gaslessOrDepositAddress) == "erc3009"
      assert Keyword.get(query, :expires) == 1_700_000_000
    end

    test "generates default expires when nil" do
      req = %QuoteRequest{
        refund_address: "0xabc",
        input_token: "0xA0b8",
        input_chain_id: 1,
        output_address: "0xdef",
        output_token: "0x8335",
        output_chain_id: 8453,
        input_amount: "1000000"
      }

      query = QuoteRequest.to_query(req)
      expires = Keyword.get(query, :expires)
      assert is_integer(expires)
      assert expires > :os.system_time(:second)
    end
  end

  describe "QuoteResponse.from_json/1" do
    test "parses quote response with deposit address" do
      json = %{
        "quoteId" => "quote_abc",
        "outputAmount" => "995000",
        "quoteExpires" => 1_700_000_300,
        "depositAddress" => %{"address" => "0xdep", "chainId" => 1}
      }

      resp = QuoteResponse.from_json(json)
      assert resp.quote_id == "quote_abc"
      assert resp.output_amount == "995000"
      assert resp.deposit_address["address"] == "0xdep"
    end

    test "parses gasless quote" do
      json = %{
        "quoteId" => "quote_gas",
        "outputAmount" => "990000",
        "quoteExpires" => 1_700_000_300,
        "gasless" => %{"type" => "erc3009", "to" => "0xsolver", "nonce" => "0xnonce1"}
      }

      resp = QuoteResponse.from_json(json)
      assert resp.gasless["type"] == "erc3009"
      assert resp.gasless["to"] == "0xsolver"
    end
  end

  describe "OrderRequest.to_json/1" do
    test "converts to JSON" do
      req = %OrderRequest{
        quote_id: "quote_abc",
        signed_object: "0xsigned",
        signature: "0xsig"
      }

      json = OrderRequest.to_json(req)
      assert json["quoteId"] == "quote_abc"
      assert json["signedObject"] == "0xsigned"
      refute Map.has_key?(json, "orderId")
    end

    test "includes orderId when set" do
      req = %OrderRequest{
        order_id: "order_123",
        quote_id: "q",
        signed_object: "0x",
        signature: "0x"
      }

      json = OrderRequest.to_json(req)
      assert json["orderId"] == "order_123"
    end
  end

  describe "OrderStatus.from_json/1" do
    test "parses completed order" do
      json = %{
        "orderId" => "order_1",
        "quoteId" => "quote_1",
        "status" => "completed",
        "inputChainId" => 1,
        "outputChainId" => 8453,
        "outputTransaction" => "0xtx"
      }

      status = OrderStatus.from_json(json)
      assert status.order_id == "order_1"
      assert status.status == :completed
      assert status.output_transaction == "0xtx"
      assert OrderStatus.terminal?(status)
    end

    test "non-terminal statuses" do
      for s <- ["pending", "received", "forwarding", "settling"] do
        json = %{"orderId" => "o", "status" => s}
        status = OrderStatus.from_json(json)
        refute OrderStatus.terminal?(status), "expected #{s} to be non-terminal"
      end
    end

    test "terminal statuses" do
      for s <- ["completed", "failed", "settlement_failed", "refunded", "expired"] do
        json = %{"orderId" => "o", "status" => s}
        status = OrderStatus.from_json(json)
        assert OrderStatus.terminal?(status), "expected #{s} to be terminal"
      end
    end
  end
end
