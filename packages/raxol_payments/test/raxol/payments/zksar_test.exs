defmodule Raxol.Payments.ZksarTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Zksar

  @now 1_700_000_000
  @valid_proof %{
    type_code: 0x01,
    issuer: "0xoracleAddress",
    subject: "0xsubjectAddress",
    issued_at: @now - 100,
    expires_at: @now + 3600,
    signature: "0xdeadbeef",
    payload: <<1, 2, 3, 4>>
  }

  describe "verify/2" do
    test "verifies valid compliance proof" do
      assert {:ok, vp} = Zksar.verify(@valid_proof, now: @now)
      assert vp.type == :compliance
      assert vp.subject == "0xsubjectAddress"
      assert vp.issuer == "0xoracleAddress"
      assert vp.valid == true
    end

    test "verifies each proof type code" do
      for {code, expected_type} <- [
            {0x01, :compliance},
            {0x02, :risk_score},
            {0x03, :pattern},
            {0x04, :attestation},
            {0x05, :membership},
            {0x06, :non_membership}
          ] do
        proof = %{@valid_proof | type_code: code}
        assert {:ok, vp} = Zksar.verify(proof, now: @now)
        assert vp.type == expected_type
      end
    end

    test "rejects expired proof" do
      proof = %{@valid_proof | expires_at: @now - 1}
      assert {:error, :expired} = Zksar.verify(proof, now: @now)
    end

    test "rejects proof expiring at exactly now" do
      proof = %{@valid_proof | expires_at: @now}
      assert {:error, :expired} = Zksar.verify(proof, now: @now)
    end

    test "rejects unknown type code" do
      proof = %{@valid_proof | type_code: 0xFF}
      assert {:error, :unknown_type} = Zksar.verify(proof, now: @now)
    end

    test "rejects malformed proof (missing fields)" do
      assert {:error, :malformed} = Zksar.verify(%{}, now: @now)
    end

    test "rejects proof with empty subject" do
      proof = %{@valid_proof | subject: ""}
      assert {:error, :malformed} = Zksar.verify(proof, now: @now)
    end

    test "rejects proof with empty issuer" do
      proof = %{@valid_proof | issuer: ""}
      assert {:error, :malformed} = Zksar.verify(proof, now: @now)
    end

    test "rejects proof with empty signature" do
      proof = %{@valid_proof | signature: ""}
      assert {:error, :malformed} = Zksar.verify(proof, now: @now)
    end

    test "rejects disallowed issuer" do
      assert {:error, :invalid_issuer} =
               Zksar.verify(@valid_proof, now: @now, allowed_issuers: ["0xotherOracle"])
    end

    test "accepts allowed issuer" do
      assert {:ok, _} =
               Zksar.verify(@valid_proof, now: @now, allowed_issuers: ["0xoracleAddress"])
    end

    test "accepts any issuer when allowed_issuers not set" do
      assert {:ok, _} = Zksar.verify(@valid_proof, now: @now)
    end
  end

  describe "verify_batch/2" do
    test "returns verified and errors separately" do
      expired = %{@valid_proof | expires_at: @now - 1}
      unknown = %{@valid_proof | type_code: 0xFF}

      {verified, errors} = Zksar.verify_batch([@valid_proof, expired, unknown], now: @now)

      assert length(verified) == 1
      assert hd(verified).type == :compliance
      assert length(errors) == 2
      assert {^expired, :expired} = Enum.at(errors, 0)
      assert {^unknown, :unknown_type} = Enum.at(errors, 1)
    end

    test "empty list returns empty results" do
      assert {[], []} = Zksar.verify_batch([], now: @now)
    end

    test "preserves order" do
      p1 = %{@valid_proof | type_code: 0x01}
      p2 = %{@valid_proof | type_code: 0x05}

      {verified, []} = Zksar.verify_batch([p1, p2], now: @now)
      assert [%{type: :compliance}, %{type: :membership}] = verified
    end
  end

  describe "proof_type_name/1 and proof_type_code/1" do
    test "round-trips all six types" do
      for {code, name} <- [
            {0x01, :compliance},
            {0x02, :risk_score},
            {0x03, :pattern},
            {0x04, :attestation},
            {0x05, :membership},
            {0x06, :non_membership}
          ] do
        assert {:ok, ^name} = Zksar.proof_type_name(code)
        assert {:ok, ^code} = Zksar.proof_type_code(name)
      end
    end

    test "unknown code returns :error" do
      assert :error = Zksar.proof_type_name(0x99)
    end

    test "unknown name returns :error" do
      assert :error = Zksar.proof_type_code(:bogus)
    end
  end

  describe "from_json/1" do
    test "parses valid JSON map" do
      json = %{
        "typeCode" => 0x01,
        "issuer" => "0xoracle",
        "subject" => "0xsubject",
        "issuedAt" => 1000,
        "expiresAt" => 2000,
        "signature" => "0xsig",
        "payload" => "DEADBEEF"
      }

      assert {:ok, proof} = Zksar.from_json(json)
      assert proof.type_code == 0x01
      assert proof.payload == <<0xDE, 0xAD, 0xBE, 0xEF>>
    end

    test "rejects missing fields" do
      assert {:error, :malformed} = Zksar.from_json(%{"typeCode" => 1})
    end

    test "rejects invalid hex payload" do
      json = %{
        "typeCode" => 1,
        "issuer" => "0x",
        "subject" => "0x",
        "issuedAt" => 1,
        "expiresAt" => 2,
        "signature" => "0x",
        "payload" => "not_hex!"
      }

      assert {:error, :malformed} = Zksar.from_json(json)
    end
  end

  describe "adversarial cases" do
    test "expired proof (expires_at = now - 1) returns :expired" do
      proof = %{@valid_proof | expires_at: @now - 1}
      assert {:error, :expired} = Zksar.verify(proof, now: @now)
    end

    test "proof with empty signature returns :malformed" do
      proof = %{@valid_proof | signature: ""}
      assert {:error, :malformed} = Zksar.verify(proof, now: @now)
    end

    test "proof with empty subject returns :malformed" do
      proof = %{@valid_proof | subject: ""}
      assert {:error, :malformed} = Zksar.verify(proof, now: @now)
    end

    test "batch with mix of valid and invalid proofs returns both lists" do
      valid = @valid_proof
      expired = %{@valid_proof | expires_at: @now - 1}
      malformed = %{@valid_proof | subject: ""}
      unknown = %{@valid_proof | type_code: 0xFF}

      {verified, errors} =
        Zksar.verify_batch([valid, expired, malformed, unknown], now: @now)

      assert length(verified) == 1
      assert hd(verified).type == :compliance
      assert length(errors) == 3

      error_reasons = Enum.map(errors, fn {_proof, reason} -> reason end)
      assert :expired in error_reasons
      assert :malformed in error_reasons
      assert :unknown_type in error_reasons
    end

    test "proof with unknown type_code 0xFF returns :unknown_type" do
      proof = %{@valid_proof | type_code: 0xFF}
      assert {:error, :unknown_type} = Zksar.verify(proof, now: @now)
    end
  end

  describe "proof_types/0" do
    test "returns all six types" do
      types = Zksar.proof_types()
      assert length(types) == 6
      assert :compliance in types
      assert :non_membership in types
    end
  end
end
