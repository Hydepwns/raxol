defmodule Raxol.Terminal.InputManager do
  @moduledoc """
  Manages terminal input processing including character input, key events, and input mode handling.
  This module is responsible for processing all input events and converting them into appropriate
  terminal actions.
  """

  alias Raxol.Terminal.{Emulator, ParserStateManager}
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  @doc """
  Processes a single character input.
  Returns the updated emulator and any output.
  """
  @spec process_input(Emulator.t(), char()) :: {Emulator.t(), any()}
  def process_input(emulator, char) do
    {emulator, output} = ParserStateManager.process_char(emulator, char)
    handle_input_result(emulator, output)
  end

  @doc """
  Processes a sequence of character inputs.
  Returns the updated emulator and any output.
  """
  @spec process_input_sequence(Emulator.t(), [char()]) :: {Emulator.t(), any()}
  def process_input_sequence(emulator, chars) do
    Enum.reduce(chars, {emulator, nil}, fn char, {emu, _} ->
      process_input(emu, char)
    end)
  end

  @doc """
  Handles a key event.
  Returns the updated emulator and any output.
  """
  @spec handle_key_event(Emulator.t(), atom(), map()) :: {Emulator.t(), any()}
  def handle_key_event(emulator, :key_press, event) do
    case event do
      %{key: :enter} ->
        handle_enter(emulator)

      %{key: :backspace} ->
        handle_backspace(emulator)

      %{key: :tab} ->
        handle_tab(emulator)

      %{key: :escape} ->
        handle_escape(emulator)

      %{key: key} when atom?(key) ->
        handle_special_key(emulator, key)

      %{char: char} when integer?(char) ->
        handle_character(emulator, char)

      _ ->
        {emulator, nil}
    end
  end

  def handle_key_event(emulator, :key_release, _event) do
    {emulator, nil}
  end

  @doc """
  Gets the current input mode.
  Returns the input mode.
  """
  @spec get_input_mode(Emulator.t()) :: atom()
  def get_input_mode(emulator) do
    emulator.input_mode
  end

  @doc """
  Sets the input mode.
  Returns the updated emulator.
  """
  @spec set_input_mode(Emulator.t(), atom()) :: Emulator.t()
  def set_input_mode(emulator, mode) do
    %{emulator | input_mode: mode}
  end

  # Private helper functions

  defp handle_input_result(emulator, nil), do: {emulator, nil}

  defp handle_input_result(emulator, output) when binary?(output) do
    {emulator, output}
  end

  defp handle_input_result(emulator, {:command, command}) do
    handle_command(emulator, command)
  end

  defp handle_command(emulator, command) do
    case command do
      {:clear_screen, _} ->
        {emulator, nil}

      {:move_cursor, _x, _y} ->
        {emulator, nil}

      {:set_style, _style} ->
        {emulator, nil}

      _ ->
        {emulator, nil}
    end
  end

  defp handle_enter(emulator) do
    {emulator, "\r\n"}
  end

  defp handle_backspace(emulator) do
    {emulator, "\b"}
  end

  defp handle_tab(emulator) do
    {emulator, "\t"}
  end

  defp handle_escape(emulator) do
    {emulator, "\e"}
  end

  defp handle_special_key(emulator, key) do
    case key do
      :up -> {emulator, "\e[A"}
      :down -> {emulator, "\e[B"}
      :right -> {emulator, "\e[C"}
      :left -> {emulator, "\e[D"}
      :home -> {emulator, "\e[H"}
      :end -> {emulator, "\e[F"}
      :page_up -> {emulator, "\e[5~"}
      :page_down -> {emulator, "\e[6~"}
      :insert -> {emulator, "\e[2~"}
      :delete -> {emulator, "\e[3~"}
      _ -> {emulator, nil}
    end
  end

  defp handle_character(emulator, char) do
    {emulator, <<char::utf8>>}
  end

  # Functions that are delegated to this module from Raxol.Terminal.Input.Manager

  @doc """
  Processes keyboard input.
  """
  @spec process_keyboard(Emulator.t(), String.t()) :: {Emulator.t(), any()}
  def process_keyboard(emulator, input) when is_binary(input) do
    # Process each character in the input string
    Enum.reduce(String.graphemes(input), {emulator, nil}, fn char, {emu, _} ->
      process_input(emu, String.to_charlist(char) |> hd())
    end)
  end

  @doc """
  Processes mouse events.
  """
  @spec process_mouse(Emulator.t(), map()) :: {Emulator.t(), any()}
  def process_mouse(emulator, event) do
    # For now, just return the emulator unchanged
    # This can be expanded later to handle mouse events properly
    {emulator, nil}
  end

  @doc """
  Processes special keys.
  """
  @spec process_special_key(Emulator.t(), atom()) :: {Emulator.t(), any()}
  def process_special_key(emulator, key) do
    handle_special_key(emulator, key)
  end

  @doc """
  Sets the input mode.
  """
  @spec set_mode(Emulator.t(), atom()) :: Emulator.t()
  def set_mode(emulator, mode) do
    set_input_mode(emulator, mode)
  end

  @doc """
  Updates modifier key state.
  """
  @spec update_modifier(Emulator.t(), String.t(), boolean()) :: Emulator.t()
  def update_modifier(emulator, modifier, value) do
    # For now, just return the emulator unchanged
    # This can be expanded later to handle modifier states properly
    emulator
  end
end
