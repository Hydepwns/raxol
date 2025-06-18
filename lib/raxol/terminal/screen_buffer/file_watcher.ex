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
          watched_paths: MapSet.new(Path.t()),
          pending_events: events(),
          last_event_time: non_neg_integer()
        }

  defstruct watched_paths: MapSet.new(),
            pending_events: [],
            last_event_time: 0

  @doc """
  Handles a file system event.
  Returns a new file watcher state with the event processed.
  """
  @spec handle_event(t(), event()) :: t()
  def handle_event(%__MODULE__{} = state, event) do
    %{
      state
      | pending_events: [event | state.pending_events],
        last_event_time: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Handles debounced file system events.
  Returns a new file watcher state with the events processed after the timeout.
  """
  @spec handle_debounced(t(), events(), debounce_timeout()) :: t()
  def handle_debounced(%__MODULE__{} = state, events, timeout) do
    current_time = System.monotonic_time(:millisecond)
    time_since_last = current_time - state.last_event_time

    if time_since_last >= timeout do
      %{state | pending_events: [], last_event_time: current_time}
    else
      %{
        state
        | pending_events: events ++ state.pending_events,
          last_event_time: current_time
      }
    end
  end

  @doc """
  Cleans up the file watcher state.
  Returns a new file watcher state with all watched paths and pending events cleared.
  """
  @spec cleanup(t()) :: t()
  def cleanup(%__MODULE__{} = state) do
    %{
      state
      | watched_paths: MapSet.new(),
        pending_events: [],
        last_event_time: 0
    }
  end

  @doc """
  Initializes a new file watcher struct with default values.
  """
  def init do
    %__MODULE__{}
  end
end
