defmodule Raxol.Payments.Pxe.SchemasTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Pxe.Schemas.{CreateNoteParams, CreateNoteResult, HealthStatus}

  describe "CreateNoteParams.validate/1" do
    @valid_params %CreateNoteParams{
      recipient: "0x" <> String.duplicate("ab", 32),
      token: "0x" <> String.duplicate("cd", 32),
      amount: "1000000",
      chain_id: 1
    }

    test "accepts valid params" do
      assert :ok = CreateNoteParams.validate(@valid_params)
    end

    test "rejects short recipient address" do
      params = %{@valid_params | recipient: "0xabc"}
      assert {:error, {:invalid_recipient, _}} = CreateNoteParams.validate(params)
    end

    test "rejects recipient without 0x prefix" do
      params = %{@valid_params | recipient: String.duplicate("ab", 32)}
      assert {:error, {:invalid_recipient, _}} = CreateNoteParams.validate(params)
    end

    test "rejects short token address" do
      params = %{@valid_params | token: "0xabc"}
      assert {:error, {:invalid_token, _}} = CreateNoteParams.validate(params)
    end

    test "rejects negative amount" do
      params = %{@valid_params | amount: "-1"}
      assert {:error, {:invalid_amount, _}} = CreateNoteParams.validate(params)
    end

    test "rejects amount with leading zeros" do
      params = %{@valid_params | amount: "01"}
      assert {:error, {:invalid_amount, _}} = CreateNoteParams.validate(params)
    end

    test "accepts zero amount" do
      params = %{@valid_params | amount: "0"}
      assert :ok = CreateNoteParams.validate(params)
    end

    test "rejects non-positive chain_id" do
      params = %{@valid_params | chain_id: 0}
      assert {:error, {:invalid_chain_id, _}} = CreateNoteParams.validate(params)
    end
  end

  describe "CreateNoteParams.to_json/1" do
    test "serializes to camelCase JSON map" do
      params = %CreateNoteParams{
        recipient: "0xrecipient",
        token: "0xtoken",
        amount: "500",
        chain_id: 42_161
      }

      json = CreateNoteParams.to_json(params)

      assert json["recipient"] == "0xrecipient"
      assert json["token"] == "0xtoken"
      assert json["amount"] == "500"
      assert json["chainId"] == 42_161
    end
  end

  describe "CreateNoteResult.from_json/1" do
    test "parses result from camelCase JSON" do
      json = %{
        "noteCommitment" => "0xcommit",
        "nullifierHash" => "0xnull",
        "l2TxHash" => "0xl2tx"
      }

      result = CreateNoteResult.from_json(json)

      assert result.note_commitment == "0xcommit"
      assert result.nullifier_hash == "0xnull"
      assert result.l2_tx_hash == "0xl2tx"
    end
  end

  describe "HealthStatus.from_json/1" do
    test "parses ok status with version" do
      json = %{"status" => "ok", "version" => "4.1.3"}
      status = HealthStatus.from_json(json)

      assert status.status == :ok
      assert status.version == "4.1.3"
    end

    test "parses starting status without version" do
      json = %{"status" => "starting"}
      status = HealthStatus.from_json(json)

      assert status.status == :starting
      assert status.version == nil
    end

    test "unknown status maps to error" do
      json = %{"status" => "borked"}
      status = HealthStatus.from_json(json)

      assert status.status == :error
    end
  end
end
