defmodule Raxol.Terminal.Charset.Manager do
  @moduledoc """
  Manages character set operations for the terminal emulator.
  This module handles character set designation, invocation, and state management.
  """

  alias Raxol.Terminal.ANSI.CharacterSets

  @doc """
  Creates a new character set state.
  """
  @spec new() :: CharacterSets.charset_state()
  def new do
    CharacterSets.new()
  end

  @doc """
  Gets the current character set state.
  """
  @spec get_state(Raxol.Terminal.Emulator.t()) :: CharacterSets.charset_state()
  def get_state(emulator) do
    emulator.charset_state
  end

  @doc """
  Updates the character set state.
  """
  @spec update_state(Raxol.Terminal.Emulator.t(), CharacterSets.charset_state()) :: Raxol.Terminal.Emulator.t()
  def update_state(emulator, state) do
    %{emulator | charset_state: state}
  end

  @doc """
  Designates a character set for the specified G-set.
  """
  @spec designate_charset(Raxol.Terminal.Emulator.t(), atom(), atom()) :: Raxol.Terminal.Emulator.t()
  def designate_charset(emulator, g_set, charset) do
    new_state = CharacterSets.designate(emulator.charset_state, g_set, charset)
    update_state(emulator, new_state)
  end

  @doc """
  Invokes a G-set.
  """
  @spec invoke_g_set(Raxol.Terminal.Emulator.t(), atom()) :: Raxol.Terminal.Emulator.t()
  def invoke_g_set(emulator, g_set) do
    new_state = CharacterSets.invoke(emulator.charset_state, g_set)
    update_state(emulator, new_state)
  end

  @doc """
  Gets the current G-set.
  """
  @spec get_current_g_set(Raxol.Terminal.Emulator.t()) :: atom()
  def get_current_g_set(emulator) do
    CharacterSets.get_current_g_set(emulator.charset_state)
  end

  @doc """
  Gets the designated character set for a G-set.
  """
  @spec get_designated_charset(Raxol.Terminal.Emulator.t(), atom()) :: atom()
  def get_designated_charset(emulator, g_set) do
    CharacterSets.get_designated_charset(emulator.charset_state, g_set)
  end

  @doc """
  Resets character set state to defaults.
  """
  @spec reset_state(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def reset_state(emulator) do
    new_state = CharacterSets.reset(emulator.charset_state)
    update_state(emulator, new_state)
  end

  @doc """
  Applies single shift to a G-set.
  """
  @spec apply_single_shift(Raxol.Terminal.Emulator.t(), atom()) :: Raxol.Terminal.Emulator.t()
  def apply_single_shift(emulator, g_set) do
    new_state = CharacterSets.apply_single_shift(emulator.charset_state, g_set)
    update_state(emulator, new_state)
  end

  @doc """
  Gets the current single shift state.
  """
  @spec get_single_shift(Raxol.Terminal.Emulator.t()) :: atom() | nil
  def get_single_shift(emulator) do
    CharacterSets.get_single_shift(emulator.charset_state)
  end
end
