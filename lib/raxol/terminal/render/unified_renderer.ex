defmodule Raxol.Terminal.Render.UnifiedRenderer do
  @moduledoc """
  Unified renderer module that consolidates all terminal rendering functionality.

  This module provides a single interface for:
  - Terminal output rendering
  - Character cell management
  - Text styling and formatting
  - Cursor rendering
  - Performance optimizations
  - Integration with Termbox2
  """

  use GenServer

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.UnifiedManager,
    Cursor.Manager,
    Integration.State
  }

  require Logger

  # Types

  @type t :: %__MODULE__{
          screen_buffer: ScreenBuffer.t(),
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          theme: map(),
          font_settings: map(),
          termbox_initialized: boolean(),
          fps: non_neg_integer(),
          last_render_time: integer() | nil,
          render_queue: list(),
          cache: map()
        }

  defstruct [
    :screen_buffer,
    :cursor,
    :theme,
    :font_settings,
    termbox_initialized: false,
    fps: 60,
    last_render_time: nil,
    render_queue: [],
    cache: %{}
  ]

  # Client API

  @doc """
  Starts the unified renderer process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initializes the terminal system.
  Must be called before other rendering functions.
  """
  def init_terminal do
    GenServer.call(__MODULE__, :init_terminal)
  end

  @doc """
  Shuts down the terminal system.
  Must be called to restore terminal state.
  """
  def shutdown_terminal do
    GenServer.call(__MODULE__, :shutdown_terminal)
  end

  @doc """
  Renders the current terminal state to the screen.
  """
  def render(%State{} = state) do
    GenServer.call(__MODULE__, {:render, state})
  end

  @doc """
  Updates the renderer configuration.
  """
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  @doc """
  Sets a specific configuration value.
  """
  def set_config_value(key, value) do
    GenServer.call(__MODULE__, {:set_config_value, key, value})
  end

  @doc """
  Resets the renderer configuration to defaults.
  """
  def reset_config do
    GenServer.call(__MODULE__, :reset_config)
  end

  @doc """
  Resizes the renderer to the given dimensions.
  """
  def resize(width, height) do
    GenServer.call(__MODULE__, {:resize, width, height})
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_cursor_visibility(visible) do
    GenServer.call(__MODULE__, {:set_cursor_visibility, visible})
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(title) do
    GenServer.call(__MODULE__, {:set_title, title})
  end

  @doc """
  Gets the terminal title.
  """
  def get_title do
    GenServer.call(__MODULE__, :get_title)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    fps = Keyword.get(opts, :fps, 60)
    theme = Keyword.get(opts, :theme, %{})
    font_settings = Keyword.get(opts, :font_settings, %{})

    {:ok,
     %__MODULE__{
       fps: fps,
       theme: theme,
       font_settings: font_settings,
       cache: %{}
     }}
  end

  @impl true
  def handle_call(:init_terminal, _from, state) do
    case :termbox2_nif.tb_init() do
      0 ->
        {:reply, :ok, %{state | termbox_initialized: true}}

      error_code ->
        Logger.error("Failed to initialize terminal: #{inspect(error_code)}")
        {:reply, {:error, error_code}, state}
    end
  end

  @impl true
  def handle_call(:shutdown_terminal, _from, state) do
    case :termbox2_nif.tb_shutdown() do
      0 ->
        {:reply, :ok, %{state | termbox_initialized: false}}

      error_code ->
        Logger.error("Failed to shutdown terminal: #{inspect(error_code)}")
        {:reply, {:error, error_code}, state}
    end
  end

  @impl true
  def handle_call({:render, %State{} = state}, _from, renderer_state) do
    if renderer_state.termbox_initialized do
      active_buffer = UnifiedManager.get_active_buffer(state.buffer_manager)

      if active_buffer && active_buffer.cells do
        # Draw content to the back buffer
        case render_cells(active_buffer.cells) do
          :ok ->
            # Set cursor position
            {cursor_x, cursor_y} = Manager.get_position(state.cursor_manager)

            case :termbox2_nif.tb_set_cursor(cursor_x, cursor_y) do
              0 ->
                # Present the back buffer
                case :termbox2_nif.tb_present() do
                  0 -> {:reply, :ok, renderer_state}
                  error_code -> {:reply, {:error, {:present_failed, error_code}}, renderer_state}
                end

              error_code ->
                {:reply, {:error, {:set_cursor_failed, error_code}}, renderer_state}
            end

          error ->
            {:reply, error, renderer_state}
        end
      else
        {:reply, :ok, renderer_state}
      end
    else
      {:reply, {:error, :not_initialized}, renderer_state}
    end
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    new_state = update_renderer_config(state, config)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_config_value, key, value}, _from, state) do
    new_state = set_renderer_config_value(state, key, value)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:reset_config, _from, state) do
    new_state = reset_renderer_config(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state) do
    new_state = resize_renderer(state, width, height)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_cursor_visibility, visible}, _from, state) do
    case :termbox2_nif.tb_set_cursor_visibility(visible) do
      0 -> {:reply, :ok, state}
      error_code -> {:reply, {:error, error_code}, state}
    end
  end

  @impl true
  def handle_call({:set_title, title}, _from, state) do
    case :termbox2_nif.tb_set_title(title) do
      0 -> {:reply, :ok, state}
      error_code -> {:reply, {:error, error_code}, state}
    end
  end

  @impl true
  def handle_call(:get_title, _from, state) do
    case :termbox2_nif.tb_get_title() do
      {:ok, title} -> {:reply, title, state}
      error -> {:reply, {:error, error}, state}
    end
  end

  # Private Functions

  defp render_cells(cells) do
    cells
    |> Enum.reduce_while(:ok, fn {row_of_cells, y_offset}, _acc ->
      row_of_cells
      |> Enum.reduce_while(:ok, fn {cell, x_offset}, _inner_acc ->
        char_s = cell.char

        codepoint =
          cond do
            is_nil(char_s) or char_s == "" -> ?\s
            true -> hd(String.to_charlist(char_s))
          end

        fg_color = cell.fg
        bg_color = cell.bg

        case :termbox2_nif.tb_set_cell(x_offset, y_offset, codepoint, fg_color, bg_color) do
          0 -> {:cont, :ok}
          error_code -> {:halt, {:error, {:set_cell_failed, {x_offset, y_offset, error_code}}}}
        end
      end)
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp update_renderer_config(state, config) do
    # Update FPS if provided
    fps = Map.get(config, :fps, state.fps)

    # Update theme if provided
    theme = Map.get(config, :theme, state.theme)

    # Update font settings if provided
    font_settings = Map.get(config, :font_settings, state.font_settings)

    %{state | fps: fps, theme: theme, font_settings: font_settings}
  end

  defp set_renderer_config_value(state, key, value) do
    case key do
      :fps -> %{state | fps: value}
      :theme -> %{state | theme: value}
      :font_settings -> %{state | font_settings: value}
      _ -> state
    end
  end

  defp reset_renderer_config(state) do
    %{state |
      fps: 60,
      theme: %{},
      font_settings: %{}
    }
  end

  defp resize_renderer(state, width, height) do
    case :termbox2_nif.tb_resize(width, height) do
      0 -> %{state | screen_buffer: ScreenBuffer.new(width, height)}
      _ -> state
    end
  end
end
