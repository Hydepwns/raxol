defmodule Raxol.Sensor.HUDOverlay do
  @moduledoc """
  Glue layer: subscribes to Fusion updates, renders HUD widgets,
  writes cells to a buffer.
  """

  use GenServer

  require Logger

  alias Raxol.Sensor.HUD

  @type layout_entry :: %{
          widget: :gauge | :sparkline | :threat | :minimap,
          region: HUD.region(),
          sensor_id: atom(),
          opts: keyword()
        }

  @type t :: %__MODULE__{
          fusion_pid: pid() | nil,
          buffer_pid: pid() | nil,
          layout: [layout_entry()],
          last_fused_state: map()
        }

  defstruct fusion_pid: nil,
            buffer_pid: nil,
            layout: [],
            last_fused_state: %{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    fusion_pid = Keyword.get(opts, :fusion_pid)
    buffer_pid = Keyword.get(opts, :buffer_pid)
    layout = Keyword.get(opts, :layout, [])

    state = %__MODULE__{
      fusion_pid: fusion_pid,
      buffer_pid: buffer_pid,
      layout: layout
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:fused_update, fused_state}, %__MODULE__{} = state) do
    cells = render_layout(state.layout, fused_state)

    if state.buffer_pid do
      send(state.buffer_pid, {:hud_cells, cells})
    end

    {:noreply, %__MODULE__{state | last_fused_state: fused_state}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp render_layout(layout, fused_state) do
    Enum.flat_map(layout, fn entry ->
      sensor_data = get_in(fused_state, [:sensors, entry.sensor_id])
      render_widget(entry.widget, entry.region, sensor_data, entry.opts)
    end)
  end

  defp render_widget(_widget, _region, nil, _opts), do: []

  defp render_widget(:gauge, region, sensor_data, opts) do
    value_key = Keyword.get(opts, :value_key, :value)
    value = get_in(sensor_data, [:values, value_key]) || 0.0
    HUD.render_gauge(region, value, opts)
  end

  defp render_widget(:sparkline, region, sensor_data, opts) do
    value_key = Keyword.get(opts, :value_key, :value)
    value = get_in(sensor_data, [:values, value_key]) || 0.0
    # Sparkline needs a list; single fused value wraps in list
    values = Keyword.get(opts, :values, [value])
    HUD.render_sparkline(region, values, opts)
  end

  defp render_widget(:threat, region, sensor_data, opts) do
    level_key = Keyword.get(opts, :level_key, :level)
    bearing_key = Keyword.get(opts, :bearing_key, :bearing)
    level = get_in(sensor_data, [:values, level_key]) || :none
    bearing = get_in(sensor_data, [:values, bearing_key]) || 0
    HUD.render_threat(region, level, bearing, opts)
  end

  defp render_widget(:minimap, region, _sensor_data, opts) do
    entities = Keyword.get(opts, :entities, [])
    HUD.render_minimap(region, entities, opts)
  end

  defp render_widget(_widget, _region, _data, _opts), do: []
end
