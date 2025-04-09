defmodule Raxol.Terminal.Session do
  @moduledoc """
  Terminal session module.

  This module manages terminal sessions, including:
  - Session lifecycle
  - Input/output handling
  - State management
  - Configuration
  """

  use GenServer
  require Logger

  # alias Raxol.Core.Events.Event # Unused
  # alias Raxol.Core.Runtime.EventLoop # Unused
  # alias Raxol.Core.I18n # Unused
  # alias Raxol.Terminal.{Cell, ScreenBuffer, Input, Emulator, Renderer} # Simplify aliases
  alias Raxol.Terminal.{Emulator, Renderer}

  @type t :: %__MODULE__{
    id: String.t(),
    emulator: Emulator.t(),
    renderer: Renderer.t(),
    width: non_neg_integer(),
    height: non_neg_integer(),
    title: String.t(),
    theme: map()
  }

  defstruct [
    :id,
    :emulator,
    :renderer,
    :width,
    :height,
    :title,
    :theme
  ]

  @doc """
  Starts a new terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link(%{width: 80, height: 24})
      iex> Process.alive?(pid)
      true
  """
  def start_link(opts \\ []) do
    id = Keyword.get(opts, :id, UUID.uuid4())
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    title = Keyword.get(opts, :title, "Terminal")
    theme = Keyword.get(opts, :theme, %{})

    GenServer.start_link(__MODULE__, {id, width, height, title, theme})
  end

  @doc """
  Stops a terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link()
      iex> :ok = Session.stop(pid)
      iex> Process.alive?(pid)
      false
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Sends input to a terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link()
      iex> :ok = Session.send_input(pid, "test")
      iex> state = Session.get_state(pid)
      iex> state.input.buffer
      "test"
  """
  def send_input(pid, input) do
    GenServer.cast(pid, {:input, input})
  end

  @doc """
  Gets the current state of a terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link()
      iex> state = Session.get_state(pid)
      iex> state.width
      80
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Updates the configuration of a terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link()
      iex> :ok = Session.update_config(pid, %{width: 100, height: 30})
      iex> state = Session.get_state(pid)
      iex> state.width
      100
  """
  def update_config(pid, config) do
    GenServer.call(pid, {:update_config, config})
  end

  @spec count_active_sessions() :: non_neg_integer()
  def count_active_sessions do
    Raxol.Terminal.Registry.count()
  end

  # Callbacks

  @impl true
  def init({id, width, height, title, theme}) do
    emulator = Emulator.new(width, height)
    renderer = Renderer.new(emulator.screen_buffer, theme)

    state = %__MODULE__{
      id: id,
      emulator: emulator,
      renderer: renderer,
      width: width,
      height: height,
      title: title,
      theme: theme
    }

    _ = Raxol.Terminal.Registry.register(id, state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:input, input}, state) do
    case Emulator.process_input(state.emulator, input) do
      {new_emulator, _output} when is_struct(new_emulator, Raxol.Terminal.Emulator) ->
        new_renderer = %{state.renderer | screen_buffer: new_emulator.screen_buffer}
        {:noreply, %{state | emulator: new_emulator, renderer: new_renderer}}
      {:error, reason} ->
        Logger.error("Error processing terminal input: #{inspect(reason)}")
        {:noreply, state} # Or handle error appropriately
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    new_state = update_state_from_config(state, config)
    _ = Raxol.Terminal.Registry.register(state.id, new_state)

    {:reply, :ok, new_state}
  end

  # Private functions

  defp update_state_from_config(state, config) do
    width = Map.get(config, :width, state.width)
    height = Map.get(config, :height, state.height)
    title = Map.get(config, :title, state.title)
    theme = Map.get(config, :theme, state.theme)

    emulator = Emulator.new(width, height)
    renderer = Renderer.new(emulator.screen_buffer, theme)

    %{state |
      emulator: emulator,
      renderer: renderer,
      width: width,
      height: height,
      title: title,
      theme: theme
    }
  end
end
