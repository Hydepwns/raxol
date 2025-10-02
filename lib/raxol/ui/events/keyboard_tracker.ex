defmodule Raxol.UI.Events.KeyboardTracker do
  @moduledoc """
  Tracks keyboard events and provides accessibility support.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  defstruct [
    :config,
    :key_bindings,
    :focus_stack,
    :accessibility_mode
  ]

  ## Client API

  # BaseManager provides start_link/1 which handles GenServer initialization
  # Usage: Raxol.UI.Events.KeyboardTracker.start_link(name: __MODULE__, ...)

  def track_key_event(tracker \\ __MODULE__, event) do
    GenServer.cast(tracker, {:key_event, event})
  end

  def get_focus_stack(tracker \\ __MODULE__) do
    GenServer.call(tracker, :get_focus_stack)
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    config = Keyword.get(opts, :config, %{})

    state = %__MODULE__{
      config: config,
      key_bindings: %{},
      focus_stack: [],
      accessibility_mode: Keyword.get(opts, :accessibility_mode, false)
    }

    Log.info("Keyboard tracker initialized")
    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:key_event, event}, state) do
    # Process keyboard event
    Log.module_debug("Processing key event: #{inspect(event)}")
    {:noreply, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_focus_stack, _from, state) do
    {:reply, state.focus_stack, state}
  end
end
