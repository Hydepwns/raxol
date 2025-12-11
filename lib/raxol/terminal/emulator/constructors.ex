defmodule Raxol.Terminal.Emulator.Constructors do
  @moduledoc """
  Handles emulator constructor functions.
  This module extracts the constructor logic from the main emulator.
  """

  alias Raxol.Terminal.{ScreenBuffer, ModeManager, Cursor.Manager}
  alias Raxol.Terminal.ScreenBufferAdapter, as: ScreenBuffer

  @doc """
  Creates a new terminal emulator instance with default dimensions.
  """
  @spec new() :: map()
  def new do
    new(80, 24)
  end

  @doc """
  Creates a new terminal emulator instance with given width and height.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: map()
  def new(width, height) do
    # Initialize all required managers and processes
    state_pid =
      get_pid(Raxol.Terminal.State.TerminalStateManager.start_link([]))

    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link([]))

    buffer_pid =
      get_pid(
        Raxol.Terminal.ScreenBuffer.Manager.start_link(
          width: width,
          height: height
        )
      )

    config_pid =
      get_pid(
        Raxol.Terminal.Config.Manager.start_link(width: width, height: height)
      )

    command_pid = get_pid(Raxol.Terminal.Command.Manager.start_link([]))
    cursor_manager_pid = get_pid(Manager.start_link([]))
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link([]))
    mode_manager = ModeManager.new()

    # Initialize screen buffers
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)

    # Create a proper CursorManager struct
    cursor = %Manager{
      row: 0,
      col: 0,
      position: {0, 0},
      visible: true,
      blinking: true,
      style: :block,
      bottom_margin: height - 1
    }

    %Raxol.Terminal.Emulator{
      # Core managers
      state: state_pid,
      event: event_pid,
      buffer: buffer_pid,
      config: config_pid,
      command: command_pid,
      cursor: cursor,
      cursor_manager: cursor_manager_pid,
      window_manager: window_manager_pid,
      mode_manager: mode_manager,

      # Screen buffers
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,

      # Character set state
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        active: :g0,
        single_shift: nil
      },

      # Dimensions
      width: width,
      height: height,

      # Window state
      window_state: %{
        iconified: false,
        maximized: false,
        position: {0, 0},
        size: {width, height},
        size_pixels: {width * 8, height * 16},
        stacking_order: :normal,
        previous_size: {width, height},
        saved_size: {width, height},
        icon_name: ""
      },

      # State stack for terminal state management
      state_stack: [],

      # Command history
      command_history: [],
      current_command_buffer: "",
      max_command_history: 100,
      history_buffer: Raxol.Terminal.HistoryBuffer.new(),

      # Other fields
      output_buffer: "",
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_limit: 1000,
      scrollback_buffer: [],
      window_title: nil,
      plugin_manager: nil,
      saved_cursor: nil,
      scroll_region: nil,
      sixel_state: nil,
      last_col_exceeded: false,
      cursor_blink_rate: 0,
      cursor_style: :block,
      session_id: nil,
      client_options: %{}
    }
  end

  @doc """
  Creates a new terminal emulator instance with given width, height, and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: map()
  def new(width, height, opts) do
    state_pid =
      get_pid(Raxol.Terminal.State.TerminalStateManager.start_link(opts))

    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link(opts))

    buffer_pid =
      get_pid(
        Raxol.Terminal.ScreenBuffer.Manager.start_link(
          [width: width, height: height] ++ opts
        )
      )

    config_pid =
      get_pid(
        Raxol.Terminal.Config.Manager.start_link(
          [width: width, height: height] ++ opts
        )
      )

    command_pid = get_pid(Raxol.Terminal.Command.Manager.start_link(opts))
    cursor_manager_pid = get_pid(Manager.start_link(opts))
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link(opts))
    mode_manager = ModeManager.new()

    # Initialize screen buffers
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)

    # Create a proper CursorManager struct
    cursor = %Manager{
      row: 0,
      col: 0,
      position: {0, 0},
      visible: true,
      blinking: true,
      style: :block,
      bottom_margin: height - 1
    }

    # Get plugin manager from options
    plugin_manager = Keyword.get(opts, :plugin_manager)

    %Raxol.Terminal.Emulator{
      # Core managers
      state: state_pid,
      event: event_pid,
      buffer: buffer_pid,
      config: config_pid,
      command: command_pid,
      cursor: cursor,
      cursor_manager: cursor_manager_pid,
      window_manager: window_manager_pid,
      mode_manager: mode_manager,

      # Screen buffers
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,

      # Character set state
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        active: :g0,
        single_shift: nil
      },

      # Dimensions
      width: width,
      height: height,

      # Window state
      window_state: %{
        iconified: false,
        maximized: false,
        position: {0, 0},
        size: {width, height},
        size_pixels: {width * 8, height * 16},
        stacking_order: :normal,
        previous_size: {width, height},
        saved_size: {width, height},
        icon_name: ""
      },

      # State stack for terminal state management
      state_stack: [],

      # Command history
      command_history: [],
      current_command_buffer: "",
      max_command_history: Keyword.get(opts, :max_command_history, 100),
      history_buffer:
        Raxol.Terminal.HistoryBuffer.new(
          Keyword.get(opts, :max_command_history, 1000)
        ),

      # Other fields
      output_buffer: "",
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000),
      scrollback_buffer: [],
      window_title: nil,
      plugin_manager: plugin_manager,
      saved_cursor: nil,
      scroll_region: nil,
      sixel_state: nil,
      last_col_exceeded: false,
      cursor_blink_rate: 0,
      cursor_style: :block,
      session_id: nil,
      client_options: %{}
    }
  end

  @doc """
  Creates a new terminal emulator instance with options map.
  """
  @spec new(%{
          required(:width) => non_neg_integer(),
          required(:height) => non_neg_integer()
        }) ::
          map()
  def new(%{width: width, height: height} = opts) do
    plugin_manager = Map.get(opts, :plugin_manager)
    emulator = new(width, height, [])

    case plugin_manager do
      nil -> emulator
      _ -> %{emulator | plugin_manager: plugin_manager}
    end
  end

  @doc """
  Creates a new emulator with width, height, and optional configuration.
  """
  @spec new(non_neg_integer(), non_neg_integer(), map(), map()) :: map()
  def new(width, height, config, options) do
    # Merge config and options
    merged_opts = Map.merge(config, options)

    # Convert to keyword list for existing new/3 function
    opts_list = Map.to_list(merged_opts)

    # Create emulator using existing constructor
    emulator = new(width, height, opts_list)

    # Apply any additional configuration
    emulator = apply_additional_config(emulator, merged_opts)

    emulator
  end

  # Private functions

  @spec get_pid({:ok, pid()} | {:error, {:already_started, pid()} | term()}) ::
          pid() | no_return()
  defp get_pid({:ok, pid}), do: pid
  defp get_pid({:error, {:already_started, pid}}), do: pid

  defp get_pid({:error, reason}),
    do: raise("Failed to start process: #{inspect(reason)}")

  defp apply_additional_config(emulator, config) do
    emulator
    |> maybe_set_plugin_manager(config)
    |> maybe_set_session_id(config)
    |> maybe_set_client_options(config)
  end

  defp maybe_set_plugin_manager(emulator, %{plugin_manager: plugin_manager}) do
    %{emulator | plugin_manager: plugin_manager}
  end

  defp maybe_set_plugin_manager(emulator, _), do: emulator

  defp maybe_set_session_id(emulator, %{session_id: session_id}) do
    %{emulator | session_id: session_id}
  end

  defp maybe_set_session_id(emulator, _), do: emulator

  defp maybe_set_client_options(emulator, %{client_options: client_options}) do
    %{emulator | client_options: client_options}
  end

  defp maybe_set_client_options(emulator, _), do: emulator
end
