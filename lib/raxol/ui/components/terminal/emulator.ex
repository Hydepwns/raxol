defmodule Raxol.UI.Components.Terminal.Emulator do
  @moduledoc """
  Terminal emulator component wrapping the core emulator logic.
  """

  alias Raxol.Terminal.Emulator, as: CoreEmulator

  @type emulator_state :: %{
          core_emulator: CoreEmulator.t()
        }

  @doc """
  Initializes a new terminal emulator component state.
  Accepts an optional map of options, currently supporting `:width` and `:height`.
  """
  @spec init(map()) :: emulator_state()
  def init(opts \\ %{}) do
    width = Map.get(opts, :width)
    height = Map.get(opts, :height)

    # Initialize the core emulator, passing options if provided
    core_emulator =
      case {width, height} do
        {w, h} when is_integer(w) and is_integer(h) -> CoreEmulator.new(w, h)
        _ -> CoreEmulator.new()
      end

    %{
      core_emulator: core_emulator
    }
  end

  @doc """
  Processes input and updates terminal state by delegating to the core emulator.
  Returns a tuple `{updated_state, output_string}`.
  """
  @spec process_input(term(), emulator_state()) :: {emulator_state(), term()}
  def process_input(input, %{core_emulator: current_emulator} = state) do
    # Delegate processing to the core emulator
    # Capture the output returned by the core emulator
    {updated_emulator, output} =
      CoreEmulator.process_input(current_emulator, input)

    # Update the component's state with the updated core emulator state
    updated_state = %{state | core_emulator: updated_emulator}

    # Return the updated state and the output
    {updated_state, output}
  end

  @doc """
  Handles terminal resize events by delegating to the CoreEmulator.
  This ensures that the terminal's internal buffers and state are correctly
  adjusted while preserving existing content and history where possible.
  """
  @spec handle_resize({integer(), integer()}, emulator_state()) :: emulator_state()
  def handle_resize({width, height}, %{core_emulator: current_emulator} = state)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    updated_core_emulator = CoreEmulator.resize(current_emulator, width, height)
    %{state | core_emulator: updated_core_emulator}
  end

  @doc """
  Gets the visible content from the UI component's state.
  """
  @spec get_visible_content(emulator_state()) :: list()
  def get_visible_content(_state) do
    # Implementation here
    []
  end

  # Private functions removed as logic is now in CoreEmulator
  # defp init_screen(...)
  # defp resize_screen(...)
  # defp clamp_cursor(...)
end
