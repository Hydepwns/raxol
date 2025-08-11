defmodule Raxol.Terminal.Events do
  @moduledoc """
  Global event management for terminal interactions.

  This module provides a centralized event system for handling global terminal
  events such as clicks, keyboard input, and other user interactions that need
  to be processed at the application level.
  """

  use GenServer
  require Logger

  @doc """
  Registers a global click handler that will be called whenever a click occurs.

  ## Parameters
    - `handler` - A function that takes a click position and handles the event

  ## Examples
      
      Raxol.Terminal.Events.register_global_click(fn {x, y} ->
        IO.puts("Clicked at \#{x}, \#{y}")
      end)
  """
  @spec register_global_click(function()) :: {:ok, reference()}
  def register_global_click(handler) when is_function(handler, 1) do
    ref = make_ref()
    GenServer.call(__MODULE__, {:register_click_handler, ref, handler})
    {:ok, ref}
  end

  @doc """
  Unregisters a previously registered click handler.

  ## Parameters
    - `ref` - The reference returned from register_global_click
  """
  @spec unregister_global_click(reference()) :: :ok
  def unregister_global_click(ref) when is_reference(ref) do
    GenServer.cast(__MODULE__, {:unregister_click_handler, ref})
  end

  @doc """
  Triggers a click event at the given position.

  This will call all registered click handlers.
  """
  @spec trigger_click({integer(), integer()}) :: :ok
  def trigger_click({x, y} = position) when is_integer(x) and is_integer(y) do
    GenServer.cast(__MODULE__, {:trigger_click, position})
  end

  @doc """
  Starts the events server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       click_handlers: %{},
       key_handlers: %{},
       focus_handlers: %{}
     }}
  end

  @impl true
  def handle_call({:register_click_handler, ref, handler}, _from, state) do
    new_handlers = Map.put(state.click_handlers, ref, handler)
    {:reply, :ok, %{state | click_handlers: new_handlers}}
  end

  @impl true
  def handle_cast({:unregister_click_handler, ref}, state) do
    new_handlers = Map.delete(state.click_handlers, ref)
    {:noreply, %{state | click_handlers: new_handlers}}
  end

  @impl true
  def handle_cast({:trigger_click, position}, state) do
    # Call all registered click handlers
    Enum.each(state.click_handlers, fn {_ref, handler} ->
      try do
        handler.(position)
      rescue
        error ->
          Logger.error("Click handler error: #{inspect(error)}")
      end
    end)

    {:noreply, state}
  end
end
