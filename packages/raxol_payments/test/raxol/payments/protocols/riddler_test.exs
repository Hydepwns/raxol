defmodule Raxol.Payments.Protocols.RiddlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Protocols.Riddler

  describe "Protocol behaviour stubs" do
    test "name returns Riddler" do
      assert Riddler.name() == "Riddler"
    end

    test "detect? always returns false" do
      refute Riddler.detect?(402, [{"payment-required", "test"}])
      refute Riddler.detect?(200, [])
    end

    test "parse_challenge returns not_a_402_protocol" do
      assert {:error, :not_a_402_protocol} = Riddler.parse_challenge([])
    end

    test "build_payment returns not_a_402_protocol" do
      assert {:error, :not_a_402_protocol} = Riddler.build_payment(%{}, MockWallet)
    end

    test "parse_receipt returns not_a_402_protocol" do
      assert {:error, :not_a_402_protocol} = Riddler.parse_receipt([])
    end
  end

  describe "amount/1" do
    test "extracts output_amount as Decimal" do
      assert Decimal.equal?(
               Riddler.amount(%{output_amount: "1000000"}),
               Decimal.new("1000000")
             )
    end

    test "returns zero for unknown shape" do
      assert Decimal.equal?(Riddler.amount(%{}), Decimal.new(0))
    end
  end
end
