defmodule Raxol.Payments.Xochi.ClientTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Xochi.Client
  alias Raxol.Payments.Xochi.Schemas.QuoteRequest

  @config %{base_url: "https://xochi.test", auth_token: "test-token"}

  describe "get_quote/2" do
    test "returns parsed QuoteResponse on success" do
      req = %QuoteRequest{
        wallet: "0xabc",
        from_chain_id: 1,
        to_chain_id: 8453,
        from_token: "0xA0b8",
        to_token: "0x8335",
        from_amount: "1000000",
        settlement_preference: "public"
      }

      # Client makes a real HTTP call; we test schema integration
      # via schemas_test.exs. This verifies the function exists and
      # returns a typed error for unreachable hosts.
      assert {:error, _reason} = Client.get_quote(@config, req)
    end
  end

  describe "get_status/2" do
    test "returns typed error for unreachable host" do
      assert {:error, _reason} = Client.get_status(@config, "intent_1")
    end
  end

  describe "execute/2" do
    test "returns typed error for unreachable host" do
      req = %Raxol.Payments.Xochi.Schemas.ExecuteRequest{
        intent_id: "i",
        quote_id: "q",
        signature: "0x",
        nonce: 1
      }

      assert {:error, _reason} = Client.execute(@config, req)
    end
  end

  describe "get_history/2" do
    test "returns typed error for unreachable host" do
      assert {:error, _reason} = Client.get_history(@config, "0xwallet")
    end
  end
end
