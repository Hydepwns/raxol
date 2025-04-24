defmodule Raxol.Components.Terminal.Emulator do
  @moduledoc """
  Terminal emulator component wrapping the core emulator logic.
  """

  alias Raxol.Terminal.Emulator, as: CoreEmulator

  @type emulator_state :: %{
          core_emulator: CoreEmulator.t()
        }

  @doc """
  Initializes a new terminal emulator component state.
  """
  def init do
    # Initialize the core emulator
    core_emulator = CoreEmulator.new()

    %{
      core_emulator: core_emulator
    }
  end

  @doc """
  Processes input and updates terminal state by delegating to the core emulator.
  """
  def process_input(input, %{core_emulator: current_emulator} = state) do
    # Delegate processing to the core emulator
    {updated_emulator, _rest} =
      CoreEmulator.process_input(current_emulator, input)

    # Update the component's state with the updated core emulator state
    %{state | core_emulator: updated_emulator}
  end

  @doc """
  Handles terminal resize events.
  TODO: Implement proper resizing by delegating to CoreEmulator or ScreenBuffer
  """
  def handle_resize({width, height}, state) do
    # Placeholder: Currently just logs a warning.
    # Needs proper implementation to resize the core_emulator state.
    IO.puts("Warning: handle_resize in component not fully implemented.")
    # Re-initialize for now to avoid state mismatch (loses history/state)
    new_core = CoreEmulator.new(width, height)
    %{state | core_emulator: new_core}
  end

  @doc """
  Gets the visible content from the UI component's state.
  """
  def get_visible_content(_state) do
    # Implementation here
    []
  end

  # Private functions removed as logic is now in CoreEmulator
  # defp init_screen(...)
  # defp resize_screen(...)
  # defp clamp_cursor(...)
end
