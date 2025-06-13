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
    modes =
      Enum.reduce(modes, %{}, fn {k, _}, acc -> Map.put(acc, k, false) end)

    # Then set the requested mode
    Map.put(modes, mode, true)
  end

  @doc """
  Resets a specific terminal mode to its default value.

  ## Examples

      iex> modes = Modes.new() |> Modes.set_mode(:insert)
      iex> modes.insert
      true
      iex> modes = Modes.reset_mode(modes, :insert)
      iex> modes.insert
      false
      iex> modes = Modes.reset_mode(modes, :replace) # replace defaults to true
      iex> modes.replace
      true
  """
  @spec reset_mode(mode_state(), atom()) :: mode_state()
  def reset_mode(%{} = modes, mode) when is_atom(mode) do
    default_modes = new()
    # Default to false if mode unknown
    default_value = Map.get(default_modes, mode, false)
    Map.put(modes, mode, default_value)
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
  def process_escape(%{} = modes, "?1049h"), do: handle_alternate_screen(modes, "?1049h")
  def process_escape(%{} = modes, "?1049l"), do: handle_alternate_screen(modes, "?1049l")
  def process_escape(%{} = modes, "?7h"), do: handle_line_wrap(modes, "?7h")
  def process_escape(%{} = modes, "?7l"), do: handle_line_wrap(modes, "?7l")
  def process_escape(%{} = modes, "?8h"), do: handle_auto_repeat(modes, "?8h")
  def process_escape(%{} = modes, "?8l"), do: handle_auto_repeat(modes, "?8l")
  def process_escape(%{} = modes, "?25h"), do: handle_cursor_visibility(modes, "?25h")
  def process_escape(%{} = modes, "?25l"), do: handle_cursor_visibility(modes, "?25l")
  def process_escape(%{} = modes, "4h"), do: handle_insert_mode(modes, "4h")
  def process_escape(%{} = modes, "4l"), do: handle_insert_mode(modes, "4l")
  def process_escape(%{} = modes, "?1000h"), do: handle_visual_mode(modes, "?1000h")
  def process_escape(%{} = modes, "?1000l"), do: handle_visual_mode(modes, "?1000l")
  def process_escape(%{} = modes, "?1001h"), do: handle_command_mode(modes, "?1001h")
  def process_escape(%{} = modes, "?1001l"), do: handle_command_mode(modes, "?1001l")
  def process_escape(%{} = modes, "?1002h"), do: handle_normal_mode(modes, "?1002h")
  def process_escape(%{} = modes, "?1002l"), do: handle_normal_mode(modes, "?1002l")
  def process_escape(%{} = modes, sequence), do: {modes, "Unknown escape sequence: #{sequence}"}

  defp handle_alternate_screen(modes, "?1049h"), do: {Map.put(modes, :alternate_screen, true), "Switched to alternate screen buffer"}
  defp handle_alternate_screen(modes, "?1049l"), do: {Map.put(modes, :alternate_screen, false), "Switched to main screen buffer"}

  defp handle_line_wrap(modes, "?7h"), do: {Map.put(modes, :line_wrap, true), "Line wrapping enabled"}
  defp handle_line_wrap(modes, "?7l"), do: {Map.put(modes, :line_wrap, false), "Line wrapping disabled"}

  defp handle_auto_repeat(modes, "?8h"), do: {Map.put(modes, :auto_repeat, true), "Auto-repeat enabled"}
  defp handle_auto_repeat(modes, "?8l"), do: {Map.put(modes, :auto_repeat, false), "Auto-repeat disabled"}

  defp handle_cursor_visibility(modes, "?25h"), do: {Map.put(modes, :cursor_visible, true), "Cursor visible"}
  defp handle_cursor_visibility(modes, "?25l"), do: {Map.put(modes, :cursor_visible, false), "Cursor hidden"}

  defp handle_insert_mode(modes, "4h"), do: {set_mode(modes, :insert), "Insert mode enabled"}
  defp handle_insert_mode(modes, "4l"), do: {set_mode(modes, :replace), "Replace mode enabled"}

  defp handle_visual_mode(modes, "?1000h"), do: {Map.put(modes, :visual, true), "Visual mode enabled"}
  defp handle_visual_mode(modes, "?1000l"), do: {Map.put(modes, :visual, false), "Visual mode disabled"}

  defp handle_command_mode(modes, "?1001h"), do: {Map.put(modes, :command, true), "Command mode enabled"}
  defp handle_command_mode(modes, "?1001l"), do: {Map.put(modes, :command, false), "Command mode disabled"}

  defp handle_normal_mode(modes, "?1002h"), do: {set_mode(modes, :normal), "Normal mode enabled"}
  defp handle_normal_mode(modes, "?1002l"), do: {set_mode(modes, :normal), "Normal mode disabled"}

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
