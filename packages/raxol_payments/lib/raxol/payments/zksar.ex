defmodule Raxol.Payments.Zksar do
  @moduledoc """
  ZKSAR (Zero-Knowledge Sanctions/AML Reporting) attestation verification.

  Verifies Xochi oracle-signed attestation results. The actual ZK proof
  verification (Noir UltraHonk) happens on-chain or in the Xochi oracle.
  This module verifies the oracle's signed result: type, expiry, issuer,
  and structural integrity.

  ## Proof Types

  Six ZK proof types from Noir circuits:

  | Code | Type             | Purpose                                    |
  | ---- | ---------------- | ------------------------------------------ |
  | 0x01 | Compliance       | Score below jurisdiction threshold          |
  | 0x02 | Risk Score       | Score comparison without revealing score    |
  | 0x03 | Pattern          | No structuring/velocity anomalies          |
  | 0x04 | Attestation      | Valid credential exists                    |
  | 0x05 | Membership       | Address in whitelist                       |
  | 0x06 | Non-Membership   | NOT on sanctions list                      |
  """

  @type proof_type ::
          :compliance
          | :risk_score
          | :pattern
          | :attestation
          | :membership
          | :non_membership

  @type proof :: %{
          type_code: pos_integer(),
          issuer: String.t(),
          subject: String.t(),
          issued_at: integer(),
          expires_at: integer(),
          signature: String.t(),
          payload: binary()
        }

  @type verified_proof :: %{
          type: proof_type(),
          subject: String.t(),
          issuer: String.t(),
          issued_at: integer(),
          expires_at: integer(),
          valid: true
        }

  @type verification_error ::
          :expired | :unknown_type | :invalid_issuer | :malformed

  @proof_types %{
    0x01 => :compliance,
    0x02 => :risk_score,
    0x03 => :pattern,
    0x04 => :attestation,
    0x05 => :membership,
    0x06 => :non_membership
  }

  @proof_type_codes Map.new(@proof_types, fn {k, v} -> {v, k} end)

  @doc """
  Verify a single attestation proof.

  Checks type code, expiry, issuer allowlist, and structural integrity.

  ## Options

  - `:now` -- override current time (unix seconds) for testing
  - `:allowed_issuers` -- list of trusted oracle addresses; all accepted if nil
  """
  @spec verify(proof(), keyword()) :: {:ok, verified_proof()} | {:error, verification_error()}
  def verify(proof, opts \\ [])

  def verify(%{type_code: code} = proof, opts) when is_map_key(@proof_types, code) do
    now = Keyword.get(opts, :now, :os.system_time(:second))

    with :ok <- check_structure(proof),
         :ok <- check_expiry(proof, now),
         :ok <- check_issuer(proof, opts) do
      {:ok,
       %{
         type: @proof_types[code],
         subject: proof.subject,
         issuer: proof.issuer,
         issued_at: proof.issued_at,
         expires_at: proof.expires_at,
         valid: true
       }}
    end
  end

  def verify(%{type_code: _code}, _opts), do: {:error, :unknown_type}
  def verify(_proof, _opts), do: {:error, :malformed}

  @doc """
  Verify a batch of proofs. Does not fail-fast.

  Returns `{verified, errors}` where errors are `{proof, reason}` tuples.
  """
  @spec verify_batch([proof()], keyword()) ::
          {[verified_proof()], [{proof(), verification_error()}]}
  def verify_batch(proofs, opts \\ []) when is_list(proofs) do
    Enum.reduce(proofs, {[], []}, fn proof, {verified, errors} ->
      case verify(proof, opts) do
        {:ok, vp} -> {[vp | verified], errors}
        {:error, reason} -> {verified, [{proof, reason} | errors]}
      end
    end)
    |> then(fn {v, e} -> {Enum.reverse(v), Enum.reverse(e)} end)
  end

  @doc "Look up proof type name from numeric code."
  @spec proof_type_name(pos_integer()) :: {:ok, proof_type()} | :error
  def proof_type_name(code) when is_map_key(@proof_types, code), do: {:ok, @proof_types[code]}
  def proof_type_name(_code), do: :error

  @doc "Look up numeric code from proof type name."
  @spec proof_type_code(proof_type()) :: {:ok, pos_integer()} | :error
  def proof_type_code(name) when is_map_key(@proof_type_codes, name),
    do: {:ok, @proof_type_codes[name]}

  def proof_type_code(_name), do: :error

  @doc "All known proof type names."
  @spec proof_types() :: [proof_type()]
  def proof_types, do: Map.values(@proof_types)

  @doc """
  Parse a proof from Xochi API JSON (camelCase).

  Expected keys: `typeCode`, `issuer`, `subject`, `issuedAt`, `expiresAt`,
  `signature`, `payload` (hex-encoded).
  """
  @spec from_json(map()) :: {:ok, proof()} | {:error, :malformed}
  def from_json(%{
        "typeCode" => type_code,
        "issuer" => issuer,
        "subject" => subject,
        "issuedAt" => issued_at,
        "expiresAt" => expires_at,
        "signature" => signature,
        "payload" => payload_hex
      })
      when is_integer(type_code) and is_binary(issuer) and is_binary(subject) and
             is_integer(issued_at) and is_integer(expires_at) and is_binary(signature) and
             is_binary(payload_hex) do
    case Base.decode16(payload_hex, case: :mixed) do
      {:ok, payload} ->
        {:ok,
         %{
           type_code: type_code,
           issuer: issuer,
           subject: subject,
           issued_at: issued_at,
           expires_at: expires_at,
           signature: signature,
           payload: payload
         }}

      :error ->
        {:error, :malformed}
    end
  end

  def from_json(_), do: {:error, :malformed}

  # -- Private --

  defp check_structure(%{subject: s, issuer: i, signature: sig})
       when is_binary(s) and byte_size(s) > 0 and
              is_binary(i) and byte_size(i) > 0 and
              is_binary(sig) and byte_size(sig) > 0,
       do: :ok

  defp check_structure(_), do: {:error, :malformed}

  defp check_expiry(%{expires_at: exp}, now) when is_integer(exp) and exp > now, do: :ok
  defp check_expiry(_, _), do: {:error, :expired}

  defp check_issuer(proof, opts) do
    case Keyword.get(opts, :allowed_issuers) do
      nil ->
        :ok

      issuers when is_list(issuers) ->
        if proof.issuer in issuers, do: :ok, else: {:error, :invalid_issuer}
    end
  end
end
