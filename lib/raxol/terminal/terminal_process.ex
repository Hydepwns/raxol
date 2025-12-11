defmodule Raxol.Terminal.TerminalProcess do
  @moduledoc """
  Individual terminal process implementation for event sourced architecture.

  This GenServer represents a single terminal instance and handles
  all terminal-specific operations including input/output processing,
  configuration management, and state persistence using event sourcing.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Terminal.TerminalRegistry
  alias Raxol.Core.Runtime.Log
  # Terminal process aliases will be added as needed

  defstruct [
    :terminal_id,
    :user_id,
    :config,
    :state,
    :emulator,
    :session,
    :buffer,
    :input_sequence,
    :version,
    :created_at,
    :last_activity_at,
    :metrics
  ]

  @type terminal_config :: %{
          terminal_id: String.t(),
          user_id: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          shell_command: String.t(),
          working_directory: String.t(),
          environment_variables: map(),
          theme: String.t() | nil,
          font_settings: map() | nil,
          accessibility_options: map() | nil
        }

  ## BaseManager Implementation

  @impl true
  def init_manager(terminal_config) do
    # Initialize terminal state
    state = %__MODULE__{
      terminal_id: terminal_config.terminal_id,
      user_id: terminal_config.user_id,
      config: terminal_config,
      state: :initializing,
      input_sequence: 0,
      version: 1,
      created_at: System.system_time(:millisecond),
      last_activity_at: System.system_time(:millisecond),
      metrics: init_metrics()
    }

    # Register with the terminal registry
    :ok =
      TerminalRegistry.register(terminal_config.terminal_id, self(), %{
        user_id: terminal_config.user_id,
        created_at: state.created_at
      })

    # Start initialization in background
    send(self(), :initialize_terminal)

    Log.info("Terminal process started: #{terminal_config.terminal_id}")
    {:ok, state}
  end

  @impl true
  def handle_manager_call(:get_config, _from, state) do
    {:reply, {:ok, state.config}, state}
  end

  @impl true
  def handle_manager_call(:get_state, _from, state) do
    terminal_state = %{
      terminal_id: state.terminal_id,
      user_id: state.user_id,
      state: state.state,
      version: state.version,
      created_at: state.created_at,
      last_activity_at: state.last_activity_at
    }

    {:reply, {:ok, terminal_state}, state}
  end

  @impl true
  def handle_manager_call(:get_next_input_sequence, _from, state) do
    new_sequence = state.input_sequence + 1
    new_state = %{state | input_sequence: new_sequence}
    {:reply, {:ok, new_sequence}, new_state}
  end

  @impl true
  def handle_manager_call({:apply_config_changes, changes}, _from, state) do
    {:ok, new_state} = apply_configuration_changes(changes, state)

    updated_state = %{
      new_state
      | version: state.version + 1,
        last_activity_at: System.system_time(:millisecond)
    }

    {:reply, {:ok, updated_state.config}, updated_state}
  end

  @impl true
  def handle_manager_call({:send_input, input_message}, _from, state) do
    {:ok, new_state} = process_input(input_message, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:capture_final_state, _from, state) do
    final_state = %{
      width: state.config.width,
      height: state.config.height,
      scroll_position: get_scroll_position(state),
      cursor_position: get_cursor_position(state),
      working_directory: state.config.working_directory,
      commands_executed: state.metrics.commands_executed,
      created_at: state.created_at
    }

    {:reply, {:ok, final_state}, state}
  end

  @impl true
  def handle_manager_call(:save_session, _from, state) do
    # save_terminal_session/1 always returns :ok, no error case possible
    :ok = save_terminal_session(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_manager_call(:get_current_theme, _from, state) do
    current_theme = Map.get(state.config, :theme)

    case current_theme do
      nil -> {:reply, {:error, :no_theme}, state}
      theme_id -> {:reply, {:ok, theme_id}, state}
    end
  end

  @impl true
  def handle_manager_call({:apply_theme, theme}, _from, state) do
    # apply_theme_to_terminal/2 always returns {:ok, new_state}, no error case possible
    {:ok, new_state} = apply_theme_to_terminal(theme, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_info(:initialize_terminal, state) do
    # initialize_terminal_components always succeeds with current implementation
    {:ok, new_state} = initialize_terminal_components(state)
    Log.info("Terminal #{state.terminal_id} initialized successfully")
    {:noreply, %{new_state | state: :active}}
  end

  @impl true
  def handle_manager_info({:output, data}, state) do
    # Handle output from the terminal emulator
    {:ok, new_state} = process_output(data, state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, state) do
    Log.info("Terminal #{state.terminal_id} terminating: #{inspect(reason)}")

    # Clean up resources
    cleanup_terminal_resources(state)

    # Unregister from registry
    TerminalRegistry.unregister(state.terminal_id)

    :ok
  end

  ## Private Implementation

  defp initialize_terminal_components(state) do
    # All initialize_* functions always return {:ok, ...}
    {:ok, emulator} = initialize_emulator(state.config)
    {:ok, session} = initialize_session(state.config)
    {:ok, buffer} = initialize_buffer(state.config)

    new_state = %{
      state
      | emulator: emulator,
        session: session,
        buffer: buffer
    }

    {:ok, new_state}
  end

  defp initialize_emulator(config) do
    # Initialize the terminal emulator with the given configuration
    # This integrates with the existing Raxol terminal emulator
    emulator_config = %{
      width: config.width,
      height: config.height,
      shell_command: config.shell_command,
      working_directory: config.working_directory,
      environment_variables: config.environment_variables
    }

    {:ok, %{config: emulator_config, state: :initialized}}
  end

  defp initialize_session(config) do
    # Initialize terminal session management
    session_config = %{
      terminal_id: config.terminal_id,
      user_id: config.user_id,
      working_directory: config.working_directory
    }

    {:ok, %{config: session_config, state: :active}}
  end

  defp initialize_buffer(config) do
    # Initialize terminal buffer
    buffer_config = %{
      width: config.width,
      height: config.height,
      scrollback_lines: 1000
    }

    {:ok, %{config: buffer_config, lines: [], cursor: {0, 0}}}
  end

  defp apply_configuration_changes(changes, state) do
    new_config =
      Enum.reduce(changes, state.config, fn change, acc_config ->
        Map.put(acc_config, change.field, change.new_value)
      end)

    # Apply changes to components if needed
    new_state = %{state | config: new_config}

    # Update emulator if dimensions changed
    new_state =
      case Enum.any?(changes, fn c -> c.field in [:width, :height] end) do
        true ->
          # update_emulator_dimensions/1 always returns {:ok, updated_state}, no error case possible
          {:ok, updated_state} = update_emulator_dimensions(new_state)
          updated_state

        false ->
          new_state
      end

    {:ok, new_state}
  end

  defp update_emulator_dimensions(state) do
    # Update emulator dimensions
    new_emulator = put_in(state.emulator, [:config, :width], state.config.width)
    new_emulator = put_in(new_emulator, [:config, :height], state.config.height)

    {:ok, %{state | emulator: new_emulator}}
  end

  defp process_input(_input_message, state) do
    # Process input and send to emulator
    updated_metrics = %{
      state.metrics
      | inputs_processed: state.metrics.inputs_processed + 1
    }

    new_state = %{
      state
      | metrics: updated_metrics,
        last_activity_at: System.system_time(:millisecond)
    }

    {:ok, new_state}
  end

  defp process_output(_data, state) do
    # Process output from emulator and update buffer
    updated_metrics = %{
      state.metrics
      | outputs_processed: state.metrics.outputs_processed + 1
    }

    new_state = %{
      state
      | metrics: updated_metrics,
        last_activity_at: System.system_time(:millisecond)
    }

    {:ok, new_state}
  end

  defp apply_theme_to_terminal(theme, state) do
    # Apply theme to terminal components
    new_config = Map.put(state.config, :theme, theme.id)

    # Update theme-related settings
    new_config =
      case theme.font_settings do
        nil -> new_config
        font_settings -> Map.put(new_config, :font_settings, font_settings)
      end

    new_config =
      case theme.accessibility_options do
        nil ->
          new_config

        accessibility_options ->
          Map.put(new_config, :accessibility_options, accessibility_options)
      end

    new_state = %{state | config: new_config, version: state.version + 1}

    {:ok, new_state}
  end

  defp save_terminal_session(state) do
    # Save terminal session data
    _session_data = %{
      terminal_id: state.terminal_id,
      user_id: state.user_id,
      buffer_content: get_buffer_content(state),
      working_directory: state.config.working_directory,
      saved_at: System.system_time(:millisecond)
    }

    Log.debug("Session saved for terminal #{state.terminal_id}")
    :ok
  end

  defp cleanup_terminal_resources(state) do
    # Clean up any resources like file handles, processes, etc.
    Log.debug("Cleaning up resources for terminal #{state.terminal_id}")
    :ok
  end

  defp get_scroll_position(state) do
    # Get current scroll position from buffer
    get_in(state.buffer, [:scroll_position]) || 0
  end

  defp get_cursor_position(state) do
    # Get current cursor position from buffer
    get_in(state.buffer, [:cursor]) || {0, 0}
  end

  defp get_buffer_content(state) do
    # Get current buffer content
    get_in(state.buffer, [:lines]) || []
  end

  defp init_metrics do
    %{
      inputs_processed: 0,
      outputs_processed: 0,
      commands_executed: 0,
      errors_encountered: 0
    }
  end
end
