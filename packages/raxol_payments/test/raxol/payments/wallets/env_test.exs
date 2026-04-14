defmodule Raxol.Payments.Wallets.EnvTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Wallets.Env

  # Hardhat account #0
  @test_env_var "TEST_WALLET_KEY"
  @test_privkey "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  @domain %{
    name: "Test",
    version: "1",
    chainId: 1,
    verifyingContract: "0x" <> String.duplicate("ab", 20)
  }

  @types %{"Transfer" => [{"to", "address"}, {"amount", "uint256"}]}

  setup do
    System.put_env(@test_env_var, @test_privkey)

    on_exit(fn ->
      System.delete_env(@test_env_var)
    end)

    :ok
  end

  describe "address/1" do
    test "returns checksummed 0x-prefixed 40-hex address" do
      address = Env.address(@test_env_var)
      assert String.starts_with?(address, "0x")
      hex = String.trim_leading(address, "0x")
      assert byte_size(hex) == 40
      assert match?({:ok, _}, Base.decode16(hex, case: :mixed))
    end

    test "raises when env var is not set" do
      System.delete_env(@test_env_var)

      assert_raise RuntimeError, ~r/Failed to derive address/, fn ->
        Env.address(@test_env_var)
      end
    end

    test "raises when hex is invalid" do
      System.put_env(@test_env_var, "not_hex_at_all")

      assert_raise RuntimeError, ~r/Failed to derive address/, fn ->
        Env.address(@test_env_var)
      end
    end
  end

  describe "eip712_hash/3" do
    test "valid typed data produces a 32-byte hash" do
      message = %{to: "0x" <> String.duplicate("cd", 20), amount: 1000}

      assert {:ok, hash} = Env.eip712_hash(@domain, @types, message)
      assert byte_size(hash) == 32
    end

    test "invalid hex in address field returns error" do
      message = %{to: "0xZZZZ", amount: 1000}

      assert {:error, {:invalid_hex, "address"}} =
               Env.eip712_hash(@domain, @types, message)
    end

    test "address with wrong byte length returns error" do
      # 10 bytes instead of 20
      short_addr = "0x" <> String.duplicate("ab", 10)
      message = %{to: short_addr, amount: 1000}

      assert {:error, {:invalid_address_length, 10}} =
               Env.eip712_hash(@domain, @types, message)
    end

    test "invalid uint256 string returns error" do
      types = %{"Transfer" => [{"to", "address"}, {"amount", "uint256"}]}
      message = %{to: "0x" <> String.duplicate("cd", 20), amount: "not_a_number"}

      assert {:error, {:invalid_uint256, "not_a_number"}} =
               Env.eip712_hash(@domain, types, message)
    end

    test "invalid hex in bytes32 field returns error" do
      types = %{"Record" => [{"hash", "bytes32"}]}
      message = %{hash: "0xNOTHEX"}

      assert {:error, {:invalid_hex, "bytes32"}} =
               Env.eip712_hash(%{name: "Test"}, types, message)
    end

    test "field name not an existing atom does not crash" do
      # Use a field name unlikely to exist as an atom
      novel_field = "zzz_never_atomized_#{System.unique_integer([:positive])}"
      types = %{"Foo" => [{novel_field, "uint256"}]}
      # Data keyed by string -- safe_atom_get will rescue ArgumentError and return nil
      message = %{}

      assert {:ok, hash} = Env.eip712_hash(%{name: "Test"}, types, message)
      assert byte_size(hash) == 32
    end
  end

  describe "sign_typed_data/4" do
    test "returns {:ok, signature} for valid data" do
      message = %{to: "0x" <> String.duplicate("cd", 20), amount: 1000}

      assert {:ok, sig} = Env.sign_typed_data(@domain, @types, message, @test_env_var)
      # r (32) + s (32) + v (1) = 65 bytes
      assert byte_size(sig) == 65
    end

    test "propagates eip712_hash errors for invalid address" do
      message = %{to: "0xZZZZ", amount: 1000}

      assert {:error, {:invalid_hex, "address"}} =
               Env.sign_typed_data(@domain, @types, message, @test_env_var)
    end

    test "returns error when env var not set" do
      System.delete_env(@test_env_var)
      message = %{to: "0x" <> String.duplicate("cd", 20), amount: 1000}

      assert {:error, {:env_not_set, @test_env_var}} =
               Env.sign_typed_data(@domain, @types, message, @test_env_var)
    end
  end
end
