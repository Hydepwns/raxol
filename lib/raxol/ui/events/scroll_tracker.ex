defmodule Raxol.UI.Events.ScrollTracker do
  @moduledoc """
  Tracks scroll events for virtual scrolling components.
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :scroll_position,
    :scroll_velocity,
    :virtual_viewport
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def track_scroll(tracker \\ __MODULE__, position) do
    GenServer.cast(tracker, {:scroll, position})
  end

  def get_scroll_position(tracker \\ __MODULE__) do
    GenServer.call(tracker, :get_position)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(opts) do
    config = Keyword.get(opts, :config, %{})
    
    state = %__MODULE__{
      config: config,
      scroll_position: 0,
      scroll_velocity: 0,
      virtual_viewport: nil
    }

    Logger.info("Scroll tracker initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:scroll, position}, state) do
    new_state = %{state | scroll_position: position}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state) do
    {:reply, state.scroll_position, state}
  end
end