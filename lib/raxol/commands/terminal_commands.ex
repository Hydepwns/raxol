defmodule Raxol.Commands.CreateTerminalCommand do
  @moduledoc """
  Command to create a new terminal instance.
  """

  use Raxol.Architecture.CQRS.Command
  import Raxol.Architecture.CQRS.Command

  defstruct [
    :command_id,
    :timestamp,
    :correlation_id,
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
    :metadata
  ]

  @type t :: %__MODULE__{
          command_id: String.t(),
          timestamp: integer(),
          correlation_id: String.t(),
          terminal_id: String.t(),
          user_id: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          shell_command: String.t() | nil,
          working_directory: String.t() | nil,
          environment_variables: map() | nil,
          theme: String.t() | nil,
          font_settings: map() | nil,
          accessibility_options: map() | nil,
          metadata: map()
        }

  def new(attrs) do
    enhanced_attrs =
      attrs
      |> Map.put_new(:terminal_id, generate_terminal_id())
      |> Map.put_new(:width, 80)
      |> Map.put_new(:height, 24)
      |> Map.put_new(:working_directory, System.user_home!())
      |> Map.put_new(:metadata, build_metadata(attrs))

    # Call the parent implementation with enhanced attributes
    super(enhanced_attrs)
  end

  def validate(command) do
    with :ok <-
           validate_required(command, [:terminal_id, :user_id, :width, :height]),
         :ok <- validate_dimensions(command),
         :ok <- validate_user_permissions(command) do
      {:ok, command}
    else
      error -> error
    end
  end

  defp validate_dimensions(command) do
    with :ok <- validate_range(command.width, 20, 300),
         :ok <- validate_range(command.height, 5, 100) do
      :ok
    else
      {:error, reason} -> {:error, {:invalid_dimensions, reason}}
    end
  end

  defp validate_user_permissions(command) do
    # In a real implementation, would check user permissions
    if command.user_id do
      :ok
    else
      {:error, :user_not_authenticated}
    end
  end

  defp generate_terminal_id do
    "term_" <>
      (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end
end

defmodule Raxol.Commands.UpdateTerminalCommand do
  @moduledoc """
  Command to update terminal settings.
  """

  use Raxol.Architecture.CQRS.Command

  defstruct [
    :command_id,
    :timestamp,
    :correlation_id,
    :terminal_id,
    :user_id,
    :width,
    :height,
    :title,
    :theme,
    :font_settings,
    :accessibility_options,
    :expected_version,
    :metadata
  ]

  @type t :: %__MODULE__{
          command_id: String.t(),
          timestamp: integer(),
          correlation_id: String.t(),
          terminal_id: String.t(),
          user_id: String.t(),
          width: pos_integer() | nil,
          height: pos_integer() | nil,
          title: String.t() | nil,
          theme: String.t() | nil,
          font_settings: map() | nil,
          accessibility_options: map() | nil,
          expected_version: integer(),
          metadata: map()
        }

  def new(attrs) do
    enhanced_attrs =
      attrs
      |> Map.put_new(:metadata, build_metadata(attrs))

    super(enhanced_attrs)
  end

  def validate(command) do
    with :ok <-
           validate_required(command, [
             :terminal_id,
             :user_id,
             :expected_version
           ]),
         :ok <- validate_dimensions_if_present(command) do
      {:ok, command}
    else
      error -> error
    end
  end

  defp validate_dimensions_if_present(command) do
    cond do
      command.width && not (command.width >= 20 && command.width <= 300) ->
        {:error, {:invalid_width, command.width}}

      command.height && not (command.height >= 5 && command.height <= 100) ->
        {:error, {:invalid_height, command.height}}

      true ->
        :ok
    end
  end
end

defmodule Raxol.Commands.SendInputCommand do
  @moduledoc """
  Command to send input to a terminal.
  """

  use Raxol.Architecture.CQRS.Command

  defstruct [
    :command_id,
    :timestamp,
    :correlation_id,
    :terminal_id,
    :user_id,
    :input_data,
    :input_type,
    :sequence_number,
    :metadata
  ]

  @type input_type :: :text | :keypress | :paste | :control_sequence

  @type t :: %__MODULE__{
          command_id: String.t(),
          timestamp: integer(),
          correlation_id: String.t(),
          terminal_id: String.t(),
          user_id: String.t(),
          input_data: String.t(),
          input_type: input_type(),
          sequence_number: integer() | nil,
          metadata: map()
        }

  def new(attrs) do
    enhanced_attrs =
      attrs
      |> Map.put_new(:input_type, :text)
      |> Map.put_new(:metadata, build_metadata(attrs))

    super(enhanced_attrs)
  end

  def validate(command) do
    with :ok <-
           validate_required(command, [:terminal_id, :user_id, :input_data]),
         :ok <- validate_input_type(command),
         :ok <- validate_input_data(command) do
      {:ok, command}
    else
      error -> error
    end
  end

  defp validate_input_type(command) do
    valid_types = [:text, :keypress, :paste, :control_sequence]
    validate_inclusion(command.input_type, valid_types)
  end

  defp validate_input_data(command) do
    cond do
      is_nil(command.input_data) ->
        {:error, :input_data_required}

      byte_size(command.input_data) > 10_000 ->
        {:error, :input_data_too_large}

      true ->
        :ok
    end
  end
end

defmodule Raxol.Commands.CloseTerminalCommand do
  @moduledoc """
  Command to close a terminal and clean up resources.
  """

  use Raxol.Architecture.CQRS.Command

  defstruct [
    :command_id,
    :timestamp,
    :correlation_id,
    :terminal_id,
    :user_id,
    :reason,
    :save_session,
    :expected_version,
    :metadata
  ]

  @type close_reason :: :user_request | :timeout | :error | :system_shutdown

  @type t :: %__MODULE__{
          command_id: String.t(),
          timestamp: integer(),
          correlation_id: String.t(),
          terminal_id: String.t(),
          user_id: String.t(),
          reason: close_reason(),
          save_session: boolean(),
          expected_version: integer(),
          metadata: map()
        }

  def new(attrs) do
    enhanced_attrs =
      attrs
      |> Map.put_new(:reason, :user_request)
      |> Map.put_new(:save_session, true)
      |> Map.put_new(:metadata, build_metadata(attrs))

    super(enhanced_attrs)
  end

  def validate(command) do
    with :ok <-
           validate_required(command, [
             :terminal_id,
             :user_id,
             :expected_version
           ]),
         :ok <- validate_close_reason(command) do
      {:ok, command}
    else
      error -> error
    end
  end

  defp validate_close_reason(command) do
    valid_reasons = [:user_request, :timeout, :error, :system_shutdown]
    validate_inclusion(command.reason, valid_reasons)
  end
end

defmodule Raxol.Commands.ApplyThemeCommand do
  @moduledoc """
  Command to apply a theme to a terminal.
  """

  use Raxol.Architecture.CQRS.Command

  defstruct [
    :command_id,
    :timestamp,
    :correlation_id,
    :terminal_id,
    :user_id,
    :theme_id,
    :theme_settings,
    :high_contrast_mode,
    :accessibility_options,
    :expected_version,
    :metadata
  ]

  @type t :: %__MODULE__{
          command_id: String.t(),
          timestamp: integer(),
          correlation_id: String.t(),
          terminal_id: String.t(),
          user_id: String.t(),
          theme_id: String.t(),
          theme_settings: map() | nil,
          high_contrast_mode: boolean(),
          accessibility_options: map() | nil,
          expected_version: integer(),
          metadata: map()
        }

  def new(attrs) do
    enhanced_attrs =
      attrs
      |> Map.put_new(:high_contrast_mode, false)
      |> Map.put_new(:metadata, build_metadata(attrs))

    super(enhanced_attrs)
  end

  def validate(command) do
    with :ok <-
           validate_required(command, [
             :terminal_id,
             :user_id,
             :theme_id,
             :expected_version
           ]),
         :ok <- validate_theme_settings(command) do
      {:ok, command}
    else
      error -> error
    end
  end

  defp validate_theme_settings(command) do
    # Validate theme settings if provided
    case command.theme_settings do
      nil ->
        :ok

      settings when is_map(settings) ->
        validate_color_values(settings)

      _ ->
        {:error, :invalid_theme_settings_format}
    end
  end

  defp validate_color_values(settings) do
    # Validate color format in theme settings
    color_keys = [:background, :foreground, :accent, :success, :warning, :error]

    invalid_colors =
      Enum.filter(color_keys, fn key ->
        case Map.get(settings, key) do
          nil ->
            false

          {r, g, b}
          when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and
                 b <= 255 ->
            false

          "#" <> hex when byte_size(hex) == 6 ->
            false

          _ ->
            true
        end
      end)

    if Enum.empty?(invalid_colors) do
      :ok
    else
      {:error, {:invalid_colors, invalid_colors}}
    end
  end
end
