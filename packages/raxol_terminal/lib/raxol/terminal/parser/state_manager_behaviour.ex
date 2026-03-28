defmodule Raxol.Terminal.Parser.StateManagerBehaviour do
  @moduledoc """
  Behaviour for terminal parser state management.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Parser.ParserState, as: State

  @type t :: term()

  @callback new() :: State.t()
  @callback get_state(EmulatorStruct.t()) :: State.t()
  @callback update_state(EmulatorStruct.t(), State.t()) :: EmulatorStruct.t()
  @callback get_state_name(EmulatorStruct.t()) :: atom()
  @callback set_state_name(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  @callback reset_to_ground(EmulatorStruct.t()) :: EmulatorStruct.t()
  @callback in_ground_state?(EmulatorStruct.t()) :: boolean()
  @callback in_escape_state?(EmulatorStruct.t()) :: boolean()
  @callback in_control_sequence_state?(EmulatorStruct.t()) :: boolean()
  @callback get_mode_manager(t()) :: map()
  @callback update_mode_manager(t(), map()) :: t()
  @callback get_charset_state(t()) :: map()
  @callback update_charset_state(t(), map()) :: t()
  @callback get_state_stack(t()) :: list()
  @callback update_state_stack(t(), list()) :: t()
  @callback get_scroll_region(t()) :: map()
  @callback update_scroll_region(t(), map()) :: t()
  @callback get_last_col_exceeded(t()) :: boolean()
  @callback update_last_col_exceeded(t(), boolean()) :: t()
  @callback reset_to_initial_state(t()) :: t()
end
