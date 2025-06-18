defmodule Raxol.Terminal.EventProcessor do
  @moduledoc '''
  Handles processing of terminal events and their effects on the terminal state.

  This module is responsible for:
  - Processing different types of terminal events
  - Validating event data
  - Applying event effects to the terminal state
  - Coordinating with other terminal components
  '''

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Events.Event
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Events.Handlers

  @event_handlers %{
    window: &Handlers.handle_window_event/2,
    mode: &Handlers.handle_mode_event/2,
    focus: &Handlers.handle_focus_event/2,
    clipboard: &Handlers.handle_clipboard_event/2,
    selection: &Handlers.handle_selection_event/2,
    paste: &Handlers.handle_paste_event/2,
    cursor: &Handlers.handle_cursor_event/2,
    scroll: &Handlers.handle_scroll_event/2
  }

  @doc '''
  Processes a terminal event and returns the updated terminal state.

  ## Parameters
    * `event` - The event to process
    * `emulator` - The current terminal emulator state

  ## Returns
    * `{updated_emulator, output}` - The updated emulator state and any output
  '''
  @spec process_event(Event.t(), Emulator.t()) :: {Emulator.t(), any()}
  def process_event(%Event{type: type, data: data} = _event, emulator) do
    case Map.get(@event_handlers, type) do
      nil ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown terminal event type: #{inspect(type)} with data: #{inspect(data)}",
          %{}
        )

        {emulator, nil}

      handler ->
        handler.(data, emulator)
    end
  end
end
