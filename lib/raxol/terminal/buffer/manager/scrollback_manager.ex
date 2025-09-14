defmodule Raxol.Terminal.Buffer.Manager.ScrollbackManager do
  @moduledoc """
  Handles scrollback operations for buffer managers.
  Extracted from Raxol.Terminal.Buffer.Manager to improve maintainability.
  """

  @doc """
  Adds a buffer to the scrollback history.
  """

  def add_to_scrollback(%Raxol.Terminal.Emulator{} = emulator, buffer) do
    scrollback = Map.get(emulator, :scrollback_buffer, [])
    scrollback_size = Map.get(emulator, :scrollback_limit, 1000)
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)

    %{
      emulator
      | scrollback_buffer: new_scrollback,
        scrollback_limit: scrollback_size
    }
  end

  def add_to_scrollback(nil, buffer),
    do: %{scrollback: [buffer], scrollback_size: 1000}

  def add_to_scrollback(
        %{scrollback: scrollback, scrollback_size: scrollback_size} = emulator,
        buffer
      ) do
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)
    %{emulator | scrollback: new_scrollback}
  end

  def add_to_scrollback(emulator, buffer) when is_map(emulator) do
    scrollback = Map.get(emulator, :scrollback, [])
    scrollback_size = Map.get(emulator, :scrollback_size, 1000)
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)

    Map.put(emulator, :scrollback, new_scrollback)
    |> Map.put(:scrollback_size, scrollback_size)
  end

  def add_to_scrollback(emulator, buffer) do
    scrollback = [buffer | emulator.buffer.scrollback]
    scrollback = Enum.take(scrollback, emulator.buffer.scrollback_size)
    %{emulator | buffer: %{emulator.buffer | scrollback: scrollback}}
  end

  @doc """
  Gets the scrollback history.
  """

  def get_scrollback(%Raxol.Terminal.Emulator{} = emulator),
    do: emulator.scrollback_buffer

  def get_scrollback(nil), do: []
  def get_scrollback(%{scrollback: scrollback}), do: scrollback

  def get_scrollback(emulator) when is_map(emulator),
    do: Map.get(emulator, :scrollback, [])

  def get_scrollback(emulator), do: emulator.buffer.scrollback

  @doc """
  Sets the scrollback size limit.
  """
  def set_scrollback_size(%Raxol.Terminal.Emulator{} = emulator, size)
      when is_integer(size) and size >= 0 do
    new_scrollback = Enum.take(emulator.scrollback_buffer, size)
    %{emulator | scrollback_buffer: new_scrollback, scrollback_limit: size}
  end

  def set_scrollback_size(nil, size) when is_integer(size) and size >= 0,
    do: %{scrollback: [], scrollback_size: size}

  def set_scrollback_size(%{scrollback: scrollback} = emulator, size)
      when is_integer(size) and size >= 0 do
    new_scrollback = Enum.take(scrollback, size)
    %{emulator | scrollback: new_scrollback, scrollback_size: size}
  end

  def set_scrollback_size(emulator, size)
      when is_map(emulator) and is_integer(size) and size >= 0 do
    scrollback = Map.get(emulator, :scrollback, []) |> Enum.take(size)

    Map.put(emulator, :scrollback, scrollback)
    |> Map.put(:scrollback_size, size)
  end

  @doc """
  Gets the current scrollback size limit.
  """

  def get_scrollback_size(%Raxol.Terminal.Emulator{} = emulator),
    do: emulator.scrollback_limit

  def get_scrollback_size(nil), do: 1000
  def get_scrollback_size(%{scrollback_size: size}), do: size

  def get_scrollback_size(emulator) when is_map(emulator),
    do: Map.get(emulator, :scrollback_size, 1000)

  def get_scrollback_size(emulator), do: emulator.buffer.scrollback_size

  @doc """
  Clears the scrollback history.
  """

  def clear_scrollback(%Raxol.Terminal.Emulator{} = emulator),
    do: %{emulator | scrollback_buffer: []}

  def clear_scrollback(nil), do: %{scrollback: []}

  def clear_scrollback(%{scrollback: _} = emulator),
    do: %{emulator | scrollback: []}

  def clear_scrollback(emulator) when is_map(emulator),
    do: Map.put(emulator, :scrollback, [])

  def clear_scrollback(emulator),
    do: %{emulator | buffer: %{emulator.buffer | scrollback: []}}
end
