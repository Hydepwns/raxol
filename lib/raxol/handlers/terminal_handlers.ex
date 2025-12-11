defmodule Raxol.Handlers.CreateTerminalHandler do
  @moduledoc """
  Handler for creating new terminal instances.
  """

  use Raxol.Architecture.CQRS.CommandHandler

  alias Raxol.Commands.CreateTerminalCommand
  alias Raxol.Events.TerminalCreatedEvent
  alias Raxol.Terminal.TerminalRegistry

  @impl true
  def handle(%CreateTerminalCommand{} = command, context) do
    execute_with_handling(command, context, &do_handle/2)
  end

  defp do_handle(command, context) do
    with :ok <- validate_preconditions(command),
         {:ok, terminal_process} <- create_terminal_process(command),
         {:ok, event} <- create_terminal_created_event(command),
         :ok <- publish_event(event, context),
         :ok <- register_terminal(command.terminal_id, terminal_process) do
      {:ok,
       success_response(%{terminal_id: command.terminal_id, status: :created})}
    else
      {:error, :terminal_already_exists} ->
        {:error,
         error_response(
           :terminal_already_exists,
           "Terminal with this ID already exists"
         )}

      {:error, :user_not_authenticated} ->
        {:error,
         error_response(
           :authentication_required,
           "User authentication required"
         )}

      {:error, reason} ->
        {:error, error_response(:terminal_creation_failed, reason)}
    end
  end

  defp validate_preconditions(command) do
    preconditions = [
      {:terminal_unique,
       fn cmd -> not TerminalRegistry.exists?(cmd.terminal_id) end},
      {:valid_dimensions,
       fn cmd ->
         cmd.width >= 20 and cmd.width <= 300 and cmd.height >= 5 and
           cmd.height <= 100
       end},
      {:user_authenticated, fn cmd -> not is_nil(cmd.user_id) end}
    ]

    validate_preconditions(command, preconditions)
  end

  defp create_terminal_process(command) do
    terminal_config = %{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      width: command.width,
      height: command.height,
      title: command.title,
      shell_command: command.shell_command || default_shell(),
      working_directory: command.working_directory,
      environment_variables: command.environment_variables || %{},
      theme: command.theme,
      font_settings: command.font_settings,
      accessibility_options: command.accessibility_options
    }

    case Raxol.Terminal.Supervisor.start_terminal(terminal_config) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, {:terminal_start_failed, reason}}
    end
  end

  defp create_terminal_created_event(command) do
    event = %TerminalCreatedEvent{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      width: command.width,
      height: command.height,
      title: command.title,
      shell_command: command.shell_command,
      working_directory: command.working_directory,
      environment_variables: command.environment_variables || %{},
      theme: command.theme,
      font_settings: command.font_settings,
      accessibility_options: command.accessibility_options,
      created_at: System.system_time(:millisecond),
      metadata: command.metadata || %{}
    }

    case TerminalCreatedEvent.validate(event) do
      {:ok, validated_event} -> {:ok, validated_event}
      {:error, reason} -> {:error, {:event_validation_failed, reason}}
    end
  end

  defp register_terminal(terminal_id, process) do
    TerminalRegistry.register(terminal_id, process)
  end

  defp default_shell do
    System.get_env("SHELL") || "/bin/bash"
  end
end

defmodule Raxol.Handlers.UpdateTerminalHandler do
  @moduledoc """
  Handler for updating terminal configurations.
  """

  use Raxol.Architecture.CQRS.CommandHandler

  alias Raxol.Commands.UpdateTerminalCommand
  alias Raxol.Events.TerminalConfiguredEvent
  alias Raxol.Terminal.TerminalRegistry

  @impl true
  def handle(%UpdateTerminalCommand{} = command, context) do
    execute_with_handling(command, context, &do_handle/2)
  end

  defp do_handle(command, context) do
    with {:ok, terminal_process} <- get_terminal_process(command.terminal_id),
         {:ok, current_config} <- get_terminal_config(terminal_process),
         :ok <- validate_version(current_config, command.expected_version),
         {:ok, changes} <- calculate_changes(current_config, command),
         {:ok, _updated_config} <-
           apply_configuration_changes(terminal_process, changes),
         {:ok, event} <-
           create_terminal_configured_event(command, changes, current_config),
         :ok <- publish_event(event, context) do
      {:ok,
       success_response(%{
         terminal_id: command.terminal_id,
         changes_applied: length(changes),
         new_version: current_config.version + 1
       })}
    else
      {:error, :terminal_not_found} ->
        {:error, error_response(:terminal_not_found, "Terminal does not exist")}

      {:error, :version_mismatch} ->
        {:error,
         error_response(:version_mismatch, "Terminal version has changed")}

      {:error, reason} ->
        {:error, error_response(:configuration_failed, reason)}
    end
  end

  defp get_terminal_process(terminal_id) do
    case TerminalRegistry.lookup(terminal_id) do
      {:ok, process} -> {:ok, process}
      {:error, :not_found} -> {:error, :terminal_not_found}
    end
  end

  defp get_terminal_config(terminal_process) do
    case GenServer.call(terminal_process, :get_config) do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_version(current_config, expected_version) do
    case current_config.version == expected_version do
      true -> :ok
      false -> {:error, :version_mismatch}
    end
  end

  defp calculate_changes(current_config, command) do
    changes = []

    changes =
      add_change_if_different(
        changes,
        :width,
        current_config.width,
        command.width
      )

    changes =
      add_change_if_different(
        changes,
        :height,
        current_config.height,
        command.height
      )

    changes =
      add_change_if_different(
        changes,
        :title,
        current_config.title,
        command.title
      )

    changes =
      add_change_if_different(
        changes,
        :theme,
        current_config.theme,
        command.theme
      )

    changes =
      add_change_if_different(
        changes,
        :font_settings,
        current_config.font_settings,
        command.font_settings
      )

    changes =
      add_change_if_different(
        changes,
        :accessibility_options,
        current_config.accessibility_options,
        command.accessibility_options
      )

    {:ok, changes}
  end

  defp add_change_if_different(changes, field, old_value, new_value)
       when new_value != nil and old_value != new_value do
    [%{field: field, old_value: old_value, new_value: new_value} | changes]
  end

  defp add_change_if_different(changes, _field, _old_value, _new_value),
    do: changes

  defp apply_configuration_changes(terminal_process, changes) do
    case GenServer.call(terminal_process, {:apply_config_changes, changes}) do
      {:ok, updated_config} -> {:ok, updated_config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_terminal_configured_event(command, changes, current_config) do
    previous_values =
      changes
      |> Enum.map(fn change -> {change.field, change.old_value} end)
      |> Map.new()

    event = %TerminalConfiguredEvent{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      changes: changes,
      previous_values: previous_values,
      version: current_config.version + 1,
      configured_at: System.system_time(:millisecond),
      metadata: command.metadata || %{}
    }

    case TerminalConfiguredEvent.validate(event) do
      {:ok, validated_event} -> {:ok, validated_event}
      {:error, reason} -> {:error, {:event_validation_failed, reason}}
    end
  end
end

defmodule Raxol.Handlers.SendInputHandler do
  @moduledoc """
  Handler for sending input to terminal instances.
  """

  use Raxol.Architecture.CQRS.CommandHandler

  alias Raxol.Commands.SendInputCommand
  alias Raxol.Events.TerminalInputReceivedEvent
  alias Raxol.Terminal.TerminalRegistry

  @impl true
  def handle(%SendInputCommand{} = command, context) do
    execute_with_handling(command, context, &do_handle/2)
  end

  defp do_handle(command, context) do
    with {:ok, terminal_process} <- get_terminal_process(command.terminal_id),
         {:ok, sequence_number} <- get_next_sequence_number(terminal_process),
         :ok <- send_input_to_terminal(terminal_process, command),
         {:ok, event} <- create_input_received_event(command, sequence_number),
         :ok <- publish_event(event, context) do
      {:ok,
       success_response(%{
         terminal_id: command.terminal_id,
         sequence_number: sequence_number,
         input_processed: true
       })}
    else
      {:error, :terminal_not_found} ->
        {:error, error_response(:terminal_not_found, "Terminal does not exist")}

      {:error, :terminal_not_ready} ->
        {:error,
         error_response(:terminal_not_ready, "Terminal is not ready for input")}

      {:error, reason} ->
        {:error, error_response(:input_processing_failed, reason)}
    end
  end

  defp get_terminal_process(terminal_id) do
    case TerminalRegistry.lookup(terminal_id) do
      {:ok, process} -> {:ok, process}
      {:error, :not_found} -> {:error, :terminal_not_found}
    end
  end

  defp get_next_sequence_number(terminal_process) do
    case GenServer.call(terminal_process, :get_next_input_sequence) do
      {:ok, sequence} -> {:ok, sequence}
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_input_to_terminal(terminal_process, command) do
    input_message = %{
      data: command.input_data,
      type: command.input_type,
      sequence_number: command.sequence_number
    }

    case GenServer.call(terminal_process, {:send_input, input_message}) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_input_received_event(command, sequence_number) do
    event = %TerminalInputReceivedEvent{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      input_data: command.input_data,
      input_type: command.input_type,
      sequence_number: sequence_number,
      processed_at: System.system_time(:millisecond),
      metadata: command.metadata || %{}
    }

    case TerminalInputReceivedEvent.validate(event) do
      {:ok, validated_event} -> {:ok, validated_event}
      {:error, reason} -> {:error, {:event_validation_failed, reason}}
    end
  end
end

defmodule Raxol.Handlers.CloseTerminalHandler do
  @moduledoc """
  Handler for closing terminal instances.
  """

  use Raxol.Architecture.CQRS.CommandHandler

  alias Raxol.Commands.CloseTerminalCommand
  alias Raxol.Events.TerminalClosedEvent
  alias Raxol.Terminal.TerminalRegistry

  @impl true
  def handle(%CloseTerminalCommand{} = command, context) do
    execute_with_handling(command, context, &do_handle/2)
  end

  defp do_handle(command, context) do
    with {:ok, terminal_process} <- get_terminal_process(command.terminal_id),
         {:ok, terminal_state} <- get_terminal_state(terminal_process),
         :ok <- validate_version(terminal_state, command.expected_version),
         {:ok, final_state} <- capture_final_state(terminal_process),
         {:ok, session_saved} <-
           save_session_if_requested(terminal_process, command.save_session),
         :ok <- terminate_terminal_process(terminal_process),
         :ok <- unregister_terminal(command.terminal_id),
         {:ok, event} <-
           create_terminal_closed_event(command, final_state, session_saved),
         :ok <- publish_event(event, context) do
      {:ok,
       success_response(%{
         terminal_id: command.terminal_id,
         session_saved: session_saved,
         status: :closed
       })}
    else
      {:error, :terminal_not_found} ->
        {:error, error_response(:terminal_not_found, "Terminal does not exist")}

      {:error, :version_mismatch} ->
        {:error,
         error_response(:version_mismatch, "Terminal version has changed")}

      {:error, reason} ->
        {:error, error_response(:terminal_close_failed, reason)}
    end
  end

  defp get_terminal_process(terminal_id) do
    case TerminalRegistry.lookup(terminal_id) do
      {:ok, process} -> {:ok, process}
      {:error, :not_found} -> {:error, :terminal_not_found}
    end
  end

  defp get_terminal_state(terminal_process) do
    case GenServer.call(terminal_process, :get_state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_version(terminal_state, expected_version) do
    case terminal_state.version == expected_version do
      true -> :ok
      false -> {:error, :version_mismatch}
    end
  end

  defp capture_final_state(terminal_process) do
    case GenServer.call(terminal_process, :capture_final_state) do
      {:ok, final_state} -> {:ok, final_state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_session_if_requested(_terminal_process, false), do: {:ok, false}

  defp save_session_if_requested(terminal_process, true) do
    case GenServer.call(terminal_process, :save_session) do
      :ok -> {:ok, true}
      # Don't fail close if session save fails
      {:error, _reason} -> {:ok, false}
    end
  end

  defp terminate_terminal_process(terminal_process) do
    GenServer.stop(terminal_process, :normal, 5000)
  end

  defp unregister_terminal(terminal_id) do
    TerminalRegistry.unregister(terminal_id)
  end

  defp create_terminal_closed_event(command, final_state, session_saved) do
    uptime_seconds = calculate_uptime(final_state.created_at)

    event = %TerminalClosedEvent{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      close_reason: command.reason,
      session_saved: session_saved,
      final_state: final_state,
      uptime_seconds: uptime_seconds,
      commands_executed: final_state.commands_executed || 0,
      closed_at: System.system_time(:millisecond),
      metadata: command.metadata || %{}
    }

    case TerminalClosedEvent.validate(event) do
      {:ok, validated_event} -> {:ok, validated_event}
      {:error, reason} -> {:error, {:event_validation_failed, reason}}
    end
  end

  defp calculate_uptime(created_at) do
    div(System.system_time(:millisecond) - created_at, 1000)
  end
end

defmodule Raxol.Handlers.ApplyThemeHandler do
  @moduledoc """
  Handler for applying themes to terminal instances.
  """

  use Raxol.Architecture.CQRS.CommandHandler

  alias Raxol.Commands.ApplyThemeCommand
  alias Raxol.Events.TerminalThemeAppliedEvent
  alias Raxol.Terminal.TerminalRegistry

  @impl true
  def handle(%ApplyThemeCommand{} = command, context) do
    execute_with_handling(command, context, &do_handle/2)
  end

  defp do_handle(command, context) do
    with {:ok, terminal_process} <- get_terminal_process(command.terminal_id),
         {:ok, terminal_state} <- get_terminal_state(terminal_process),
         :ok <- validate_version(terminal_state, command.expected_version),
         {:ok, theme} <- load_theme(command.theme_id),
         {:ok, resolved_theme} <- resolve_theme_settings(theme, command),
         {:ok, previous_theme_id} <- get_current_theme_id(terminal_process),
         :ok <- apply_theme_to_terminal(terminal_process, resolved_theme),
         {:ok, event} <-
           create_theme_applied_event(
             command,
             resolved_theme,
             previous_theme_id
           ),
         :ok <- publish_event(event, context) do
      {:ok,
       success_response(%{
         terminal_id: command.terminal_id,
         theme_applied: command.theme_id,
         previous_theme: previous_theme_id
       })}
    else
      {:error, :terminal_not_found} ->
        {:error, error_response(:terminal_not_found, "Terminal does not exist")}

      {:error, :theme_not_found} ->
        {:error, error_response(:theme_not_found, "Theme does not exist")}

      {:error, :version_mismatch} ->
        {:error,
         error_response(:version_mismatch, "Terminal version has changed")}

      {:error, reason} ->
        {:error, error_response(:theme_application_failed, reason)}
    end
  end

  defp get_terminal_process(terminal_id) do
    case TerminalRegistry.lookup(terminal_id) do
      {:ok, process} -> {:ok, process}
      {:error, :not_found} -> {:error, :terminal_not_found}
    end
  end

  defp get_terminal_state(terminal_process) do
    case GenServer.call(terminal_process, :get_state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_version(terminal_state, expected_version) do
    case terminal_state.version == expected_version do
      true -> :ok
      false -> {:error, :version_mismatch}
    end
  end

  defp load_theme(theme_id) do
    case Raxol.Themes.load_theme(theme_id) do
      {:ok, basic_theme} ->
        # Convert basic theme structure to full theme structure
        full_theme = %{
          id: theme_id,
          name: theme_id |> to_string() |> String.capitalize(),
          color_scheme: basic_theme,
          font_settings: %{},
          accessibility_options: %{}
        }

        {:ok, full_theme}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_theme_settings(theme, command) do
    resolved_theme = %{
      id: theme.id,
      name: theme.name,
      color_scheme:
        merge_color_scheme(theme.color_scheme, command.theme_settings),
      font_settings: command.font_settings || theme.font_settings,
      accessibility_options:
        merge_accessibility_options(
          theme.accessibility_options,
          command.accessibility_options,
          command.high_contrast_mode
        )
    }

    {:ok, resolved_theme}
  end

  defp merge_color_scheme(base_scheme, nil), do: base_scheme

  defp merge_color_scheme(base_scheme, overrides) do
    Map.merge(base_scheme, overrides)
  end

  defp merge_accessibility_options(base_options, nil, false), do: base_options

  defp merge_accessibility_options(base_options, overrides, high_contrast) do
    merged = Map.merge(base_options, overrides || %{})

    case high_contrast do
      true -> Map.put(merged, :high_contrast_mode, true)
      false -> merged
    end
  end

  defp get_current_theme_id(terminal_process) do
    case GenServer.call(terminal_process, :get_current_theme) do
      {:ok, theme_id} -> {:ok, theme_id}
      {:error, :no_theme} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_theme_to_terminal(terminal_process, theme) do
    case GenServer.call(terminal_process, {:apply_theme, theme}) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_theme_applied_event(command, theme, previous_theme_id) do
    event = %TerminalThemeAppliedEvent{
      terminal_id: command.terminal_id,
      user_id: command.user_id,
      theme_id: theme.id,
      theme_name: theme.name,
      color_scheme: theme.color_scheme,
      font_settings: theme.font_settings,
      accessibility_options: theme.accessibility_options,
      previous_theme_id: previous_theme_id,
      applied_at: System.system_time(:millisecond),
      metadata: command.metadata || %{}
    }

    case TerminalThemeAppliedEvent.validate(event) do
      {:ok, validated_event} -> {:ok, validated_event}
      {:error, reason} -> {:error, {:event_validation_failed, reason}}
    end
  end
end
