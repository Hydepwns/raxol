defmodule Raxol.Terminal.State.Manager do
  @moduledoc """
  Manages terminal state operations for the terminal emulator.
  This module handles state stack, mode management, and general state operations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.ModeManager

  @doc """
  Gets the current state stack.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current state stack
  """
  @spec get_state_stack(Emulator.t()) :: TerminalState.t()
  def get_state_stack(%Emulator{} = emulator) do
    emulator.state_stack
  end

  @doc """
  Updates the state stack.

  ## Parameters

  * `emulator` - The emulator instance
  * `state_stack` - The new state stack

  ## Returns

  Updated emulator with new state stack
  """
  @spec update_state_stack(Emulator.t(), TerminalState.t()) :: Emulator.t()
  def update_state_stack(%Emulator{} = emulator, state_stack) do
    %{emulator | state_stack: state_stack}
  end

  @doc """
  Gets the current mode manager.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current mode manager
  """
  @spec get_mode_manager(Emulator.t()) :: ModeManager.t()
  def get_mode_manager(%Emulator{} = emulator) do
    emulator.mode_manager
  end

  @doc """
  Updates the mode manager.

  ## Parameters

  * `emulator` - The emulator instance
  * `mode_manager` - The new mode manager

  ## Returns

  Updated emulator with new mode manager
  """
  @spec update_mode_manager(Emulator.t(), ModeManager.t()) :: Emulator.t()
  def update_mode_manager(%Emulator{} = emulator, mode_manager) do
    %{emulator | mode_manager: mode_manager}
  end

  @doc """
  Gets the current charset state.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current charset state
  """
  @spec get_charset_state(Emulator.t()) :: map()
  def get_charset_state(%Emulator{} = emulator) do
    emulator.charset_state
  end

  @doc """
  Updates the charset state.

  ## Parameters

  * `emulator` - The emulator instance
  * `charset_state` - The new charset state

  ## Returns

  Updated emulator with new charset state
  """
  @spec update_charset_state(Emulator.t(), map()) :: Emulator.t()
  def update_charset_state(%Emulator{} = emulator, charset_state) do
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Gets the current scroll region.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The current scroll region tuple or nil
  """
  @spec get_scroll_region(Emulator.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_scroll_region(%Emulator{} = emulator) do
    emulator.scroll_region
  end

  @doc """
  Updates the scroll region.

  ## Parameters

  * `emulator` - The emulator instance
  * `scroll_region` - The new scroll region tuple or nil

  ## Returns

  Updated emulator with new scroll region
  """
  @spec update_scroll_region(Emulator.t(), {non_neg_integer(), non_neg_integer()} | nil) :: Emulator.t()
  def update_scroll_region(%Emulator{} = emulator, scroll_region) do
    %{emulator | scroll_region: scroll_region}
  end

  @doc """
  Gets the last column exceeded flag.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  The last column exceeded flag
  """
  @spec get_last_col_exceeded(Emulator.t()) :: boolean()
  def get_last_col_exceeded(%Emulator{} = emulator) do
    emulator.last_col_exceeded
  end

  @doc """
  Updates the last column exceeded flag.

  ## Parameters

  * `emulator` - The emulator instance
  * `last_col_exceeded` - The new last column exceeded flag

  ## Returns

  Updated emulator with new last column exceeded flag
  """
  @spec update_last_col_exceeded(Emulator.t(), boolean()) :: Emulator.t()
  def update_last_col_exceeded(%Emulator{} = emulator, last_col_exceeded) do
    %{emulator | last_col_exceeded: last_col_exceeded}
  end

  @doc """
  Resets the emulator to its initial state.

  ## Parameters

  * `emulator` - The emulator instance

  ## Returns

  Updated emulator with reset state
  """
  @spec reset_to_initial_state(Emulator.t()) :: Emulator.t()
  def reset_to_initial_state(%Emulator{} = emulator) do
    %{
      emulator
      | cursor: %{x: 0, y: 0},
        scroll_region: {0, emulator.height - 1},
        tab_stops: default_tab_stops(emulator.width),
        charset_state: %{},
        single_shift: nil,
        final_byte: nil,
        intermediates_buffer: [],
        params_buffer: [],
        payload_buffer: []
    }
  end

  # Private helper functions

  defp default_tab_stops(width) do
    # Generate tab stops every 8 columns
    for i <- 0..(width - 1), rem(i, 8) == 0, do: i
  end
end
