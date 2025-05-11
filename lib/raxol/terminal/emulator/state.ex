defmodule Raxol.Terminal.Emulator.State do
  @moduledoc """
  Handles state management for the terminal emulator.
  Provides functions for managing terminal state, modes, and character sets.
  """

  require Logger

  alias Raxol.Terminal.{
    Core,
    ANSI.CharacterSets,
    ANSI.TerminalState,
    ModeManager
  }

  @doc """
  Sets a terminal mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_mode(Core.t(), atom(), boolean()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_mode(%Core{} = emulator, mode, value) when is_atom(mode) and is_boolean(value) do
    case ModeManager.set_mode(emulator.mode_manager, mode, value) do
      {:ok, updated_mode_manager} ->
        {:ok, %{emulator | mode_manager: updated_mode_manager}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_mode(%Core{} = _emulator, invalid_mode, _value) do
    {:error, "Invalid mode: #{inspect(invalid_mode)}"}
  end

  @doc """
  Gets the value of a terminal mode.
  Returns the mode value or nil if not set.
  """
  @spec get_mode(Core.t(), atom()) :: boolean() | nil
  def get_mode(%Core{} = emulator, mode) when is_atom(mode) do
    ModeManager.get_mode(emulator.mode_manager, mode)
  end

  def get_mode(%Core{} = _emulator, invalid_mode) do
    {:error, "Invalid mode: #{inspect(invalid_mode)}"}
  end

  @doc """
  Sets the character set state.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_charset_state(Core.t(), CharacterSets.charset_state()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_charset_state(%Core{} = emulator, charset_state) do
    case CharacterSets.validate_state(charset_state) do
      :ok ->
        {:ok, %{emulator | charset_state: charset_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the current character set state.
  Returns the current charset state.
  """
  @spec get_charset_state(Core.t()) :: CharacterSets.charset_state()
  def get_charset_state(%Core{} = emulator) do
    emulator.charset_state
  end

  @doc """
  Pushes a new state onto the state stack.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec push_state(Core.t()) :: {:ok, Core.t()} | {:error, String.t()}
  def push_state(%Core{} = emulator) do
    case TerminalState.push(emulator.state) do
      {:ok, updated_state} ->
        {:ok, %{emulator | state: updated_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Pops a state from the state stack.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec pop_state(Core.t()) :: {:ok, Core.t()} | {:error, String.t()}
  def pop_state(%Core{} = emulator) do
    case TerminalState.pop(emulator.state) do
      {:ok, updated_state} ->
        {:ok, %{emulator | state: updated_state}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the current state from the state stack.
  Returns the current state or nil if stack is empty.
  """
  @spec get_current_state(Core.t()) :: TerminalState.t() | nil
  def get_current_state(%Core{} = emulator) do
    TerminalState.current(emulator.state)
  end

  @doc """
  Sets the memory limit for the terminal.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_memory_limit(Core.t(), non_neg_integer()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_memory_limit(%Core{} = emulator, limit) when is_integer(limit) and limit > 0 do
    {:ok, %{emulator | memory_limit: limit}}
  end

  def set_memory_limit(%Core{} = _emulator, invalid_limit) do
    {:error, "Invalid memory limit: #{inspect(invalid_limit)}"}
  end

  @doc """
  Gets the current memory limit.
  Returns the memory limit.
  """
  @spec get_memory_limit(Core.t()) :: non_neg_integer()
  def get_memory_limit(%Core{} = emulator) do
    emulator.memory_limit
  end

  @doc """
  Sets the current hyperlink URL.
  Returns {:ok, updated_emulator}.
  """
  @spec set_hyperlink_url(Core.t(), String.t() | nil) :: {:ok, Core.t()}
  def set_hyperlink_url(%Core{} = emulator, url) when is_binary(url) or is_nil(url) do
    {:ok, %{emulator | current_hyperlink_url: url}}
  end

  def set_hyperlink_url(%Core{} = _emulator, invalid_url) do
    {:error, "Invalid hyperlink URL: #{inspect(invalid_url)}"}
  end

  @doc """
  Gets the current hyperlink URL.
  Returns the current hyperlink URL or nil.
  """
  @spec get_hyperlink_url(Core.t()) :: String.t() | nil
  def get_hyperlink_url(%Core{} = emulator) do
    emulator.current_hyperlink_url
  end

  @doc """
  Sets the tab stops for the terminal.
  Returns {:ok, updated_emulator}.
  """
  @spec set_tab_stops(Core.t(), MapSet.t()) :: {:ok, Core.t()}
  def set_tab_stops(%Core{} = emulator, tab_stops) when is_map(tab_stops) do
    {:ok, %{emulator | tab_stops: tab_stops}}
  end

  def set_tab_stops(%Core{} = _emulator, invalid_tab_stops) do
    {:error, "Invalid tab stops: #{inspect(invalid_tab_stops)}"}
  end

  @doc """
  Gets the current tab stops.
  Returns the current tab stops.
  """
  @spec get_tab_stops(Core.t()) :: MapSet.t()
  def get_tab_stops(%Core{} = emulator) do
    emulator.tab_stops
  end
end
