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
    :fps,
    :theme,
    :font_settings,
    :cache
  ]

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          screen: Screen.t(),
          style: Style.t(),
          cursor_visible: boolean(),
          title: String.t(),
          termbox_initialized: boolean(),
          fps: integer(),
          theme: map(),
          font_settings: map(),
          cache: map()
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
  def cleanup(%__MODULE__{} = state) do
    GenServer.call(__MODULE__, {:cleanup, state})
  end

  def cleanup(_other) do
    # Handle cases where a plain map or other type is passed
    :ok
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
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _ -> GenServer.call(__MODULE__, :shutdown_terminal)
    end
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
    initial_state = build_initial_state(opts)
    {:ok, initial_state}
  end

  defp build_initial_state(opts) do
    %__MODULE__{
      buffer: get_opt(opts, :buffer, &Buffer.new/0),
      screen: get_opt(opts, :screen, %{}),
      style: get_opt(opts, :style, %{}),
      cursor_visible: get_opt(opts, :cursor_visible, true),
      title: get_opt(opts, :title, ""),
      termbox_initialized: false,
      fps: get_opt(opts, :fps, 60),
      theme: get_opt(opts, :theme, %{}),
      font_settings: get_opt(opts, :font_settings, %{}),
      cache: get_opt(opts, :cache, %{})
    }
  end

  defp get_opt(opts, key, default) when is_function(default, 0) do
    opts[key] || default.()
  end

  defp get_opt(opts, key, default) do
    opts[key] || default
  end

  @impl true
  def handle_call({:render, state}, _from, renderer) do
    if renderer.termbox_initialized do
      if Mix.env() != :test do
        render_to_terminal(state)
      end
      {:reply, :ok, renderer}
    else
      {:reply, {:error, :not_initialized}, renderer}
    end
  end

  @impl true
  def handle_call({:update_config, _state, config}, _from, renderer) do
    new_state = %{
      renderer
      | fps: Map.get(config, :fps, renderer.fps),
        theme: Map.get(config, :theme, renderer.theme),
        font_settings: Map.get(config, :font_settings, renderer.font_settings),
        style: Map.merge(renderer.style, Map.get(config, :style, %{})),
        cursor_visible:
          Map.get(config, :cursor_visible, renderer.cursor_visible)
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:cleanup, _state}, _from, renderer) do
    # Cleanup termbox only if not in test mode
    if Mix.env() != :test do
      :termbox2_nif.tb_shutdown()
    end

    {:reply, :ok, renderer}
  end

  def handle_call({:resize, width, height}, _from, renderer) do
    # Resize termbox only if not in test mode
    if Mix.env() != :test do
      :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)
      :termbox2_nif.tb_set_cell(width - 1, height - 1, 0, 0, 0)
    end

    # Update screen buffer with new dimensions
    new_screen = Map.put(renderer.screen || %{}, :width, width)
    new_screen = Map.put(new_screen, :height, height)

    {:reply, :ok, %{renderer | screen: new_screen}}
  end

  def handle_call({:set_cursor_visibility, visible}, _from, renderer) do
    if Mix.env() != :test do
      if visible do
        {x, y} = Buffer.get_cursor_position(renderer.buffer)
        :termbox2_nif.tb_set_cursor(x, y)
      else
        :termbox2_nif.tb_set_cursor(-1, -1)
      end
    end

    {:reply, :ok, %{renderer | cursor_visible: visible}}
  end

  def handle_call({:set_title, title}, _from, renderer) do
    # Set window title only if not in test mode
    if Mix.env() != :test do
      :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)
    end

    {:reply, :ok, %{renderer | title: title}}
  end

  def handle_call(:get_title, _from, renderer) do
    {:reply, renderer.title, renderer}
  end

  def handle_call(:init_terminal, _from, renderer) do
    # Initialize termbox only if not in test mode
    if Mix.env() != :test do
      :termbox2_nif.tb_init()
    end

    {:reply, :ok, %{renderer | termbox_initialized: true}}
  end

  def handle_call(:shutdown_terminal, _from, renderer) do
    # Shutdown termbox only if not in test mode
    if Mix.env() != :test do
      :termbox2_nif.tb_shutdown()
    end

    {:reply, :ok, %{renderer | termbox_initialized: false}}
  end

  def handle_call({:set_config_value, key, value}, _from, renderer) do
    new_state =
      case key do
        :fps -> %{renderer | fps: value}
        :theme -> %{renderer | theme: value}
        :font_settings -> %{renderer | font_settings: value}
        _ -> renderer
      end

    {:reply, :ok, new_state}
  end

  def handle_call(:reset_config, _from, renderer) do
    new_state = %{
      renderer
      | fps: 60,
        theme: %{},
        font_settings: %{}
    }

    {:reply, :ok, new_state}
  end

  # Private functions

  defp render_cell(col, row, cell) do
    if Mix.env() != :test do
      :termbox2_nif.tb_set_cell(
        col,
        row,
        cell.char,
        cell.style.fg,
        cell.style.bg
      )
    end
  end

  defp render_to_terminal(state) do
    :termbox2_nif.tb_init()
    :termbox2_nif.tb_clear()
    render_cells(state.buffer.cells)
    render_cursor(state)
    :termbox2_nif.tb_present()
  end

  defp render_cells(cells) do
    Enum.each(cells, fn {row, cells} ->
      Enum.each(cells, fn {col, cell} ->
        render_cell(col, row, cell)
      end)
    end)
  end

  defp render_cursor(state) do
    if state.cursor_visible do
      {x, y} = Buffer.get_cursor_position(state.buffer)
      :termbox2_nif.tb_set_cursor(x, y)
    else
      :termbox2_nif.tb_set_cursor(-1, -1)
    end
  end
end
