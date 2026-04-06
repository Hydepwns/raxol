defmodule Raxol.Payments.Protocols.MPPTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Protocols.MPP

  describe "detect?/2" do
    test "detects WWW-Authenticate Payment header" do
      headers = [{"www-authenticate", "Payment eyJ0ZXN0IjogdHJ1ZX0="}]
      assert MPP.detect?(402, headers)
    end

    test "detects case-insensitive header" do
      headers = [{"WWW-Authenticate", "Payment eyJ0ZXN0IjogdHJ1ZX0="}]
      assert MPP.detect?(402, headers)
    end

    test "returns false for non-Payment auth scheme" do
      headers = [{"www-authenticate", "Bearer realm=test"}]
      refute MPP.detect?(402, headers)
    end

    test "returns false for non-402 status" do
      headers = [{"www-authenticate", "Payment eyJ0ZXN0IjogdHJ1ZX0="}]
      refute MPP.detect?(200, headers)
    end

    test "returns false without auth header" do
      headers = [{"content-type", "application/json"}]
      refute MPP.detect?(402, headers)
    end
  end

  describe "parse_challenge/1" do
    test "decodes challenge from auth header" do
      payload =
        Jason.encode!(%{
          "amount" => "100",
          "currency" => "USDC",
          "recipient" => "0xabcdef1234567890abcdef1234567890abcdef12",
          "methods" => ["tempo", "stripe"],
          "network" => "tempo:mainnet",
          "nonce" => "abc123"
        })

      encoded = Base.encode64(payload)
      headers = [{"www-authenticate", "Payment " <> encoded}]

      assert {:ok, challenge} = MPP.parse_challenge(headers)
      assert challenge.amount == "100"
      assert challenge.currency == "USDC"
      assert challenge.recipient == "0xabcdef1234567890abcdef1234567890abcdef12"
      assert challenge.methods == ["tempo", "stripe"]
      assert challenge.nonce == "abc123"
    end

    test "returns error for missing header" do
      assert {:error, {:missing_header, "www-authenticate"}} = MPP.parse_challenge([])
    end
  end

  describe "amount/1" do
    test "returns Decimal from string amount" do
      challenge = %{amount: "0.05"}
      assert Decimal.equal?(MPP.amount(challenge), Decimal.new("0.05"))
    end
  end

  describe "parse_receipt/1" do
    test "decodes base64 JSON receipt" do
      payload =
        Jason.encode!(%{
          "transactionHash" => "0xcafebabe",
          "amount" => "100",
          "method" => "tempo",
          "success" => true
        })

      encoded = Base.encode64(payload)
      headers = [{"payment-receipt", encoded}]

      assert {:ok, receipt} = MPP.parse_receipt(headers)
      assert receipt.tx_hash == "0xcafebabe"
      assert receipt.amount == "100"
      assert receipt.method == "tempo"
      assert receipt.success == true
    end

    test "returns error for missing header" do
      assert {:error, :no_receipt} = MPP.parse_receipt([])
    end
  end
end
