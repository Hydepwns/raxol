defmodule Raxol.Payments.SpendingPolicy do
  @moduledoc """
  Spending limits for agent payment operations.

  Defines per-request, per-session (sliding window), and lifetime caps.
  Used by the `Ledger` to enforce budget constraints before signing payments.

  ## Example

      policy = %SpendingPolicy{
        per_request_max: Decimal.new("1.00"),
        session_max: Decimal.new("10.00"),
        session_window_ms: 3_600_000,
        lifetime_max: Decimal.new("100.00"),
        currency: "USDC",
        approved_domains: ["api.example.com"],
        require_confirmation_above: Decimal.new("5.00")
      }
  """

  @type t :: %__MODULE__{
          per_request_max: Decimal.t(),
          session_max: Decimal.t(),
          session_window_ms: pos_integer(),
          lifetime_max: Decimal.t(),
          currency: String.t(),
          approved_domains: [String.t()] | nil,
          require_confirmation_above: Decimal.t() | nil
        }

  defstruct [
    :per_request_max,
    :session_max,
    :lifetime_max,
    :require_confirmation_above,
    session_window_ms: 3_600_000,
    currency: "USDC",
    approved_domains: nil
  ]

  @doc """
  Create a policy with sensible defaults for development.
  """
  @spec dev() :: t()
  def dev do
    %__MODULE__{
      per_request_max: Decimal.new("0.10"),
      session_max: Decimal.new("1.00"),
      lifetime_max: Decimal.new("10.00"),
      currency: "USDC"
    }
  end

  @doc """
  Create an unrestricted policy (for testing only).
  """
  @spec unrestricted() :: t()
  def unrestricted do
    max = Decimal.new("999999999")

    %__MODULE__{
      per_request_max: max,
      session_max: max,
      lifetime_max: max,
      currency: "USDC"
    }
  end

  @doc """
  Check if a domain is approved under this policy.

  Returns true if `approved_domains` is nil (all domains allowed)
  or if the domain matches an entry in the list. Matching is
  case-insensitive and respects domain boundaries -- `evil-example.com`
  does not match `example.com`, but `api.example.com` does.

  Empty strings in the approved list are ignored. An empty domain
  string never matches.
  """
  @spec domain_approved?(t(), String.t()) :: boolean()
  def domain_approved?(%__MODULE__{approved_domains: nil}, _domain), do: true
  def domain_approved?(_policy, ""), do: false

  def domain_approved?(%__MODULE__{approved_domains: domains}, domain) do
    downcased = String.downcase(domain)

    Enum.any?(domains, fn approved ->
      approved = String.downcase(approved)
      approved != "" and domain_matches?(downcased, approved)
    end)
  end

  defp domain_matches?(domain, approved) do
    domain == approved or String.ends_with?(domain, "." <> approved)
  end

  @doc """
  Check if a payment amount requires user confirmation.
  """
  @spec requires_confirmation?(t(), Decimal.t()) :: boolean()
  def requires_confirmation?(%__MODULE__{require_confirmation_above: nil}, _amount), do: false

  def requires_confirmation?(%__MODULE__{require_confirmation_above: threshold}, amount) do
    Decimal.compare(amount, threshold) == :gt
  end
end
