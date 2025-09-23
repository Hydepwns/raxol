defmodule Raxol.Terminal.CharsetManager do
  @moduledoc """
  Manages the terminal character sets.
  """

  defstruct state: %{}, g_set: :g0, designated_charsets: %{}

  @type t :: %__MODULE__{
          state: map(),
          g_set: atom(),
          designated_charsets: map()
        }

  @doc """
  Gets the current state.
  """
  @spec get_state(t()) :: map()
  def get_state(state) do
    state.state
  end

  @doc """
  Updates the state.
  """
  @spec update_state(t(), map()) :: t()
  def update_state(state, new_state) do
    %{state | state: new_state}
  end

  @doc """
  Designates a charset for the given g-set.
  """
  @spec designate_charset(t(), atom(), atom()) :: t()
  def designate_charset(state, g_set, charset) do
    %{
      state
      | designated_charsets: Map.put(state.designated_charsets, g_set, charset)
    }
  end

  @doc """
  Invokes the given g-set.
  """
  @spec invoke_g_set(t(), atom()) :: t()
  def invoke_g_set(state, g_set) do
    %{state | g_set: g_set}
  end

  @doc """
  Gets the current g-set.
  """
  @spec get_current_g_set(t()) :: atom()
  def get_current_g_set(state) do
    state.g_set
  end

  @doc """
  Gets the designated charset for the given g-set.
  """
  @spec get_designated_charset(t(), atom()) :: atom()
  def get_designated_charset(state, g_set) do
    Map.get(state.designated_charsets, g_set, :default)
  end

  @doc """
  Resets the state to its initial values.
  """
  @spec reset_state(t()) :: t()
  def reset_state(state) do
    %{state | state: %{}, g_set: :g0, designated_charsets: %{}}
  end

  @doc """
  Applies a single shift to the state.
  """
  @spec apply_single_shift(t(), atom()) :: t()
  def apply_single_shift(state, _shift) do
    # TODO: Implement single shift application
    state
  end

  @doc """
  Gets the current single shift.
  """
  @spec get_single_shift(t()) :: atom()
  def get_single_shift(_state) do
    :ok
  end
end
