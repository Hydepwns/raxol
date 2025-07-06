defmodule Raxol.Terminal.Emulator.Constructors do
  @moduledoc """
  Handles emulator constructor functions.
  This module extracts the constructor logic from the main emulator.
  """

  alias Raxol.Terminal.{ScreenBuffer, ModeManager, Cursor.Manager}

  @doc """
  Creates a new terminal emulator instance with default dimensions.
  """
  @spec new() :: Raxol.Terminal.Emulator.t()
  def new() do
    new(80, 24)
  end

  @doc """
  Creates a new terminal emulator instance with given width and height.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: Raxol.Terminal.Emulator.t()
  def new(width, height) do
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)
    mode_manager = ModeManager.new()

    cursor_result = Manager.start_link([])
    cursor_pid = get_pid(cursor_result)

    %Raxol.Terminal.Emulator{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      mode_manager: mode_manager,
      cursor: cursor_pid,
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_buffer: [],
      cursor_style: :block,
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        single_shift: nil
      }
    }
  end

  @doc """
  Creates a new terminal emulator instance with given width, height, and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: Raxol.Terminal.Emulator.t()
  def new(width, height, opts) do
    state_pid = get_pid(Raxol.Terminal.State.Manager.start_link(opts))
    event_pid = get_pid(Raxol.Terminal.Event.Handler.start_link(opts))

    buffer_pid =
      get_pid(
        Raxol.Terminal.Buffer.Manager.start_link(
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
    cursor_pid = get_pid(Manager.start_link(opts))
    window_manager_pid = get_pid(Raxol.Terminal.Window.Manager.start_link(opts))
    mode_manager = ModeManager.new()

    # Initialize screen buffers
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)

    %Raxol.Terminal.Emulator{
      state: state_pid,
      event: event_pid,
      buffer: buffer_pid,
      config: config_pid,
      command: command_pid,
      cursor: cursor_pid,
      window_manager: window_manager_pid,
      mode_manager: mode_manager,
      active_buffer_type: :main,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      width: width,
      height: height,
      output_buffer: "",
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000),
      scrollback_buffer: [],
      cursor_style: :block
    }
  end

  @doc """
  Creates a new terminal emulator instance with options map.
  """
  @spec new(map()) :: Raxol.Terminal.Emulator.t()
  def new(%{width: width, height: height} = opts) do
    plugin_manager = Map.get(opts, :plugin_manager)
    emulator = new(width, height, [])

    if plugin_manager do
      %{emulator | plugin_manager: plugin_manager}
    else
      emulator
    end
  end

  @doc """
  Creates a new emulator with width, height, and optional configuration.
  """
  @spec new(non_neg_integer(), non_neg_integer(), map(), map()) :: Raxol.Terminal.Emulator.t()
  def new(width, height, config \\ %{}, options \\ %{}) do
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
