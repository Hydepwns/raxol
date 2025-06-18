defmodule Raxol.Terminal.ANSI.TerminalStateBehaviour do
  @moduledoc '''
  Behaviour for managing terminal state saving and restoring.
  '''

  alias Raxol.Terminal.Emulator
  # For the @type t and state_data_map
  alias Raxol.Terminal.ANSI.TerminalState

  # Represents the map of state data from restore_state
  @type state_data_map :: map()
  # or the emulator-like map passed to save_state's second arg.

  # The second argument to save_state is the current emulator state (or a map with similar structure)
  # from which fields like :cursor, :style, etc., are extracted.
  @callback save_state(
              stack :: TerminalState.state_stack(),
              current_emulator_state :: map()
            ) :: TerminalState.state_stack()

  @callback restore_state(stack :: TerminalState.state_stack()) ::
              {new_stack :: TerminalState.state_stack(),
               state_data :: state_data_map() | nil}

  @callback apply_restored_data(
              emulator_state :: Emulator.t(),
              state_data :: state_data_map() | nil,
              fields_to_restore :: list(atom())
            ) :: Emulator.t()
end
