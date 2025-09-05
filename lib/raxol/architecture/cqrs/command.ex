defmodule Raxol.Architecture.CQRS.Command do
  @moduledoc """
  Base command module for CQRS pattern implementation in Raxol.

  Commands represent write operations in the system and encapsulate
  the intent to perform an action. All commands should be immutable
  and contain all the data necessary to perform the operation.

  ## Command Design Principles

  1. **Intention Revealing**: Command names should express business intent
  2. **Immutable**: Commands should be immutable once created
  3. **Self-Contained**: Commands should contain all necessary data
  4. **Validated**: Commands should validate their data upon creation
  5. **Traceable**: Commands should include metadata for auditing

  ## Usage

      defmodule MyApp.Commands.CreateUserCommand do
        use Raxol.Architecture.CQRS.Command
        
        defstruct [:user_id, :name, :email, :created_by, :metadata]
        
        @type t :: %__MODULE__{
          user_id: String.t(),
          name: String.t(),
          email: String.t(),
          created_by: String.t(),
          metadata: map()
        }
        
        def new(attrs) do
          %__MODULE__{
            user_id: attrs[:user_id] || UUID.uuid4(),
            name: attrs[:name],
            email: attrs[:email],
            created_by: attrs[:created_by],
            metadata: build_metadata(attrs)
          }
          |> validate()
        end
        
        defp validate(%__MODULE__{} = command) do
          with :ok <- validate_required(command, [:name, :email, :created_by]),
               :ok <- validate_email(command.email) do
            {:ok, command}
          else
            {:error, reason} -> {:error, reason}
          end
        end
      end
  """

  @type t :: struct()

  @callback new(attrs :: map()) :: {:ok, struct()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Architecture.CQRS.Command

      import Raxol.Architecture.CQRS.Command

      @doc """
      Creates a new command with validation.
      """
      def new(attrs) when is_map(attrs) do
        command =
          struct(__MODULE__, attrs)
          |> Map.put(:command_id, generate_command_id())
          |> Map.put(:timestamp, System.system_time(:millisecond))
          |> Map.put(
            :correlation_id,
            Map.get(attrs, :correlation_id, generate_correlation_id())
          )

        validate(command)
      end

      def new(attrs) when is_list(attrs) do
        new(Enum.into(attrs, %{}))
      end

      # Default validation - can be overridden
      def validate(command) do
        {:ok, command}
      end

      defoverridable new: 1, validate: 1
    end
  end

  @doc """
  Validates required fields are present in the command.
  """
  def validate_required(command, required_fields) do
    missing_fields =
      Enum.filter(required_fields, fn field ->
        case Map.get(command, field) do
          nil -> true
          "" -> true
          _ -> false
        end
      end)

    validate_missing_fields(Enum.empty?(missing_fields), missing_fields)
  end

  @doc """
  Validates email format.
  """
  def validate_email(email) when is_binary(email) do
    validate_email_format(String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/))
  end

  def validate_email(nil), do: {:error, :email_required}
  def validate_email(_), do: {:error, :invalid_email_type}

  @doc """
  Validates a field is within a specified range.
  """
  def validate_range(value, min, max) when is_number(value) do
    validate_value_range(value >= min and value <= max, value, min, max)
  end

  def validate_range(_, _, _), do: {:error, :invalid_range_value}

  @doc """
  Validates a field matches one of the allowed values.
  """
  def validate_inclusion(value, allowed_values) when is_list(allowed_values) do
    validate_value_inclusion(value in allowed_values, value, allowed_values)
  end

  @doc """
  Validates string length is within bounds.
  """
  def validate_length(value, min, max) when is_binary(value) do
    length = String.length(value)

    validate_string_length(length >= min and length <= max, length, min, max)
  end

  def validate_length(nil, min, _max) when min > 0 do
    {:error, :value_required}
  end

  def validate_length(_, _, _), do: {:error, :invalid_length_value}

  @doc """
  Builds standard command metadata.
  """
  def build_metadata(attrs) do
    %{
      created_at: System.system_time(:millisecond),
      source: Map.get(attrs, :source, "system"),
      user_agent: Map.get(attrs, :user_agent),
      ip_address: Map.get(attrs, :ip_address),
      session_id: Map.get(attrs, :session_id),
      request_id: Map.get(attrs, :request_id),
      version: Map.get(attrs, :version, "1.0")
    }
  end

  @doc """
  Generates a unique command ID.
  """
  def generate_command_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  @doc """
  Generates a correlation ID for tracking related commands.
  """
  def generate_correlation_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  @doc """
  Extracts command type from a command struct.
  """
  def command_type(%{__struct__: module}) do
    module
    |> Module.split()
    |> List.last()
    |> String.replace("Command", "")
  end

  @doc """
  Creates a command result structure.
  """
  def create_result(command, status, data \\ nil, error \\ nil) do
    %{
      command_id: Map.get(command, :command_id),
      command_type: command_type(command),
      status: status,
      data: data,
      error: error,
      processed_at: System.system_time(:millisecond),
      processing_time_ms: calculate_processing_time(command)
    }
  end

  defp calculate_processing_time(command) do
    case Map.get(command, :timestamp) do
      nil -> 0
      timestamp -> System.system_time(:millisecond) - timestamp
    end
  end

  # Helper functions to eliminate if statements

  defp validate_missing_fields(true, _missing_fields), do: :ok

  defp validate_missing_fields(false, missing_fields) do
    {:error, {:missing_required_fields, missing_fields}}
  end

  defp validate_email_format(true), do: :ok

  defp validate_email_format(false), do: {:error, :invalid_email_format}

  defp validate_value_range(true, _value, _min, _max), do: :ok

  defp validate_value_range(false, value, min, max) do
    {:error, {:value_out_of_range, value, min, max}}
  end

  defp validate_value_inclusion(true, _value, _allowed_values), do: :ok

  defp validate_value_inclusion(false, value, allowed_values) do
    {:error, {:value_not_allowed, value, allowed_values}}
  end

  defp validate_string_length(true, _length, _min, _max), do: :ok

  defp validate_string_length(false, length, min, max) do
    {:error, {:invalid_length, length, min, max}}
  end
end
