defmodule Raxol.UI.Theming.ColorManager do
  @moduledoc """
  Manages color palettes and color transformations for themes.
  """

  use GenServer
  require Logger

  defstruct [
    :current_palette,
    :palettes,
    :contrast_ratio
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def update_palette(manager \\ __MODULE__, palette) do
    GenServer.call(manager, {:update_palette, palette})
  end

  def get_palette(manager \\ __MODULE__) do
    GenServer.call(manager, :get_palette)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      current_palette: %{
        primary: "#007acc",
        secondary: "#666",
        background: "#ffffff",
        text: "#000000"
      },
      palettes: %{},
      contrast_ratio: 4.5
    }

    Logger.info("Color manager initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:update_palette, palette}, _from, state) do
    new_state = %{
      state
      | current_palette: Map.merge(state.current_palette, palette)
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_palette, _from, state) do
    {:reply, state.current_palette, state}
  end
end
