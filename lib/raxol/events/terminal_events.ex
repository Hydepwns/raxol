defmodule Raxol.Events.TerminalCreatedEvent do
  @moduledoc """
  Event emitted when a new terminal is created.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :width,
    :height,
    :title,
    :shell_command,
    :working_directory,
    :environment_variables,
    :theme,
    :font_settings,
    :accessibility_options,
    :created_at,
    :metadata
  ]

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          shell_command: String.t() | nil,
          working_directory: String.t(),
          environment_variables: map(),
          theme: String.t() | nil,
          font_settings: map() | nil,
          accessibility_options: map() | nil,
          created_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_dimensions(event),
         :ok <- validate_user_id(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :user_id, :width, :height, :working_directory]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_dimensions(event) when event.width < 20 or event.width > 300,
    do: {:error, {:invalid_width, event.width}}

  defp validate_dimensions(event) when event.height < 5 or event.height > 100,
    do: {:error, {:invalid_height, event.height}}

  defp validate_dimensions(_event), do: :ok

  defp validate_user_id(%{user_id: user_id})
       when is_binary(user_id) and byte_size(user_id) > 0,
       do: :ok

  defp validate_user_id(_event),
    do: {:error, :invalid_user_id}
end

defmodule Raxol.Events.TerminalConfiguredEvent do
  @moduledoc """
  Event emitted when terminal configuration is updated.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :changes,
    :previous_values,
    :version,
    :configured_at,
    :metadata
  ]

  @type configuration_change :: %{
          field: atom(),
          old_value: term(),
          new_value: term()
        }

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          changes: [configuration_change()],
          previous_values: map(),
          version: pos_integer(),
          configured_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_changes(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :user_id, :changes, :version]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_changes(%{changes: changes})
       when is_list(changes) and length(changes) > 0,
       do: :ok

  defp validate_changes(_event),
    do: {:error, :no_changes_specified}
end

defmodule Raxol.Events.TerminalInputReceivedEvent do
  @moduledoc """
  Event emitted when input is received by a terminal.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :input_data,
    :input_type,
    :sequence_number,
    :processed_at,
    :metadata
  ]

  @type input_type :: :text | :keypress | :paste | :control_sequence

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          input_data: String.t(),
          input_type: input_type(),
          sequence_number: pos_integer(),
          processed_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_input_type(event),
         :ok <- validate_input_data(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [
      :terminal_id,
      :user_id,
      :input_data,
      :input_type,
      :sequence_number
    ]

    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_input_type(%{input_type: type})
       when type in [:text, :keypress, :paste, :control_sequence],
       do: :ok

  defp validate_input_type(%{input_type: type}),
    do: {:error, {:invalid_input_type, type}}

  defp validate_input_data(%{input_data: nil}),
    do: {:error, :input_data_required}

  defp validate_input_data(event) when not is_binary(event.input_data),
    do: {:error, :input_data_must_be_string}

  defp validate_input_data(event) when byte_size(event.input_data) > 10_000,
    do: {:error, :input_data_too_large}

  defp validate_input_data(_event), do: :ok
end

defmodule Raxol.Events.TerminalOutputGeneratedEvent do
  @moduledoc """
  Event emitted when terminal generates output.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :output_data,
    :output_type,
    :sequence_number,
    :generated_at,
    :formatting,
    :metadata
  ]

  @type output_type :: :stdout | :stderr | :control_sequence | :bell

  @type formatting :: %{
          foreground_color: tuple() | nil,
          background_color: tuple() | nil,
          bold: boolean(),
          italic: boolean(),
          underline: boolean()
        }

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          output_data: String.t(),
          output_type: output_type(),
          sequence_number: pos_integer(),
          generated_at: integer(),
          formatting: formatting() | nil,
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_output_type(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :output_data, :output_type, :sequence_number]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_output_type(%{output_type: type})
       when type in [:stdout, :stderr, :control_sequence, :bell],
       do: :ok

  defp validate_output_type(%{output_type: type}),
    do: {:error, {:invalid_output_type, type}}
end

defmodule Raxol.Events.TerminalThemeAppliedEvent do
  @moduledoc """
  Event emitted when a theme is applied to a terminal.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :theme_id,
    :theme_name,
    :color_scheme,
    :font_settings,
    :accessibility_options,
    :previous_theme_id,
    :applied_at,
    :metadata
  ]

  @type color_scheme :: %{
          background: tuple(),
          foreground: tuple(),
          accent: tuple(),
          success: tuple(),
          warning: tuple(),
          error: tuple()
        }

  @type font_settings :: %{
          family: String.t(),
          size: pos_integer(),
          weight: String.t(),
          style: String.t()
        }

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          theme_id: String.t(),
          theme_name: String.t(),
          color_scheme: color_scheme(),
          font_settings: font_settings() | nil,
          accessibility_options: map() | nil,
          previous_theme_id: String.t() | nil,
          applied_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_color_scheme(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :user_id, :theme_id, :theme_name, :color_scheme]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_color_scheme(%{color_scheme: color_scheme})
       when is_map(color_scheme) do
    required_colors = [:background, :foreground]

    missing_colors =
      Enum.filter(required_colors, fn color ->
        not Map.has_key?(color_scheme, color)
      end)

    case Enum.empty?(missing_colors) do
      true -> validate_color_values(color_scheme)
      false -> {:error, {:missing_colors, missing_colors}}
    end
  end

  defp validate_color_scheme(_event),
    do: {:error, :invalid_color_scheme_format}

  defp validate_color_values(color_scheme) do
    invalid_colors =
      color_scheme
      |> Enum.filter(fn {_key, value} ->
        not valid_color?(value)
      end)

    case Enum.empty?(invalid_colors) do
      true -> :ok
      false -> {:error, {:invalid_color_values, invalid_colors}}
    end
  end

  defp valid_color?({r, g, b})
       when is_integer(r) and is_integer(g) and is_integer(b) do
    r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255
  end

  defp valid_color?("#" <> hex) when byte_size(hex) == 6 do
    String.match?(hex, ~r/^[0-9a-fA-F]{6}$/)
  end

  defp valid_color?(_), do: false
end

defmodule Raxol.Events.TerminalClosedEvent do
  @moduledoc """
  Event emitted when a terminal is closed.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :close_reason,
    :session_saved,
    :final_state,
    :uptime_seconds,
    :commands_executed,
    :closed_at,
    :metadata
  ]

  @type close_reason ::
          :user_request
          | :timeout
          | :error
          | :system_shutdown
          | :process_terminated

  @type final_state :: %{
          width: pos_integer(),
          height: pos_integer(),
          scroll_position: integer(),
          cursor_position: {integer(), integer()},
          working_directory: String.t()
        }

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          close_reason: close_reason(),
          session_saved: boolean(),
          final_state: final_state(),
          uptime_seconds: non_neg_integer(),
          commands_executed: non_neg_integer(),
          closed_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_close_reason(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :user_id, :close_reason, :closed_at]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_close_reason(event) do
    valid_reasons = [
      :user_request,
      :timeout,
      :error,
      :system_shutdown,
      :process_terminated
    ]

    case event.close_reason in valid_reasons do
      true -> :ok
      false -> {:error, {:invalid_close_reason, event.close_reason}}
    end
  end
end

defmodule Raxol.Events.TerminalErrorOccurredEvent do
  @moduledoc """
  Event emitted when an error occurs in a terminal.
  """

  # use Raxol.Architecture.EventSourcing.Event

  defstruct [
    :terminal_id,
    :user_id,
    :error_type,
    :error_message,
    :error_code,
    :stack_trace,
    :context,
    :recoverable,
    :occurred_at,
    :metadata
  ]

  @type error_type ::
          :command_error
          | :system_error
          | :network_error
          | :permission_error
          | :resource_error

  @type error_context :: %{
          command: String.t() | nil,
          working_directory: String.t(),
          environment: map(),
          process_id: String.t() | nil
        }

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          error_type: error_type(),
          error_message: String.t(),
          error_code: String.t() | integer() | nil,
          stack_trace: String.t() | nil,
          context: error_context(),
          recoverable: boolean(),
          occurred_at: integer(),
          metadata: map()
        }

  def validate(event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_error_type(event) do
      {:ok, event}
    else
      error -> error
    end
  end

  defp validate_required_fields(event) do
    required = [:terminal_id, :user_id, :error_type, :error_message, :context]
    missing = Enum.filter(required, &(Map.get(event, &1) == nil))

    case Enum.empty?(missing) do
      true -> :ok
      false -> {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_error_type(event) do
    valid_types = [
      :command_error,
      :system_error,
      :network_error,
      :permission_error,
      :resource_error
    ]

    case event.error_type in valid_types do
      true -> :ok
      false -> {:error, {:invalid_error_type, event.error_type}}
    end
  end
end
