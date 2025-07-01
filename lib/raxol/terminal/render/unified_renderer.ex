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
    :title,
    :termbox_initialized,
    :config
  ]

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          screen: Screen.t(),
          style: Style.t(),
          cursor_visible: boolean(),
          title: String.t(),
          termbox_initialized: boolean(),
          config: map()
        }

  # Client API

  @doc """
  Starts the renderer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
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

  @doc """
  Gets the current window title.
  """
  @spec get_title() :: String.t()
  def get_title do
    GenServer.call(__MODULE__, :get_title)
  end

  @doc """
  Initializes the terminal.
  """
  @spec init_terminal() :: :ok
  def init_terminal do
    GenServer.call(__MODULE__, :init_terminal)
  end

  @doc """
  Shuts down the terminal.
  """
  @spec shutdown_terminal() :: :ok
  def shutdown_terminal do
    GenServer.call(__MODULE__, :shutdown_terminal)
  end

  @doc """
  Sets a specific configuration value.
  """
  @spec set_config_value(atom(), any()) :: :ok
  def set_config_value(key, value) do
    GenServer.call(__MODULE__, {:set_config_value, key, value})
  end

  @doc """
  Resets the configuration to defaults.
  """
  @spec reset_config() :: :ok
  def reset_config do
    GenServer.call(__MODULE__, :reset_config)
  end

  # Server Callbacks

  @doc """
  Initializes the GenServer with default state.
  """
  @impl GenServer
  def init(opts) do
    initial_state = %__MODULE__{
      buffer: opts[:buffer] || Buffer.new(),
      screen: opts[:screen] || %{},
      style: opts[:style] || %{},
      cursor_visible: opts[:cursor_visible] || true,
      title: opts[:title] || "",
      termbox_initialized: false,
      config: opts[:config] || %{}
    }

    {:ok, initial_state}
  end

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

  def handle_call({:update_config, _state, config}, _from, renderer) do
    # Handle config structure where rendering settings are under :rendering key
    rendering_config = config[:rendering] || config

    new_state = %{
      renderer
      | style: Map.merge(renderer.style, rendering_config[:style] || %{}),
        cursor_visible:
          Map.get(rendering_config, :cursor_visible, renderer.cursor_visible)
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:cleanup, _state}, _from, renderer) do
    # Cleanup termbox
    :termbox2_nif.tb_shutdown()
    {:reply, :ok, renderer}
  end

  def handle_call({:resize, width, height}, _from, renderer) do
    # Resize termbox
    :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)
    :termbox2_nif.tb_set_cell(width - 1, height - 1, 0, 0, 0)

    {:reply, :ok, renderer}
  end

  def handle_call({:set_cursor_visibility, visible}, _from, renderer) do
    if visible do
      {x, y} = Buffer.get_cursor_position(renderer.buffer)
      :termbox2_nif.tb_set_cursor(x, y)
    else
      :termbox2_nif.tb_set_cursor(-1, -1)
    end

    {:reply, :ok, %{renderer | cursor_visible: visible}}
  end

  def handle_call({:set_title, title}, _from, renderer) do
    # Set window title
    :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)

    {:reply, :ok, %{renderer | title: title}}
  end

  def handle_call(:get_title, _from, renderer) do
    {:reply, renderer.title, renderer}
  end

  def handle_call(:init_terminal, _from, renderer) do
    # Initialize termbox
    :termbox2_nif.tb_init()
    {:reply, :ok, %{renderer | termbox_initialized: true}}
  end

  def handle_call(:shutdown_terminal, _from, renderer) do
    # Shutdown termbox
    :termbox2_nif.tb_shutdown()
    {:reply, :ok, %{renderer | termbox_initialized: false}}
  end

  def handle_call({:set_config_value, key, value}, _from, renderer) do
    new_config = Map.put(renderer.config || %{}, key, value)
    {:reply, :ok, %{renderer | config: new_config}}
  end

  def handle_call(:reset_config, _from, renderer) do
    default_config = %{
      fps: 60,
      theme: %{foreground: :white, background: :black},
      font_settings: %{size: 12}
    }

    {:reply, :ok, %{renderer | config: default_config}}
  end

  # Private functions

  defp render_cell(col, row, cell) do
    :termbox2_nif.tb_set_cell(col, row, cell.char, cell.style.fg, cell.style.bg)
  end
end
