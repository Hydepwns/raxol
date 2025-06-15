defmodule Raxol.Terminal.Input.Processor do
  @moduledoc """
  Processes input events for the terminal emulator.
  """

  @doc """
  Creates a new input processor.
  """
  def new do
    %{
      state: :normal,
      buffer: ""
    }
  end

  @doc """
  Maps an input event to a terminal command.
  """
  def map_event(event) do
    case event do
      %{type: :key, key: key, modifiers: modifiers} ->
        map_key_event(key, modifiers)

      %{type: :mouse, button: button, x: x, y: y} ->
        map_mouse_event(button, x, y)

      _ ->
        {:error, :unknown_event_type}
    end
  end

  # Private functions

  defp map_key_event(key, modifiers) do
    case {key, modifiers} do
      # Arrow keys
      {:up, []} ->
        {:ok, "\e[A"}

      {:down, []} ->
        {:ok, "\e[B"}

      {:right, []} ->
        {:ok, "\e[C"}

      {:left, []} ->
        {:ok, "\e[D"}

      # Function keys
      {:f1, []} ->
        {:ok, "\eOP"}

      {:f2, []} ->
        {:ok, "\eOQ"}

      {:f3, []} ->
        {:ok, "\eOR"}

      {:f4, []} ->
        {:ok, "\eOS"}

      {:f5, []} ->
        {:ok, "\e[15~"}

      {:f6, []} ->
        {:ok, "\e[17~"}

      {:f7, []} ->
        {:ok, "\e[18~"}

      {:f8, []} ->
        {:ok, "\e[19~"}

      {:f9, []} ->
        {:ok, "\e[20~"}

      {:f10, []} ->
        {:ok, "\e[21~"}

      {:f11, []} ->
        {:ok, "\e[23~"}

      {:f12, []} ->
        {:ok, "\e[24~"}

      # Special keys
      {:home, []} ->
        {:ok, "\e[H"}

      {:end, []} ->
        {:ok, "\e[F"}

      {:insert, []} ->
        {:ok, "\e[2~"}

      {:delete, []} ->
        {:ok, "\e[3~"}

      {:page_up, []} ->
        {:ok, "\e[5~"}

      {:page_down, []} ->
        {:ok, "\e[6~"}

      # Regular keys
      {char, []} when is_binary(char) and byte_size(char) == 1 ->
        {:ok, char}

      # Unknown key
      _ ->
        {:error, :unknown_key}
    end
  end

  defp map_mouse_event(button, x, y) do
    case button do
      :left -> {:ok, "\e[M#{x + 32}#{y + 32}"}
      :middle -> {:ok, "\e[M#{x + 32}#{y + 32}"}
      :right -> {:ok, "\e[M#{x + 32}#{y + 32}"}
      _ -> {:error, :unknown_button}
    end
  end
end
