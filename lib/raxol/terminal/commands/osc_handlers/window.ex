defmodule Raxol.Terminal.Commands.OSCHandlers.Window do
  @moduledoc false

  alias Raxol.Terminal.Emulator, as: Emulator

  @spec handle_0(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_0(emulator, title) do
    # Set the window title directly in the emulator
    {:ok, %{emulator | window_title: title}}
  end

  @spec handle_1(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_1(emulator, icon_name) do
    # Set the icon name in the window state
    window_state = Map.put(emulator.window_state, :icon_name, icon_name)
    {:ok, %{emulator | window_state: window_state}}
  end

  @spec handle_2(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_2(emulator, title) do
    # Set the window title directly in the emulator
    {:ok, %{emulator | window_title: title}}
  end

  @spec handle_7(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_7(emulator, dir) do
    # Store working directory in window state
    window_state = Map.put(emulator.window_state, :working_directory, dir)
    {:ok, %{emulator | window_state: window_state}}
  end

  @spec handle_8(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_8(emulator, size_str) do
    case parse_size(size_str) do
      {:ok, {width, height}} ->
        # Update window size in window state
        window_state =
          Map.merge(emulator.window_state, %{
            size: {width, height},
            # Approximate pixel size
            size_pixels: {width * 8, height * 16}
          })

        {:ok, %{emulator | window_state: window_state}}

      :error ->
        {:error, :invalid_size_format, emulator}
    end
  end

  @spec handle_1337(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_1337(emulator, data) do
    case parse_size(data) do
      {:ok, {width, height}} ->
        # Update window size in window state
        window_state =
          Map.merge(emulator.window_state, %{
            size: {width, height},
            # Approximate pixel size
            size_pixels: {width * 8, height * 16}
          })

        {:ok, %{emulator | window_state: window_state}}

      :error ->
        {:error, :invalid_size_format, emulator}
    end
  end

  # Private helper functions
  defp parse_size(size_str) do
    case String.split(size_str, ";") do
      [width_str, height_str] ->
        with {width, ""} <- Integer.parse(width_str),
             {height, ""} <- Integer.parse(height_str),
             true <- width > 0 and height > 0 do
          {:ok, {width, height}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
