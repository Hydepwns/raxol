defmodule Raxol.Terminal.Buffer.ScrollbackManager do
  @moduledoc """
  Manages scrollback buffer for the terminal emulator.
  """

  use GenServer
  @behaviour GenServer

  @type t :: %__MODULE__{
          max_lines: non_neg_integer(),
          current_lines: non_neg_integer(),
          lines: list(list(Raxol.Terminal.Buffer.Cell.t())),
          limit: non_neg_integer()
        }

  defstruct [
    # Default max scrollback lines
    max_lines: 1000,
    current_lines: 0,
    lines: [],
    limit: 1000
  ]

  # Client API

  @doc """
  Starts the scrollback manager process.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets the current number of scrollback lines.
  """
  def get_scrollback_count(scrollback_manager) do
    GenServer.call(scrollback_manager, :get_scrollback_count)
  end

  @doc """
  Adds a line to the scrollback buffer.
  """
  def add_line(scrollback_manager, line) do
    GenServer.call(scrollback_manager, {:add_line, line})
  end

  @doc """
  Gets a range of lines from the scrollback buffer.
  """
  def get_lines(scrollback_manager, start_line, count) do
    GenServer.call(scrollback_manager, {:get_lines, start_line, count})
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear(scrollback_manager) do
    GenServer.call(scrollback_manager, :clear)
  end

  @doc """
  Creates a new scrollback manager.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      max_lines: 1000,
      current_lines: 0,
      lines: [],
      limit: 1000
    }
  end

  # Server Callbacks

  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def handle_call(:get_scrollback_count, _from, state) do
    {:reply, state.current_lines, state}
  end

  def handle_call({:add_line, line}, _from, state) do
    new_lines = [line | state.lines]
    new_count = min(state.current_lines + 1, state.max_lines)

    new_state = %{
      state
      | lines: Enum.take(new_lines, state.max_lines),
        current_lines: new_count
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:get_lines, start_line, count}, _from, state) do
    lines =
      state.lines
      |> Enum.drop(start_line)
      |> Enum.take(count)

    {:reply, lines, state}
  end

  def handle_call(:clear, _from, state) do
    new_state = %{state | lines: [], current_lines: 0}
    {:reply, :ok, new_state}
  end
end
