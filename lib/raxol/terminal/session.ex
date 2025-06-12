defmodule Raxol.Terminal.Session do
  @moduledoc """
  Terminal session module.

  This module manages terminal sessions, including:
  - Session lifecycle
  - Input/output handling
  - State management
  - Configuration
  - Session persistence and recovery
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  # alias Raxol.Core.Events.Event # Unused
  # alias Raxol.Core.Runtime.EventLoop # Unused
  # alias Raxol.Core.I18n # Unused
  # alias Raxol.Terminal.{Cell, ScreenBuffer, Input, Emulator, Renderer} # Simplify aliases
  alias Raxol.Terminal.{Emulator, Renderer, ScreenBuffer}
  alias Raxol.Terminal.Session.{Serializer, Storage}
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Input

  @type t :: %__MODULE__{
          id: String.t(),
          emulator: EmulatorStruct.t(),
          renderer: Raxol.Terminal.Renderer.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          title: String.t(),
          theme: map(),
          auto_save: boolean()
        }

  defstruct [
    :id,
    :emulator,
    :renderer,
    :width,
    :height,
    :title,
    :theme,
    auto_save: true
  ]

  @doc """
  Starts a new terminal session.

  ## Examples

      iex> {:ok, pid} = Session.start_link(%{width: 80, height: 24})
      iex> Process.alive?(pid)
      true
  """
  @spec start_link(keyword()) :: GenServer.on_start()
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
  @spec stop(GenServer.server()) :: :ok
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
  @spec send_input(GenServer.server(), String.t()) :: :ok
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
  @spec get_state(GenServer.server()) :: t()
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
  @spec update_config(GenServer.server(), map()) :: :ok
  def update_config(pid, config) do
    GenServer.call(pid, {:update_config, config})
  end

  @doc """
  Saves the current session state to persistent storage.
  """
  @spec save_session(GenServer.server()) :: :ok | {:error, term()}
  def save_session(pid) do
    GenServer.call(pid, :save_session)
  end

  @doc """
  Loads a session from persistent storage.
  """
  @spec load_session(String.t()) :: {:ok, pid()} | {:error, term()}
  def load_session(session_id) do
    case Storage.load_session(session_id) do
      {:ok, session_state} ->
        start_link(
          id: session_state.id,
          width: session_state.width,
          height: session_state.height,
          title: session_state.title,
          theme: session_state.theme
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all saved sessions.
  """
  @spec list_saved_sessions() :: {:ok, [String.t()]} | {:error, term()}
  def list_saved_sessions do
    Storage.list_sessions()
  end

  @doc """
  Sets whether the session should be automatically saved.
  """
  @spec set_auto_save(GenServer.server(), boolean()) :: :ok
  def set_auto_save(pid, enabled) do
    GenServer.call(pid, {:set_auto_save, enabled})
  end

  @spec count_active_sessions() :: non_neg_integer()
  def count_active_sessions do
    # Guard against potential nil return or other issues
    case Raxol.Terminal.Registry.count() do
      count when is_integer(count) and count >= 0 -> count
      _ -> 0
    end
  end

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  # Callbacks

  @impl true
  def init({id, width, height, title, theme}) do
    # Create emulator with explicit dimensions
    scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    emulator = EmulatorStruct.new(width, height, scrollback: scrollback_limit)

    # Create a default screen buffer without relying on get_active_buffer
    # Default to main buffer - no need to pattern match since we know new emulators default to :main
    screen_buffer =
      try do
        # Access main buffer directly since we know new emulators default to main buffer
        emulator.main_screen_buffer
      rescue
        _ -> ScreenBuffer.new(width, height)
      end

    # Create renderer with screen buffer
    renderer = Renderer.new(screen_buffer, theme)

    # Build state struct
    state = %__MODULE__{
      id: id,
      emulator: emulator,
      renderer: renderer,
      width: width,
      height: height,
      title: title,
      theme: theme
    }

    # Register with error handling
    try do
      Raxol.Terminal.Registry.register(id, state)
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Failed to register session: #{inspect(e)}"
        )
    end

    {:ok, state}
  end

  @impl true
  def handle_cast({:input, input}, state) do
    # Handle process_input with more robust pattern matching
    new_state =
      try do
        case EmulatorStruct.process_input(state.emulator, input) do
          {new_emulator, _output}
          when is_struct(new_emulator, EmulatorStruct) ->
            # Access the screen buffer directly without pattern matching that can't succeed
            screen_buffer =
              try do
                # Use a fallback approach instead of pattern matching
                buffer =
                  cond do
                    # Check for main buffer active
                    new_emulator.active_buffer_type == :main &&
                        is_struct(new_emulator.main_screen_buffer, ScreenBuffer) ->
                      new_emulator.main_screen_buffer

                    # Check for alternate buffer active
                    new_emulator.active_buffer_type == :alternate &&
                        is_struct(
                          new_emulator.alternate_screen_buffer,
                          ScreenBuffer
                        ) ->
                      new_emulator.alternate_screen_buffer

                    # Default fallback
                    true ->
                      state.renderer.screen_buffer
                  end

                # Extra safety check
                if is_struct(buffer, ScreenBuffer) do
                  buffer
                else
                  state.renderer.screen_buffer
                end
              rescue
                _ -> state.renderer.screen_buffer
              end

            # Update renderer with new screen buffer
            new_renderer = %{state.renderer | screen_buffer: screen_buffer}
            %{state | emulator: new_emulator, renderer: new_renderer}

          # Broader pattern matching for error cases
          error_result ->
            Raxol.Core.Runtime.Log.error(
              "Unexpected result from Emulator.process_input: #{inspect(error_result)}"
            )

            state
        end
      rescue
        e ->
          Raxol.Core.Runtime.Log.error("Error in process_input: #{inspect(e)}")
          state
      end

    # Auto-save if enabled
    if state.auto_save do
      Task.start(fn -> Storage.save_session(new_state) end)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    new_state = update_state_from_config(state, config)
    # Handle potential errors from the Registry
    try do
      Raxol.Terminal.Registry.register(state.id, new_state)
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Failed to register updated session state: #{inspect(e)}"
        )
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:save_session, _from, state) do
    case Storage.save_session(state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:set_auto_save, enabled}, _from, state) do
    new_state = %{state | auto_save: enabled}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:auto_save, state) do
    if state.auto_save do
      Task.start(fn -> Storage.save_session(state) end)
    end

    # Schedule next auto-save
    Process.send_after(self(), :auto_save, :timer.minutes(5))
    {:noreply, state}
  end

  # Private functions

  defp update_state_from_config(state, config) do
    width =
      if is_map(config),
        do: Map.get(config, :width, state.width),
        else: if(is_tuple(config), do: elem(config, 0), else: state.width)

    height =
      if is_map(config),
        do: Map.get(config, :height, state.height),
        else: if(is_tuple(config), do: elem(config, 1), else: state.height)

    title = Map.get(config, :title, state.title)
    theme = Map.get(config, :theme, state.theme)

    # Create emulator with explicit dimensions
    scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    emulator = EmulatorStruct.new(width, height, scrollback: scrollback_limit)

    # Access the screen buffer directly without pattern matching that can't succeed
    # Default to main buffer - no need to pattern match since we know new emulators default to :main
    screen_buffer =
      try do
        # Access main buffer directly since we know new emulators default to main buffer
        emulator.main_screen_buffer
      rescue
        _ -> ScreenBuffer.new(width, height)
      end

    # Create renderer with screen buffer
    renderer = Renderer.new(screen_buffer, theme)

    %{
      state
      | emulator: emulator,
        renderer: renderer,
        width: width,
        height: height,
        title: title,
        theme: theme
    }
  end
end
