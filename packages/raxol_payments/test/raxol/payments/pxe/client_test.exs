defmodule Raxol.Payments.Pxe.ClientTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Pxe.Client
  alias Raxol.Payments.Pxe.Schemas.CreateNoteParams

  @config %{url: "http://127.0.0.1:19999", api_key: "test-key", retry: false}

  @valid_params %CreateNoteParams{
    recipient: "0x" <> String.duplicate("ab", 32),
    token: "0x" <> String.duplicate("cd", 32),
    amount: "1000000",
    chain_id: 1
  }

  describe "create_note/2" do
    test "validates params before making RPC call" do
      bad_params = %{@valid_params | recipient: "0xshort"}
      assert {:error, {:invalid_recipient, _}} = Client.create_note(@config, bad_params)
    end

    test "returns connection error for unreachable host" do
      assert {:error, _reason} = Client.create_note(@config, @valid_params)
    end
  end

  describe "get_version/1" do
    test "returns connection error for unreachable host" do
      assert {:error, _reason} = Client.get_version(@config)
    end
  end

  describe "health/1" do
    test "returns connection error for unreachable host" do
      assert {:error, _reason} = Client.health(@config)
    end
  end

  describe "auth headers" do
    test "config without api_key still works" do
      config = %{url: "http://127.0.0.1:19999", retry: false}
      assert {:error, _reason} = Client.health(config)
    end

    test "config with nil api_key still works" do
      config = %{url: "http://127.0.0.1:19999", api_key: nil, retry: false}
      assert {:error, _reason} = Client.health(config)
    end
  end
end
