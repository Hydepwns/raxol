defmodule Raxol.Terminal.Commands.OSCHandlers.Window do
  @moduledoc false

  alias Raxol.Terminal.Emulator, as: Emulator
  alias Raxol.Terminal.Window

  @spec handle_0(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_0(emulator, title) do
    case Window.set_title(emulator.window, title) do
      {:ok, new_window} ->
        {:ok, %{emulator | window: new_window}}

      _ ->
        {:error, :invalid_title, emulator}
    end
  end

  @spec handle_1(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_1(emulator, icon_name) do
    case Window.set_icon_name(emulator.window, icon_name) do
      {:ok, new_window} ->
        {:ok, %{emulator | window: new_window}}

      _ ->
        {:error, :invalid_icon_name, emulator}
    end
  end

  @spec handle_2(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_2(emulator, title) do
    case Window.set_title(emulator.window, title) do
      {:ok, new_window} ->
        {:ok, %{emulator | window: new_window}}

      _ ->
        {:error, :invalid_title, emulator}
    end
  end

  @spec handle_7(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_7(emulator, dir) do
    new_window = Window.set_working_directory(emulator.window, dir)
    {:ok, %{emulator | window: new_window}}
  end

  @spec handle_8(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_8(emulator, size_str) do
    case parse_size(size_str) do
      {:ok, {width, height}} ->
        case Window.set_size(emulator.window, width, height) do
          {:ok, new_window} ->
            {:ok, %{emulator | window: new_window}}

          _ ->
            {:error, :invalid_size, emulator}
        end

      :error ->
        {:error, :invalid_size_format, emulator}
    end
  end

  @spec handle_1337(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}

  def handle_1337(emulator, data) do
    case parse_size(data) do
      {:ok, {width, height}} ->
        case Window.set_size(emulator.window, width, height) do
          {:ok, new_window} ->
            {:ok, %{emulator | window: new_window}}

          _ ->
            {:error, :invalid_size, emulator}
        end

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
