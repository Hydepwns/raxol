defmodule Raxol.Payments.RouterTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Router

  describe "select/1" do
    test "defaults to x402 for same-chain" do
      assert Router.select() == :x402
      assert Router.select(cross_chain: false) == :x402
    end

    test "routes cross-chain to xochi" do
      assert Router.select(cross_chain: true) == :xochi
    end

    test "routes stealth privacy to xochi" do
      assert Router.select(privacy: :stealth) == :xochi
    end

    test "routes shielded privacy to xochi" do
      assert Router.select(privacy: :shielded) == :xochi
    end

    test "public privacy same-chain stays x402" do
      assert Router.select(privacy: :public, cross_chain: false) == :x402
    end

    test "forced protocol overrides routing" do
      assert Router.select(protocol: :mpp) == :mpp
      assert Router.select(protocol: :riddler, cross_chain: true) == :riddler
    end
  end
end
