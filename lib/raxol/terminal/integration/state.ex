defmodule Raxol.Terminal.Integration.State do
  @moduledoc """
  Manages the state of the integrated terminal system.
  """

  alias Raxol.Terminal.{
    Emulator,
    Renderer,
    Buffer.Manager,
    Buffer.Scroll,
    Cursor.Manager,
    Commands.History,
    MemoryManager
  }

  @type t :: %__MODULE__{
          emulator: Emulator.t(),
          renderer: Renderer.t(),
          buffer_manager: Manager.t(),
          scroll_buffer: Scroll.t(),
          cursor_manager: Manager.t(),
          command_history: History.t(),
          config: map(),
          last_cleanup: integer()
        }

  defstruct [
    :emulator,
    :renderer,
    :buffer_manager,
    :scroll_buffer,
    :cursor_manager,
    :command_history,
    :config,
    :last_cleanup
  ]

  @doc """
  Creates a new terminal state with the specified dimensions.
  """
  def new(width, height, config) do
    emulator = Emulator.new(width, height)

    {:ok, buffer_manager} =
      Manager.new(
        width,
        height,
        config.behavior.scrollback_lines,
        config.memory_limit || 50 * 1024 * 1024
      )

    renderer =
      Renderer.new(Emulator.get_active_buffer(emulator), config.ansi.colors)

    scroll_buffer = Scroll.new(config.behavior.scrollback_lines)
    cursor_manager = Manager.new()
    command_history = History.new((config.behavior.save_history && 1000) || 0)

    %__MODULE__{
      emulator: emulator,
      renderer: renderer,
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer,
      cursor_manager: cursor_manager,
      command_history: command_history,
      config: config,
      last_cleanup: System.system_time(:millisecond)
    }
  end

  @doc """
  Updates the terminal state with new components.
  """
  def update(%__MODULE__{} = state, updates) do
    state = struct!(state, updates)
    MemoryManager.check_and_cleanup(state)
  end

  @doc """
  Gets the current visible content from the terminal state.
  """
  def get_visible_content(%__MODULE__{} = state) do
    state.buffer_manager
    |> Manager.get_visible_content()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(&Enum.join/1)
    |> Enum.join("\n")
  end

  @doc """
  Gets the current cursor position from the terminal state.
  """
  def get_cursor_position(%__MODULE__{} = state) do
    state.cursor_manager
    |> Manager.get_position()
  end

  @doc """
  Gets the current scroll position from the terminal state.
  """
  def get_scroll_position(%__MODULE__{} = state) do
    state.scroll_buffer
    |> Scroll.get_position()
  end

  @doc """
  Gets the current command history from the terminal state.
  """
  def get_command_history(%__MODULE__{} = state) do
    state.command_history
    |> History.get_entries()
  end

  @doc """
  Gets the current configuration from the terminal state.
  """
  def get_config(%__MODULE__{} = state) do
    state.config
  end

  @doc """
  Gets the current memory usage from the terminal state.
  """
  def get_memory_usage(%__MODULE__{} = state) do
    state.buffer_manager
    |> Manager.get_memory_usage()
  end
end
