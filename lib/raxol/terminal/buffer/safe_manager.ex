defmodule Raxol.Terminal.Buffer.SafeManager do
  @moduledoc """
  Safe buffer manager that handles buffer operations with error recovery.

  This module provides a safe interface to buffer operations, ensuring
  that failures don't crash the system and providing fallback behavior.
  """

  @doc """
  Starts a safe manager process.
  """
  @spec start_link() :: {:ok, pid()} | {:error, term()}
  def start_link do
    # For now, delegate to regular Manager
    GenServer.start_link(Raxol.Terminal.ScreenBuffer.Manager, %{},
      name: __MODULE__
    )
  end

  @doc """
  Safely writes data to the buffer.
  """
  @spec write(pid() | atom(), binary()) :: :ok | {:error, term()}
  def write(manager, data) when is_binary(data) do
    try do
      GenServer.call(manager, {:write, data})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def write(_manager, _data), do: {:error, :invalid_data}

  @doc """
  Safely reads from the buffer.
  """
  @spec read(pid() | atom(), non_neg_integer()) ::
          {:ok, binary()} | {:error, term()}
  def read(manager, count) when is_integer(count) and count > 0 do
    try do
      GenServer.call(manager, {:read, count})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def read(_manager, _count), do: {:error, :invalid_count}

  @doc """
  Safely resizes the buffer.
  """
  @spec resize(pid() | atom(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, term()}
  def resize(manager, width, height)
      when is_integer(width) and width > 0 and
             is_integer(height) and height > 0 do
    try do
      GenServer.call(manager, {:resize, width, height})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def resize(_manager, _width, _height), do: {:error, :invalid_dimensions}

  @doc """
  Safely clears the buffer.
  """
  @spec clear(pid() | atom()) :: :ok | {:error, term()}
  def clear(manager) do
    try do
      GenServer.call(manager, :clear)
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  @doc """
  Gets buffer info safely.
  """
  @spec info(pid() | atom()) :: {:ok, map()} | {:error, term()}
  def info(manager) do
    try do
      GenServer.call(manager, :info)
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  @doc """
  Safely gets a cell from the buffer.
  """
  @spec get_cell(pid() | atom(), non_neg_integer(), non_neg_integer()) ::
          {:ok, map()} | {:error, term()}
  def get_cell(manager, x, y)
      when is_integer(x) and x >= 0 and
             is_integer(y) and y >= 0 do
    try do
      GenServer.call(manager, {:get_cell, x, y})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def get_cell(_manager, _x, _y), do: {:error, :invalid_coordinates}

  @doc """
  Safely sets a cell in the buffer.
  """
  @spec set_cell(pid() | atom(), non_neg_integer(), non_neg_integer(), map()) ::
          :ok | {:error, term()}
  def set_cell(manager, x, y, cell)
      when is_integer(x) and x >= 0 and
             is_integer(y) and y >= 0 and
             is_map(cell) do
    try do
      GenServer.call(manager, {:set_cell, x, y, cell})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def set_cell(_manager, _x, _y, _cell), do: {:error, :invalid_arguments}

  @doc """
  Safely scrolls the buffer.
  """
  @spec scroll(pid() | atom(), integer()) :: :ok | {:error, term()}
  def scroll(manager, lines) when is_integer(lines) do
    try do
      GenServer.call(manager, {:scroll, lines})
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  def scroll(_manager, _lines), do: {:error, :invalid_lines}
end
