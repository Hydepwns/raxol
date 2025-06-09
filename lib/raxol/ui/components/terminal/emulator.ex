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
    width =
      if is_map(opts),
        do: Map.get(opts, :width),
        else: if(is_tuple(opts), do: elem(opts, 0), else: nil)

    height =
      if is_map(opts),
        do: Map.get(opts, :height),
        else: if(is_tuple(opts), do: elem(opts, 1), else: nil)

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
    # IO.inspect({input, Map.take(state.core_emulator, [:parser_state, :output_buffer])}, label: "UI.Component.Emulator RECEIVED ARGS")

    core_result = CoreEmulator.process_input(current_emulator, input)

    # IO.inspect(core_result, label: "UI.Component.Emulator CORE_EMULATOR_RESULT")

    {updated_emulator, output} = core_result
    updated_state = %{state | core_emulator: updated_emulator}

    # IO.inspect({updated_state, output}, label: "UI.Component.Emulator INTENDS TO RETURN")
    {updated_state, output}
  end

  @doc """
  Handles terminal resize events by delegating to the CoreEmulator.
  This ensures that the terminal's internal buffers and state are correctly
  adjusted while preserving existing content and history where possible.
  """
  @spec handle_resize({integer(), integer()}, emulator_state()) ::
          emulator_state()
  def handle_resize({width, height}, %{core_emulator: current_emulator} = state)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    updated_core_emulator = CoreEmulator.resize(current_emulator, width, height)
    %{state | core_emulator: updated_core_emulator}
  end

  @doc """
  Gets the visible content from the UI component's state.
  """
  @spec get_visible_content(emulator_state()) :: String.t()
  def get_visible_content(%{core_emulator: core_emulator}) do
    core_emulator
    |> CoreEmulator.get_active_buffer()
    |> Raxol.Terminal.ScreenBuffer.get_content()
  end

  # Private functions removed as logic is now in CoreEmulator
  # defp init_screen(...)
  # defp resize_screen(...)
  # defp clamp_cursor(...)
end
