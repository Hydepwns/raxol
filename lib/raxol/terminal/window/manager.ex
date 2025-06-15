defmodule Raxol.Terminal.Window.Manager do
  @moduledoc """
  Manages terminal window properties and state.
  Handles window title, size, position, and other window-related operations.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_window_title(pid \\ __MODULE__, title) do
    GenServer.call(pid, {:set_window_title, title})
  end

  def set_icon_name(pid \\ __MODULE__, name) do
    GenServer.call(pid, {:set_icon_name, name})
  end

  def set_window_size(pid \\ __MODULE__, width, height) do
    GenServer.call(pid, {:set_window_size, width, height})
  end

  def set_window_position(pid \\ __MODULE__, x, y) do
    GenServer.call(pid, {:set_window_position, x, y})
  end

  def set_stacking_order(pid \\ __MODULE__, order) do
    GenServer.call(pid, {:set_stacking_order, order})
  end

  def get_window_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_window_state)
  end

  def save_window_size(pid \\ __MODULE__) do
    GenServer.call(pid, :save_window_size)
  end

  def restore_window_size(pid \\ __MODULE__) do
    GenServer.call(pid, :restore_window_size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       title: "Terminal",
       icon_name: "Terminal",
       size: {80, 24},
       position: {0, 0},
       stacking_order: :normal,
       saved_size: nil
     }}
  end

  @impl true
  def handle_call({:set_window_title, title}, _from, state) do
    {:reply, :ok, %{state | title: title}}
  end

  @impl true
  def handle_call({:set_icon_name, name}, _from, state) do
    {:reply, :ok, %{state | icon_name: name}}
  end

  @impl true
  def handle_call({:set_window_size, width, height}, _from, state) do
    {:reply, :ok, %{state | size: {width, height}}}
  end

  @impl true
  def handle_call({:set_window_position, x, y}, _from, state) do
    {:reply, :ok, %{state | position: {x, y}}}
  end

  @impl true
  def handle_call({:set_stacking_order, order}, _from, state) do
    {:reply, :ok, %{state | stacking_order: order}}
  end

  @impl true
  def handle_call(:get_window_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:save_window_size, _from, state) do
    {:reply, :ok, %{state | saved_size: state.size}}
  end

  @impl true
  def handle_call(:restore_window_size, _from, state) do
    case state.saved_size do
      nil -> {:reply, {:error, :no_saved_size}, state}
      size -> {:reply, :ok, %{state | size: size}}
    end
  end

  @impl true
  def handle_call(request, _from, state) do
    Logger.warning("Unhandled call: #{inspect(request)}")
    {:reply, {:error, :unknown_call}, state}
  end
end
