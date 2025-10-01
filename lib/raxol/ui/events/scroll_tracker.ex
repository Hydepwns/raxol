defmodule Raxol.UI.Events.ScrollTracker do
  @moduledoc """
  Tracks scroll events for virtual scrolling components.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  defstruct [
    :config,
    :scroll_position,
    :scroll_velocity,
    :virtual_viewport
  ]

  ## Client API

  # BaseManager provides start_link/1 which handles GenServer initialization
  # Usage: Raxol.UI.Events.ScrollTracker.start_link(name: __MODULE__, ...)

  def track_scroll(tracker \\ __MODULE__, position) do
    GenServer.cast(tracker, {:scroll, position})
  end

  def get_scroll_position(tracker \\ __MODULE__) do
    GenServer.call(tracker, :get_position)
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    config = Keyword.get(opts, :config, %{})

    state = %__MODULE__{
      config: config,
      scroll_position: 0,
      scroll_velocity: 0,
      virtual_viewport: nil
    }

    Log.module_info("Scroll tracker initialized")
    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:scroll, position}, state) do
    new_state = %{state | scroll_position: position}
    {:noreply, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_position, _from, state) do
    {:reply, state.scroll_position, state}
  end
end
