defmodule Raxol.Terminal.Emulator.State do
  @moduledoc """
  Handles state management for the terminal emulator.
  Provides functions for managing terminal state, modes, and character sets.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    Emulator,
    ANSI.CharacterSets,
    ANSI.TerminalState,
    ModeManager
  }

  @doc """
  Sets a terminal mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_mode(Emulator.t(), atom(), boolean()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_mode(%Emulator{} = emulator, mode, value)
      when is_atom(mode) and is_boolean(value) do
    case ModeManager.set_mode(emulator.mode_manager, mode, value) do
      {:ok, updated_mode_manager} ->
        {:ok, %{emulator | mode_manager: updated_mode_manager}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_mode(%Emulator{} = _emulator, invalid_mode, _value) do
    {:error, "Invalid mode: #{inspect(invalid_mode)}"}
  end

  @doc """
  Gets the value of a terminal mode.
  Returns the mode value or nil if not set.
  """
  @spec get_mode(Emulator.t(), atom()) :: boolean() | nil
  def get_mode(%Emulator{} = emulator, mode) when is_atom(mode) do
    ModeManager.get_mode(emulator.mode_manager, mode)
  end

  def get_mode(%Emulator{} = _emulator, invalid_mode) do
    {:error, "Invalid mode: #{inspect(invalid_mode)}"}
  end

  @doc """
  Sets the character set state.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_charset_state(Emulator.t(), CharacterSets.charset_state()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_charset_state(%Emulator{} = emulator, charset_state) do
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
  @spec get_charset_state(Emulator.t()) :: CharacterSets.charset_state()
  def get_charset_state(%Emulator{} = emulator) do
    emulator.charset_state
  end

  @doc """
  Pushes a new state onto the state stack.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec push_state(Emulator.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def push_state(%Emulator{} = emulator) do
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
  @spec pop_state(Emulator.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def pop_state(%Emulator{} = emulator) do
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
  @spec get_current_state(Emulator.t()) :: TerminalState.t() | nil
  def get_current_state(%Emulator{} = emulator) do
    TerminalState.current(emulator.state)
  end

  @doc """
  Sets the memory limit for the terminal.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_memory_limit(Emulator.t(), non_neg_integer()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_memory_limit(%Emulator{} = emulator, limit)
      when is_integer(limit) and limit > 0 do
    {:ok, %{emulator | memory_limit: limit}}
  end

  def set_memory_limit(%Emulator{} = _emulator, invalid_limit) do
    {:error, "Invalid memory limit: #{inspect(invalid_limit)}"}
  end

  @doc """
  Gets the current memory limit.
  Returns the memory limit.
  """
  @spec get_memory_limit(Emulator.t()) :: non_neg_integer()
  def get_memory_limit(%Emulator{} = emulator) do
    emulator.memory_limit
  end

  @doc """
  Sets the current hyperlink URL.
  Returns {:ok, updated_emulator}.
  """
  @spec set_hyperlink_url(Emulator.t(), String.t() | nil) :: {:ok, Emulator.t()}
  def set_hyperlink_url(%Emulator{} = emulator, url)
      when is_binary(url) or is_nil(url) do
    {:ok, %{emulator | current_hyperlink_url: url}}
  end

  def set_hyperlink_url(%Emulator{} = _emulator, invalid_url) do
    {:error, "Invalid hyperlink URL: #{inspect(invalid_url)}"}
  end

  @doc """
  Gets the current hyperlink URL.
  Returns the current hyperlink URL or nil.
  """
  @spec get_hyperlink_url(Emulator.t()) :: String.t() | nil
  def get_hyperlink_url(%Emulator{} = emulator) do
    emulator.current_hyperlink_url
  end

  @doc """
  Sets the tab stops for the terminal.
  Returns {:ok, updated_emulator}.
  """
  @spec set_tab_stops(Emulator.t(), MapSet.t()) :: {:ok, Emulator.t()}
  def set_tab_stops(%Emulator{} = emulator, tab_stops) when is_map(tab_stops) do
    {:ok, %{emulator | tab_stops: tab_stops}}
  end

  def set_tab_stops(%Emulator{} = _emulator, invalid_tab_stops) do
    {:error, "Invalid tab stops: #{inspect(invalid_tab_stops)}"}
  end

  @doc """
  Gets the current tab stops.
  Returns the current tab stops.
  """
  @spec get_tab_stops(Emulator.t()) :: MapSet.t()
  def get_tab_stops(%Emulator{} = emulator) do
    emulator.tab_stops
  end
end
