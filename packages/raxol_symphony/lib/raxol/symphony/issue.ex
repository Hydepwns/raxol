defmodule Raxol.Symphony.Issue do
  @moduledoc """
  Normalized issue record.

  Implements SPEC s4.1.1. All tracker adapters MUST normalize their native
  payloads into this shape before returning issues to the orchestrator.

  Field semantics:

  - `id` -- stable tracker-internal ID (used for map keys and refresh
    queries).
  - `identifier` -- human-readable ticket key (e.g. `MT-123`); used for
    workspace naming after sanitization.
  - `priority` -- lower numbers are higher priority in dispatch sorting; null
    sorts last.
  - `state` -- current tracker state name (compared lowercase).
  - `labels` -- normalized to lowercase strings.
  - `blocked_by` -- list of `Blocker` refs derived from inverse relations
    where relation type is `blocks`.
  - `created_at` / `updated_at` -- parsed ISO-8601 timestamps (or nil).
  """

  alias __MODULE__.Blocker

  @enforce_keys [:id, :identifier, :title, :state]
  defstruct [
    :id,
    :identifier,
    :title,
    :state,
    description: nil,
    priority: nil,
    branch_name: nil,
    url: nil,
    labels: [],
    blocked_by: [],
    created_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: binary(),
          identifier: binary(),
          title: binary(),
          description: binary() | nil,
          priority: integer() | nil,
          state: binary(),
          branch_name: binary() | nil,
          url: binary() | nil,
          labels: [binary()],
          blocked_by: [Blocker.t()],
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Returns true when the issue's state is in the configured terminal_states
  list (compared case-insensitively per SPEC s4.2).
  """
  @spec terminal?(t(), [binary()]) :: boolean()
  def terminal?(%__MODULE__{state: state}, terminal_states) when is_list(terminal_states) do
    needle = String.downcase(state)
    Enum.any?(terminal_states, &(String.downcase(&1) == needle))
  end

  @doc """
  Returns true when the issue's state is in the configured active_states
  list (compared case-insensitively per SPEC s4.2).
  """
  @spec active?(t(), [binary()]) :: boolean()
  def active?(%__MODULE__{state: state}, active_states) when is_list(active_states) do
    needle = String.downcase(state)
    Enum.any?(active_states, &(String.downcase(&1) == needle))
  end

  defmodule Blocker do
    @moduledoc "Reference to a blocking issue (inverse `blocks` relation)."

    defstruct [:id, :identifier, :state]

    @type t :: %__MODULE__{
            id: binary() | nil,
            identifier: binary() | nil,
            state: binary() | nil
          }
  end
end
