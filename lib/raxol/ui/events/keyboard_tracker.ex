defmodule Raxol.UI.Events.KeyboardTracker do
  @moduledoc """
  Tracks keyboard events and provides accessibility support.
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :key_bindings,
    :focus_stack,
    :accessibility_mode
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def track_key_event(tracker \\ __MODULE__, event) do
    GenServer.cast(tracker, {:key_event, event})
  end

  def get_focus_stack(tracker \\ __MODULE__) do
    GenServer.call(tracker, :get_focus_stack)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(opts) do
    config = Keyword.get(opts, :config, %{})

    state = %__MODULE__{
      config: config,
      key_bindings: %{},
      focus_stack: [],
      accessibility_mode: Keyword.get(opts, :accessibility_mode, false)
    }

    Logger.info("Keyboard tracker initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:key_event, event}, state) do
    # Process keyboard event
    Logger.debug("Processing key event: #{inspect(event)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_focus_stack, _from, state) do
    {:reply, state.focus_stack, state}
  end
end
