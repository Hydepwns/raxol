defmodule Raxol.Terminal.Rendering.RenderServer do
  @moduledoc """
  Provides a unified interface for terminal rendering operations.
  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Terminal.Buffer

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
          screen: term(),
          style: term(),
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
  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
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
    handle_render_request(renderer.termbox_initialized, state, renderer)
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
    cleanup_termbox(Mix.env())
    {:reply, :ok, renderer}
  end

  def handle_call({:resize, width, height}, _from, renderer) do
    # Resize termbox only if not in test mode
    resize_termbox(Mix.env(), width, height)

    # Update screen buffer with new dimensions
    new_screen = Map.put(renderer.screen || %{}, :width, width)
    new_screen = Map.put(new_screen, :height, height)

    {:reply, :ok, %{renderer | screen: new_screen}}
  end

  def handle_call({:set_cursor_visibility, visible}, _from, renderer) do
    set_cursor_in_terminal(Mix.env(), visible, renderer.buffer)
    {:reply, :ok, %{renderer | cursor_visible: visible}}
  end

  def handle_call({:set_title, title}, _from, renderer) do
    # Set window title only if not in test mode
    set_title_in_terminal(Mix.env())
    {:reply, :ok, %{renderer | title: title}}
  end

  def handle_call(:get_title, _from, renderer) do
    {:reply, renderer.title, renderer}
  end

  def handle_call(:init_terminal, _from, renderer) do
    # Initialize termbox only if not in test mode
    init_termbox(Mix.env())
    {:reply, :ok, %{renderer | termbox_initialized: true}}
  end

  def handle_call(:shutdown_terminal, _from, renderer) do
    # Shutdown termbox only if not in test mode
    shutdown_termbox(Mix.env())
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
    render_cell_in_terminal(Mix.env(), col, row, cell)
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
    render_cursor_with_visibility(state.cursor_visible, state.buffer)
  end

  # Helper functions for if statement elimination

  defp handle_render_request(false, _state, renderer) do
    {:reply, {:error, :not_initialized}, renderer}
  end

  defp handle_render_request(true, state, renderer) do
    render_to_terminal_if_not_test(Mix.env(), state)
    {:reply, :ok, renderer}
  end

  defp render_to_terminal_if_not_test(:test, _state), do: :ok

  defp render_to_terminal_if_not_test(_env, state),
    do: render_to_terminal(state)

  defp cleanup_termbox(:test), do: :ok
  defp cleanup_termbox(_env), do: :termbox2_nif.tb_shutdown()

  defp resize_termbox(:test, _width, _height), do: :ok

  defp resize_termbox(_env, width, height) do
    :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)
    :termbox2_nif.tb_set_cell(width - 1, height - 1, 0, 0, 0)
  end

  defp set_cursor_in_terminal(:test, _visible, _buffer), do: :ok

  defp set_cursor_in_terminal(_env, visible, buffer) do
    set_cursor_position(visible, buffer)
  end

  defp set_cursor_position(true, buffer) do
    {x, y} = Buffer.get_cursor_position(buffer)
    :termbox2_nif.tb_set_cursor(x, y)
  end

  defp set_cursor_position(false, _buffer) do
    :termbox2_nif.tb_set_cursor(-1, -1)
  end

  defp set_title_in_terminal(:test), do: :ok
  defp set_title_in_terminal(_env), do: :termbox2_nif.tb_set_cell(0, 0, 0, 0, 0)

  defp init_termbox(:test), do: :ok
  defp init_termbox(_env), do: :termbox2_nif.tb_init()

  defp shutdown_termbox(:test), do: :ok
  defp shutdown_termbox(_env), do: :termbox2_nif.tb_shutdown()

  defp render_cell_in_terminal(:test, _col, _row, _cell), do: :ok

  defp render_cell_in_terminal(_env, col, row, cell) do
    :termbox2_nif.tb_set_cell(
      col,
      row,
      cell.char,
      cell.style.fg,
      cell.style.bg
    )
  end

  defp render_cursor_with_visibility(true, buffer) do
    {x, y} = Buffer.get_cursor_position(buffer)
    :termbox2_nif.tb_set_cursor(x, y)
  end

  defp render_cursor_with_visibility(false, _buffer) do
    :termbox2_nif.tb_set_cursor(-1, -1)
  end
end
