defmodule Raxol.Terminal.ScreenBuffer.FileWatcher do
  @moduledoc """
  Handles file system event monitoring for the terminal screen buffer.
  This module provides functions for processing file system events and managing
  debounced event handling.
  """

  @type event ::
          {:created, Path.t()} | {:modified, Path.t()} | {:deleted, Path.t()}
  @type events :: list(event())
  @type debounce_timeout :: non_neg_integer()

  @type t :: %__MODULE__{
          watched_paths: MapSet.t(Path.t()),
          pending_events: events(),
          last_event_time: non_neg_integer()
        }

  defstruct watched_paths: MapSet.new(),
            pending_events: [],
            last_event_time: 0

  @spec handle_event(t(), event()) :: t()
  def handle_event(%__MODULE__{} = state, event) do
    %{
      state
      | pending_events: [event | state.pending_events],
        last_event_time: System.monotonic_time(:millisecond)
    }
  end

  @spec handle_debounced(t(), events(), debounce_timeout()) :: t()
  def handle_debounced(%__MODULE__{} = state, events, timeout) do
    current_time = System.monotonic_time(:millisecond)
    time_since_last = current_time - state.last_event_time

    case time_since_last >= timeout do
      true ->
        %{state | pending_events: [], last_event_time: current_time}

      false ->
        %{
          state
          | pending_events: events ++ state.pending_events,
            last_event_time: current_time
        }
    end
  end

  @spec cleanup(t()) :: t()
  def cleanup(%__MODULE__{} = state) do
    %{
      state
      | watched_paths: MapSet.new(),
        pending_events: [],
        last_event_time: 0
    }
  end

  def init do
    %__MODULE__{}
  end
end
