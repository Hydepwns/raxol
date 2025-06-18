defmodule Raxol.Terminal.Render.UnifiedRenderer do
  @moduledoc """
  Provides a unified interface for terminal rendering operations.
  """

  use GenServer

  alias Raxol.Terminal.{
    Buffer,
    Style
  }

  defstruct [
    :buffer,
    :screen,
    :style,
    :cursor_visible,
    :title
  ]

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          screen: Screen.t(),
          style: Style.t(),
          cursor_visible: boolean(),
          title: String.t()
        }

  # Client API

  @doc """
  Starts the renderer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Renders the current state.
  """
  @spec render(t()) :: :ok
  def render(state) do
    GenServer.call(__MODULE__, {:render, state})
  end

  @doc """
  Renders the current state with a specific renderer ID.
  """
  @spec render(t(), String.t()) :: :ok
  def render(state, _renderer_id) do
    GenServer.call(__MODULE__, {:render, state})
  end

  @doc """
  Updates the renderer configuration.
  """
  @spec update_config(t(), map()) :: :ok
  def update_config(state, config) do
    GenServer.call(__MODULE__, {:update_config, state, config})
  end

  @doc """
  Updates the renderer configuration with a single argument.
  """
  @spec update_config(map()) :: :ok
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, nil, config})
  end

  @doc """
  Cleans up resources.
  """
  @spec cleanup(t()) :: :ok
  def cleanup(state) do
    GenServer.call(__MODULE__, {:cleanup, state})
  end

  @doc """
  Resizes the renderer.
  """
  @spec resize(non_neg_integer(), non_neg_integer()) :: :ok
  def resize(width, height) do
    GenServer.call(__MODULE__, {:resize, width, height})
  end

  @doc """
  Sets cursor visibility.
  """
  @spec set_cursor_visibility(boolean()) :: :ok
  def set_cursor_visibility(visible) do
    GenServer.call(__MODULE__, {:set_cursor_visibility, visible})
  end

  @doc """
  Sets the window title.
  """
  @spec set_title(String.t()) :: :ok
  def set_title(title) do
    GenServer.call(__MODULE__, {:set_title, title})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    buffer = Keyword.get(opts, :buffer)
    screen = Keyword.get(opts, :screen)
    style = Keyword.get(opts, :style)
    cursor_visible = Keyword.get(opts, :cursor_visible, true)
    title = Keyword.get(opts, :title, "")

    state = %__MODULE__{
      buffer: buffer,
      screen: screen,
      style: style,
      cursor_visible: cursor_visible,
      title: title
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:render, state}, _from, renderer) do
    # Initialize termbox if not already initialized
    :termbox2_nif.tb_init()

    # Clear the screen
    :termbox2_nif.tb_clear()

    # Render each cell
    Enum.each(state.buffer.cells, fn {row, cells} ->
      Enum.each(cells, fn {col, cell} ->
        render_cell(col, row, cell)
      end)
    end)

    # Set cursor position if visible
    if state.cursor_visible do
      {x, y} = Buffer.get_cursor_position(state.buffer)
      :termbox2_nif.tb_set_cursor(x, y)
    else
      :termbox2_nif.tb_set_cursor(-1, -1)
    end

    # Present the changes
    :termbox2_nif.tb_present()

    {:reply, :ok, renderer}
  end

  @impl true
  def handle_call({:update_config, _state, config}, _from, renderer) do
    new_state = %{
      renderer
      | style: Map.merge(renderer.style, config.style || %{}),
        cursor_visible:
          Map.get(config, :cursor_visible, renderer.cursor_visible)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:cleanup, _state}, _from, renderer) do
    # Cleanup termbox
    :termbox2_nif.tb_shutdown()
    {:reply, :ok, renderer}
  end

  @impl true
  def handle_call({:resize, width, height}, _from, renderer) do
    # Resize termbox
    :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)
    :termbox2_nif.tb_set_cell(width - 1, height - 1, 0, 0, 0)

    {:reply, :ok, renderer}
  end

  @impl true
  def handle_call({:set_cursor_visibility, visible}, _from, renderer) do
    if visible do
      {x, y} = Buffer.get_cursor_position(renderer.buffer)
      :termbox2_nif.tb_set_cursor(x, y)
    else
      :termbox2_nif.tb_set_cursor(-1, -1)
    end

    {:reply, :ok, %{renderer | cursor_visible: visible}}
  end

  @impl true
  def handle_call({:set_title, title}, _from, renderer) do
    # Set window title
    :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)

    {:reply, :ok, %{renderer | title: title}}
  end

  # Private functions

  defp render_cell(col, row, cell) do
    :termbox2_nif.tb_set_cell(col, row, cell.char, cell.style.fg, cell.style.bg)
  end
end
