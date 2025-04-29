defmodule Raxol.Examples.KeyboardShortcutsDemo do
  use Raxol.Core.Runtime.Application

  require Logger
  require Raxol.View.Elements

  alias Raxol.Core.Accessibility

  @impl Raxol.Core.Runtime.Application
  def init(_args) do
    Logger.info("Initializing KeyboardShortcutsDemo...")

    initial_state = %{
      message: "Press keys to see shortcuts or Ctrl+C to exit.",
      last_key: nil,
      async_data: nil
    }

    Accessibility.announce("Keyboard shortcuts demo started. Press F1 for help.")

    {:ok, initial_state}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:keyboard_event, event}, state) do
    new_state = Map.put(state, :last_key, event)
    {:ok, new_state}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message({:some_async_result, data}, state) do
    Logger.info("Received async result: #{inspect(data)}")
    new_state = Map.put(state, :async_data, data)
    {:noreply, new_state}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(message, state) do
    Logger.debug("KeyboardShortcutsDemo received unhandled message: #{inspect message}")
    {:noreply, state}
  end

  @impl Raxol.Core.Runtime.Application
  def view(state) do
    # Simple view displaying the message and last key
    last_key_display =
      if state.last_key do
        "Last key: #{inspect(state.last_key)}"
      else
        ""
      end

    # Use do...end block syntax for elements
    Raxol.View.Elements.box do
      Raxol.View.Elements.label content: state.message
      Raxol.View.Elements.label content: last_key_display
    end
  end

  @impl Raxol.Core.Runtime.Application
  def terminate(reason, _state) do
    Logger.info("Terminating KeyboardShortcutsDemo: #{inspect(reason)}")
    :ok
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    Logger.debug("Received unhandled event (handle_event/1): #{inspect event}")
    :noreply
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(state) do
    # Default implementation: no state change
    {:noreply, state}
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state) do
    # Default implementation: no subscriptions
    []
  end
end
