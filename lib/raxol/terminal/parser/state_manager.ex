defmodule Raxol.Terminal.Parser.StateManager do
  @moduledoc """
  Manages the state for the terminal parser.
  """

  defstruct mode_manager: nil, charset_state: nil, state_stack: [], scroll_region: nil, last_col_exceeded: false

  @type t :: %__MODULE__{
    mode_manager: map(),
    charset_state: map(),
    state_stack: list(),
    scroll_region: map(),
    last_col_exceeded: boolean()
  }

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Parser.State

  @doc """
  Creates a new parser state.
  """
  @spec new() :: State.t()
  def new do
    %State{state: :ground}
  end

  @doc """
  Gets the current parser state.
  """
  @spec get_state(EmulatorStruct.t()) :: State.t()
  def get_state(emulator) do
    emulator.parser_state
  end

  @doc """
  Updates the parser state.
  """
  @spec update_state(EmulatorStruct.t(), State.t()) :: EmulatorStruct.t()
  def update_state(emulator, state) do
    %{emulator | parser_state: state}
  end

  @doc """
  Gets the current state name.
  """
  @spec get_state_name(EmulatorStruct.t()) :: atom()
  def get_state_name(emulator) do
    emulator.parser_state.name
  end

  @doc """
  Sets the state name.
  """
  @spec set_state_name(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def set_state_name(emulator, name) do
    state = %{emulator.parser_state | name: name}
    %{emulator | parser_state: state}
  end

  @doc """
  Resets to ground state.
  """
  @spec reset_to_ground(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_to_ground(emulator) do
    state = %{emulator.parser_state | name: :ground}
    %{emulator | parser_state: state}
  end

  @doc """
  Checks if in ground state.
  """
  @spec in_ground_state?(EmulatorStruct.t()) :: boolean()
  def in_ground_state?(emulator) do
    emulator.parser_state.name == :ground
  end

  @doc """
  Checks if in escape state.
  """
  @spec in_escape_state?(EmulatorStruct.t()) :: boolean()
  def in_escape_state?(emulator) do
    emulator.parser_state.name == :escape
  end

  @doc """
  Checks if in control sequence state.
  """
  @spec in_control_sequence_state?(EmulatorStruct.t()) :: boolean()
  def in_control_sequence_state?(emulator) do
    emulator.parser_state.name == :csi
  end

  @doc """
  Gets the mode manager from the state.
  """
  @spec get_mode_manager(t()) :: map()
  def get_mode_manager(state) do
    state.mode_manager
  end

  @doc """
  Updates the mode manager in the state.
  """
  @spec update_mode_manager(t(), map()) :: t()
  def update_mode_manager(state, mode_manager) do
    %{state | mode_manager: mode_manager}
  end

  @doc """
  Gets the charset state from the state.
  """
  @spec get_charset_state(t()) :: map()
  def get_charset_state(state) do
    state.charset_state
  end

  @doc """
  Updates the charset state in the state.
  """
  @spec update_charset_state(t(), map()) :: t()
  def update_charset_state(state, charset_state) do
    %{state | charset_state: charset_state}
  end

  @doc """
  Gets the state stack from the state.
  """
  @spec get_state_stack(t()) :: list()
  def get_state_stack(state) do
    state.state_stack
  end

  @doc """
  Updates the state stack in the state.
  """
  @spec update_state_stack(t(), list()) :: t()
  def update_state_stack(state, state_stack) do
    %{state | state_stack: state_stack}
  end

  @doc """
  Gets the scroll region from the state.
  """
  @spec get_scroll_region(t()) :: map()
  def get_scroll_region(state) do
    state.scroll_region
  end

  @doc """
  Updates the scroll region in the state.
  """
  @spec update_scroll_region(t(), map()) :: t()
  def update_scroll_region(state, scroll_region) do
    %{state | scroll_region: scroll_region}
  end

  @doc """
  Gets the last column exceeded flag from the state.
  """
  @spec get_last_col_exceeded(t()) :: boolean()
  def get_last_col_exceeded(state) do
    state.last_col_exceeded
  end

  @doc """
  Updates the last column exceeded flag in the state.
  """
  @spec update_last_col_exceeded(t(), boolean()) :: t()
  def update_last_col_exceeded(state, last_col_exceeded) do
    %{state | last_col_exceeded: last_col_exceeded}
  end

  @doc """
  Resets the state to its initial values.
  """
  @spec reset_to_initial_state(t()) :: t()
  def reset_to_initial_state(state) do
    %{state | mode_manager: nil, charset_state: nil, state_stack: [], scroll_region: nil, last_col_exceeded: false}
  end
end
