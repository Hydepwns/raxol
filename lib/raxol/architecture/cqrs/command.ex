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

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end

  @doc """
  Validates email format.
  """
  def validate_email(email) when is_binary(email) do
    if String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      :ok
    else
      {:error, :invalid_email_format}
    end
  end

  def validate_email(nil), do: {:error, :email_required}
  def validate_email(_), do: {:error, :invalid_email_type}

  @doc """
  Validates a field is within a specified range.
  """
  def validate_range(value, min, max) when is_number(value) do
    if value >= min and value <= max do
      :ok
    else
      {:error, {:value_out_of_range, value, min, max}}
    end
  end

  def validate_range(_, _, _), do: {:error, :invalid_range_value}

  @doc """
  Validates a field matches one of the allowed values.
  """
  def validate_inclusion(value, allowed_values) when is_list(allowed_values) do
    if value in allowed_values do
      :ok
    else
      {:error, {:value_not_allowed, value, allowed_values}}
    end
  end

  @doc """
  Validates string length is within bounds.
  """
  def validate_length(value, min, max) when is_binary(value) do
    length = String.length(value)

    if length >= min and length <= max do
      :ok
    else
      {:error, {:invalid_length, length, min, max}}
    end
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
end
