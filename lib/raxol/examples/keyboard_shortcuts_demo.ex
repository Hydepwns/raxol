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

    _shortcuts = [
      {[:ctrl], ?c, {__MODULE__, :handle_exit, []}},
      {[:alt], ?h, {__MODULE__, :toggle_high_contrast, []}},
      {[:alt], ?m, {__MODULE__, :toggle_reduced_motion, []}},
      {[:alt], ?l, {__MODULE__, :toggle_large_text, []}},
      {{}, :f1, {__MODULE__, :show_help, []}}
    ]

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

  def handle_exit(_context) do
    Logger.info("Exit requested (Ctrl+C)")
    Application.stop(:raxol)
    {:stop, :normal, %{}}
  end

  def show_help(_context) do
    Accessibility.announce("Shortcuts: Alt+H (Contrast), Alt+M (Motion), Alt+L (Large Text), Ctrl+C (Exit)")
    {:noreply, %{}}
  end

  def toggle_high_contrast(_context) do
    current_state = Raxol.Core.UserPreferences.get([:accessibility, :high_contrast]) || false
    Accessibility.set_high_contrast(not current_state)
    new_state = Raxol.Core.UserPreferences.get([:accessibility, :high_contrast]) || false
    Logger.info("High contrast toggled to: #{new_state}")
    announce_state_change("High contrast", new_state)
    {:noreply, %{}}
  end

  def toggle_reduced_motion(_context) do
    current_state = Raxol.Core.UserPreferences.get([:accessibility, :reduced_motion]) || false
    Accessibility.set_reduced_motion(not current_state)
    new_state = Raxol.Core.UserPreferences.get([:accessibility, :reduced_motion]) || false
    Logger.info("Reduced motion toggled to: #{new_state}")
    announce_state_change("Reduced motion", new_state)
    {:noreply, %{}}
  end

  def toggle_large_text(_context) do
    current_state = Raxol.Core.UserPreferences.get([:accessibility, :large_text]) || false
    Accessibility.set_large_text(not current_state)
    new_state = Raxol.Core.UserPreferences.get([:accessibility, :large_text]) || false
    Logger.info("Large text toggled to: #{new_state}")
    announce_state_change("Large text", new_state)
    {:noreply, %{}}
  end

  defp announce_state_change(feature, state) do
    Accessibility.announce("#{feature} is now #{if(state, do: "enabled", else: "disabled")}")
  end

  def handle_event(event, state) do
    Logger.debug("Received unhandled event (handle_event/2): #{inspect event}")
    {:noreply, state}
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
