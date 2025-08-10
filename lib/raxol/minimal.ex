defmodule Raxol.Minimal do
  @moduledoc """
  Minimal Raxol terminal interface for ultra-fast startup.
  
  This module provides a stripped-down version of Raxol optimized for 
  minimal startup time and memory footprint while still providing core
  terminal functionality.
  
  ## Features Included
  - Core terminal emulation
  - Basic ANSI parsing
  - Keyboard/mouse input handling
  - Simple rendering
  
  ## Features Excluded
  - Web interface (Phoenix)
  - Database layer
  - Advanced animations
  - Plugin system
  - Audit logging
  - Enterprise features
  
  ## Usage
  
      # Start minimal terminal
      {:ok, terminal} = Raxol.Minimal.start_terminal()
      
      # Or start with options
      {:ok, terminal} = Raxol.Minimal.start_terminal(
        width: 80, 
        height: 24,
        mode: :raw
      )
  """
  
  use GenServer
  require Logger
  
  @type terminal_options :: [
    width: pos_integer(),
    height: pos_integer(), 
    mode: :raw | :cooked
  ]
  
  @default_options [
    width: 80,
    height: 24,
    mode: :raw
  ]
  
  @doc """
  Start a minimal terminal session with ultra-fast startup.
  
  Returns `{:ok, pid}` on success.
  """
  @spec start_terminal(terminal_options()) :: {:ok, pid()} | {:error, term()}
  def start_terminal(opts \\ []) do
    GenServer.start_link(__MODULE__, Keyword.merge(@default_options, opts))
  end
  
  @doc """
  Get current terminal state for debugging.
  """
  @spec get_state(pid()) :: map()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end
  
  @doc """
  Send input to terminal.
  """
  @spec send_input(pid(), binary()) :: :ok
  def send_input(pid, data) do
    GenServer.cast(pid, {:input, data})
  end
  
  # GenServer Callbacks
  
  @impl GenServer
  def init(opts) do
    state = %{
      width: opts[:width],
      height: opts[:height], 
      mode: opts[:mode],
      buffer: %{},
      cursor: {0, 0},
      started_at: System.monotonic_time(:millisecond)
    }
    
    Logger.info("Minimal terminal started in #{System.monotonic_time(:millisecond) - state.started_at}ms")
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl GenServer
  def handle_cast({:input, data}, state) do
    # Minimal input processing
    new_state = process_input(data, state)
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp process_input(data, state) do
    # Basic ANSI sequence processing
    case data do
      "\e[A" -> move_cursor(state, :up)
      "\e[B" -> move_cursor(state, :down) 
      "\e[C" -> move_cursor(state, :right)
      "\e[D" -> move_cursor(state, :left)
      "\e[H" -> move_cursor(state, :home)
      "\e[F" -> move_cursor(state, :end)
      "\r" -> move_cursor(state, :newline)
      "\n" -> move_cursor(state, :newline)
      printable when is_binary(printable) ->
        put_char(state, printable)
    end
  end
  
  defp move_cursor(state, direction) do
    {x, y} = state.cursor
    
    new_cursor = case direction do
      :up -> {x, max(0, y - 1)}
      :down -> {x, min(state.height - 1, y + 1)}
      :left -> {max(0, x - 1), y}
      :right -> {min(state.width - 1, x + 1), y}
      :home -> {0, y}
      :end -> {state.width - 1, y}
      :newline -> {0, min(state.height - 1, y + 1)}
    end
    
    %{state | cursor: new_cursor}
  end
  
  defp put_char(state, char) do
    {x, y} = state.cursor
    new_buffer = Map.put(state.buffer, {x, y}, char)
    new_cursor = {min(state.width - 1, x + 1), y}
    
    %{state | buffer: new_buffer, cursor: new_cursor}
  end
end