defmodule Raxol.Terminal.Modes do
  @moduledoc """
  Handles terminal modes and state transitions for the terminal emulator.

  This module provides functions for managing terminal modes, processing
  escape sequences, and handling terminal state transitions.
  """

  @type mode :: :insert | :replace | :visual | :command | :normal
  @type mode_state :: %{mode => boolean()}

  @doc """
  Creates a new terminal mode state.

  ## Examples

      iex> modes = Modes.new()
      iex> modes.insert
      false
  """
  def new do
    %{
      insert: false,
      replace: true,
      visual: false,
      command: false,
      normal: true
    }
  end

  @doc """
  Sets a terminal mode.

  ## Examples

      iex> modes = Modes.new()
      iex> modes = Modes.set_mode(modes, :insert)
      iex> modes.insert
      true
      iex> modes.replace
      false
  """
  def set_mode(%{} = modes, mode) when is_atom(mode) do
    # Turn off all modes first
    modes = Enum.reduce(modes, %{}, fn {k, _}, acc -> Map.put(acc, k, false) end)

    # Then set the requested mode
    Map.put(modes, mode, true)
  end

  @doc """
  Checks if a terminal mode is active.

  ## Examples

      iex> modes = Modes.new()
      iex> Modes.active?(modes, :normal)
      true
      iex> Modes.active?(modes, :insert)
      false
  """
  def active?(%{} = modes, mode) when is_atom(mode) do
    Map.get(modes, mode, false)
  end

  @doc """
  Processes an escape sequence for terminal mode changes.

  ## Examples

      iex> modes = Modes.new()
      iex> {modes, _} = Modes.process_escape(modes, "?1049h")
      iex> Modes.active?(modes, :alternate_screen)
      true
  """
  def process_escape(%{} = modes, sequence) do
    case sequence do
      # Alternate screen buffer
      "?1049h" -> {Map.put(modes, :alternate_screen, true), "Switched to alternate screen buffer"}
      "?1049l" -> {Map.put(modes, :alternate_screen, false), "Switched to main screen buffer"}

      # Line wrapping
      "?7h" -> {Map.put(modes, :line_wrap, true), "Line wrapping enabled"}
      "?7l" -> {Map.put(modes, :line_wrap, false), "Line wrapping disabled"}

      # Auto-repeat
      "?8h" -> {Map.put(modes, :auto_repeat, true), "Auto-repeat enabled"}
      "?8l" -> {Map.put(modes, :auto_repeat, false), "Auto-repeat disabled"}

      # Cursor visibility
      "?25h" -> {Map.put(modes, :cursor_visible, true), "Cursor visible"}
      "?25l" -> {Map.put(modes, :cursor_visible, false), "Cursor hidden"}

      # Insert mode
      "4h" -> {set_mode(modes, :insert), "Insert mode enabled"}
      "4l" -> {set_mode(modes, :replace), "Replace mode enabled"}

      # Visual mode
      "?1000h" -> {Map.put(modes, :visual, true), "Visual mode enabled"}
      "?1000l" -> {Map.put(modes, :visual, false), "Visual mode disabled"}

      # Command mode
      "?1001h" -> {Map.put(modes, :command, true), "Command mode enabled"}
      "?1001l" -> {Map.put(modes, :command, false), "Command mode disabled"}

      # Normal mode
      "?1002h" -> {set_mode(modes, :normal), "Normal mode enabled"}
      "?1002l" -> {set_mode(modes, :normal), "Normal mode disabled"}

      # Unknown sequence
      _ -> {modes, "Unknown escape sequence: #{sequence}"}
    end
  end

  @doc """
  Saves the current terminal mode state.

  ## Examples

      iex> modes = Modes.new()
      iex> {modes, saved_modes} = Modes.save_state(modes)
      iex> modes = Modes.set_mode(modes, :insert)
      iex> modes = Modes.restore_state(modes, saved_modes)
      iex> Modes.active?(modes, :normal)
      true
  """
  def save_state(%{} = modes) do
    # Maps are immutable, just return the current map
    {modes, modes}
  end

  @doc """
  Restores a previously saved terminal mode state.

  ## Examples

      iex> modes = Modes.new()
      iex> {modes, saved_modes} = Modes.save_state(modes)
      iex> modes = Modes.set_mode(modes, :insert)
      iex> modes = Modes.restore_state(modes, saved_modes)
      iex> Modes.active?(modes, :normal)
      true
  """
  def restore_state(%{} = _modes, %{} = saved_modes) do
    saved_modes
  end

  @doc """
  Returns a list of all active terminal modes.

  ## Examples

      iex> modes = Modes.new()
      iex> Modes.active_modes(modes)
      [:normal, :replace]
  """
  def active_modes(%{} = modes) do
    modes
    |> Enum.filter(fn {_k, v} -> v end)
    |> Enum.map(fn {k, _v} -> k end)
  end

  @doc """
  Returns a string representation of the terminal mode state.

  ## Examples

      iex> modes = Modes.new()
      iex> Modes.to_string(modes)
      "Terminal Modes: normal, replace"
  """
  def to_string(%{} = modes) do
    active = active_modes(modes)
    "Terminal Modes: #{Enum.join(active, ", ")}"
  end
end
