defmodule Raxol.UI.Components.Terminal.Emulator do
  @moduledoc """
  Terminal emulator component wrapping the core emulator logic.
  """

  alias Raxol.Terminal.{
    Integration.State,
    IO.IOServer
  }

  @type emulator_state :: %{
          state: State.t()
        }

  @doc """
  Initializes a new terminal emulator component state.
  Accepts an optional map of options, currently supporting `:width` and `:height`.
  """
  def init(opts \\ %{}) do
    width = Map.get(opts, :width)
    height = Map.get(opts, :height)

    # Initialize the integration state
    state =
      State.new(%{
        width: width,
        height: height,
        config: Map.get(opts, :config, %{})
      })

    %{
      state: state
    }
  end

  @doc """
  Processes input and updates terminal state by delegating to IOServer.
  Returns a tuple `{updated_state, output_string}`.
  """
  def process_input(input, %{state: current_state} = state) do
    # Wrap input in the expected event format
    event = %{type: :key, key: input}

    # Process input through IOServer
    {:ok, commands} = IOServer.process_input(event)

    # Update the component's state
    updated_state = %{state | state: current_state}

    # Return the updated state and any commands
    {updated_state, commands}
  end

  @doc """
  Handles terminal resize events by delegating to State.
  This ensures that the terminal's internal buffers and state are correctly
  adjusted while preserving existing content and history where possible.
  """
  def handle_resize({width, height}, %{state: current_state} = state) do
    # Delegate resize to State
    updated_state = State.resize(current_state, width, height)
    %{state | state: updated_state}
  end

  @doc """
  Renders the current terminal state.
  """
  def render(%{state: current_state} = state) do
    # Delegate rendering to State
    updated_state = State.render(current_state)
    %{state | state: updated_state}
  end

  @doc """
  Cleans up resources when the component is destroyed.
  """
  def cleanup(%{state: current_state}) do
    State.cleanup(current_state)
  end
end
