defmodule Raxol.Core.Runtime.Plugins.TimerManager.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin timer management.

  This behaviour is responsible for:
  - Managing plugin timers
  - Handling timer scheduling and cancellation
  - Coordinating timer events
  - Managing timer state
  """

  @doc """
  Cancels an existing timer and returns updated state.
  """
  @callback cancel_existing_timer(state :: map()) :: map()

  @doc """
  Schedules a new timer and returns updated state.
  """
  @callback schedule_timer(
              state :: map(),
              message :: term(),
              timeout :: non_neg_integer()
            ) :: map()

  @doc """
  Handles timer message delivery.
  """
  @callback handle_timer_message(
              state :: map(),
              message :: term()
            ) :: map()

  @doc """
  Gets the current timer state.
  """
  @callback get_timer_state(state :: map()) :: map()

  @doc """
  Updates the timer state.
  """
  @callback update_timer_state(
              state :: map(),
              new_state :: map()
            ) :: map()
end
