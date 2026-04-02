defmodule Raxol.Agent.ProcessBehaviour do
  @moduledoc """
  Behaviour for agents running in the observe/think/act loop (Agent.Process).

  Formalizes the callbacks that Agent.Process modules implement.
  Using this behaviour gives compile-time warnings for missing callbacks.
  """

  @type state :: map()
  @type observation :: map()
  @type action :: term()
  @type directive :: term()
  @type events :: [term()]

  @doc "Initialize agent state from options."
  @callback init(keyword()) :: {:ok, state()} | state()

  @doc "Observe events and produce an observation map."
  @callback observe(events(), state()) :: {:ok, observation(), state()}

  @doc """
  Decide what to do based on the observation.

  Returns:
  - `{:act, action, new_state}` -- execute an action
  - `{:wait, new_state}` -- do nothing this tick
  - `{:ask_pilot, question, new_state}` -- escalate to human
  """
  @callback think(observation(), state()) ::
              {:act, action(), state()}
              | {:wait, state()}
              | {:ask_pilot, term(), state()}

  @doc "Execute an action. Returns updated state."
  @callback act(action(), state()) ::
              {:ok, state()} | {:error, term(), state()}

  @doc "Handle a directive from the orchestrator or pilot."
  @callback receive_directive(directive(), state()) ::
              {:ok, state()} | {:defer, state()}

  @doc "Snapshot state for crash recovery."
  @callback context_snapshot(state()) :: map()

  @doc "Restore state from a snapshot."
  @callback restore_context(map()) :: {:ok, state()} | :error

  @doc "Called when pilot takes over."
  @callback on_takeover(state()) :: {:ok, state()}

  @doc "Called when pilot releases."
  @callback on_resume(state()) :: {:ok, state()}

  @optional_callbacks [
    context_snapshot: 1,
    restore_context: 1,
    on_takeover: 1,
    on_resume: 1
  ]
end
