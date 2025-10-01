defmodule Raxol.Core.Standards.CodeStyle do
  @moduledoc """
  Defines and enforces code style standards across the Raxol codebase.

  This module provides guidelines and utilities for maintaining consistent
  code patterns, naming conventions, and architectural decisions.
  """

  @doc """
  Module structure template and organization guidelines.
  """
  def module_template do
    """
    defmodule ModuleName do
      @moduledoc \"\"\"
      Brief description of module purpose.

      Detailed explanation including:
      - Main responsibilities
      - Key features
      - Usage examples
      \"\"\"

      # Compile-time configuration
      @default_timeout 5_000
      @max_retries 3

      # Type specifications
      @type state :: %{
        field: type(),
        another_field: another_type()
      }

      @type result :: {:ok, term()} | {:error, reason()}
      @type reason :: atom() | {atom(), term()}

      # Module attributes for behaviour
      @behaviour SomeBehaviour

      # Use macros
      use Raxol.Core.Behaviours.BaseManager

      # Import statements (grouped by origin)
            import Bitwise, only: [band: 2, bor: 2]

      # Alias statements (alphabetically ordered)
      alias Raxol.Core.{ErrorHandler, Logger}
      alias Raxol.Terminal.{Buffer, Cursor}

      # Require statements
      # Public API functions

      @doc \"\"\"
      Starts the process.

      ## Options

      - `:name` - Process name (optional)
      - `:timeout` - Operation timeout in ms (default: 5000)

      ## Examples

          iex> start_link(name: :my_process)
          {:ok, pid}
      \"\"\"
      @spec start_link(keyword()) :: GenServer.on_start()
    #       def start_link(opts \\\\ []) do
    #         GenServer.start_link(__MODULE__, opts, name: opts[:name])
    #       end

      # GenServer callbacks

      @impl true
      def init_manager(opts) do
        state = %{
          timeout: Keyword.get(opts, :timeout, @default_timeout)
        }
        {:ok, state}
      end

      @impl true
      def handle_manager_call(request, from, state)
      def handle_manager_call(:get_state, _from, state) do
        {:reply, {:ok, state}, state}
      end

      # Private functions (grouped by functionality)

      defp internal_helper(arg) do
        # Implementation
      end
    end
    """
  end

  @doc """
  Error handling patterns and conventions.
  """
  def error_handling_patterns do
    %{
      standard_result: """
      # Always use tagged tuples for results
      @spec operation(term()) :: {:ok, result()} | {:error, reason()}
      def operation(input) do
        case validate_input(input) do
          {:ok, valid_input} ->
            perform_operation(valid_input)

          {:error, reason} = error ->
            error
        end
      end
      """,
      with_pattern: """
      # Use 'with' for multiple operations that may fail
      def complex_operation(input) do
        with {:ok, validated} <- validate(input),
             {:ok, processed} <- process(validated),
             {:ok, result} <- finalize(processed) do
          {:ok, result}
        else
          {:error, :validation_failed} = error ->
            Log.module_error("Validation failed: \#{inspect(input)}")
            error

          {:error, reason} = error ->
            Log.module_error("Operation failed: \#{inspect(reason)}")
            error
        end
      end
      """,
      error_types: """
      # Standardized error types
      @type error_reason ::
        :invalid_input
        | :not_found
        | :timeout
        | :permission_denied
        | {:validation_error, field :: atom(), message :: String.t()}
        | {:system_error, details :: term()}
        | {:unexpected_error, Exception.t()}
      """
    }
  end

  @doc """
  Naming conventions for consistency.
  """
  def naming_conventions do
    %{
      modules: [
        "Use CamelCase for module names",
        "Group related modules under common namespaces",
        "Use descriptive names that indicate purpose",
        "Examples: UserManager, AuthenticationService, DataValidator"
      ],
      functions: [
        "Use snake_case for function names",
        "Use descriptive verbs for actions",
        "Use ? suffix for boolean returns",
        "Use ! suffix for functions that may raise",
        "Examples: validate_input, is_valid?, create_user!"
      ],
      variables: [
        "Use snake_case for variable names",
        "Use descriptive names over abbreviations",
        "Avoid single letter variables except in comprehensions",
        "Examples: user_data, validation_result, error_message"
      ],
      constants: [
        "Use SCREAMING_SNAKE_CASE for module attributes used as constants",
        "Prefix with @ for module attributes",
        "Examples: @MAX_RETRIES, @DEFAULT_TIMEOUT, @BUFFER_SIZE"
      ]
    }
  end

  @doc """
  Function documentation standards.
  """
  def documentation_standards do
    %{
      module_doc: """
      @moduledoc \"\"\"
      Brief one-line description.

      Detailed explanation of the module's purpose and responsibilities.

      ## Features

      - Feature 1
      - Feature 2

      ## Examples

          iex> Module.function()
          :result

      ## Implementation Notes

      Any important implementation details.
      \"\"\"
      """,
      function_doc: """
      @doc \"\"\"
      Brief description of what the function does.

      ## Parameters

      - `param1` - Description of parameter 1
      - `param2` - Description of parameter 2

      ## Returns

      Description of return value.

      ## Examples

          iex> function(arg1, arg2)
          {:ok, result}

      ## Raises

      - `ArgumentError` - When invalid arguments provided
      \"\"\"
      @spec function(type1(), type2()) :: {:ok, result()} | {:error, reason()}
      """
    }
  end

  @doc """
  Testing patterns and conventions.
  """
  def testing_patterns do
    %{
      test_structure: """
      defmodule ModuleNameTest do
        use ExUnit.Case, async: true

        alias ModuleName
      alias Raxol.Core.Runtime.Log

        describe "function_name/arity" do
          setup do
            # Setup code
            {:ok, key: value}
          end

          test "successful case description", %{key: value} do
            assert {:ok, result} = ModuleName.function_name(value)
            assert result == expected_value
          end

          test "error case description" do
            assert {:error, :reason} = ModuleName.function_name(invalid_input)
          end

          test "edge case description" do
            # Test edge cases
          end
        end
      end
      """,
      test_naming: [
        "Use descriptive test names that explain the scenario",
        "Format: 'test action when condition then result'",
        "Group related tests with describe blocks",
        "Example: 'test validates input when string is empty then returns error'"
      ]
    }
  end

  @doc """
  GenServer patterns and best practices.
  """
  def genserver_patterns do
    %{
      callback_organization: """
      # Group callbacks by type
      # 1. init/1
      # 2. handle_call/3 clauses
      # 3. handle_cast/2 clauses
      # 4. handle_info/2 clauses
      # 5. terminate/2 (if needed)

      @impl true
      def init_manager(opts) do
        # Always return quickly
        # Schedule initialization work if needed
        {:ok, initial_state()}
      end

      @impl true
      def handle_manager_call(request, from, state)

      def handle_manager_call(:sync_operation, _from, state) do
        case perform_operation(state) do
          {:ok, result, new_state} ->
            {:reply, {:ok, result}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      end

      @impl true
      def handle_manager_cast(request, state)

      def handle_manager_cast({:async_operation, data}, state) do
        new_state = process_async(data, state)
        {:noreply, new_state}
      end
      """,
      state_management: """
      # Define state structure explicitly
      defmodule State do
        @moduledoc false
        defstruct [
          :field1,
          :field2,
          field3: default_value(),
          counters: %{},
          options: []
        ]

        @type t :: %__MODULE__{
          field1: type1(),
          field2: type2(),
          field3: type3(),
          counters: %{atom() => non_neg_integer()},
          options: keyword()
        }
      end
      """
    }
  end

  @doc """
  Pipeline and functional composition patterns.
  """
  def pipeline_patterns do
    %{
      basic_pipeline: """
      def process_data(input) do
        input
        |> validate()
        |> transform()
        |> enrich()
        |> format_output()
      end
      """,
      error_handling_pipeline: """
      def safe_process(input) do
        with {:ok, validated} <- validate(input),
             {:ok, transformed} <- transform(validated),
             {:ok, enriched} <- enrich(transformed) do
          format_output(enriched)
        end
      end
      """,
      stream_pipeline: """
      def process_large_dataset(file_path) do
        file_path
        |> File.stream!()
        |> Stream.map(&parse_line/1)
        |> Stream.filter(&valid?/1)
        |> Stream.map(&transform/1)
        |> Enum.to_list()
      end
      """
    }
  end

  @doc """
  Dependency injection and configuration patterns.
  """
  def configuration_patterns do
    %{
      compile_time: """
      # Use module attributes for compile-time configuration
      @default_timeout Application.compile_env(:raxol, :timeout, 5_000)
      @max_connections Application.compile_env(:raxol, :max_connections, 100)
      """,
      runtime: """
      # Use functions for runtime configuration
      defp get_timeout do
        Application.get_env(:raxol, :timeout, @default_timeout)
      end
      """,
      dependency_injection: """
      # Accept dependencies as parameters
      def new(opts \\\\ []) do
        %__MODULE__{
          logger: Keyword.get(opts, :logger, Logger),
          storage: Keyword.get(opts, :storage, DefaultStorage)
        }
      end
      """
    }
  end

  @doc """
  Performance optimization patterns.
  """
  def performance_patterns do
    %{
      ets_usage: """
      # Use ETS for shared state and caching
      def init_manager(_opts) do
        :ets.new(:cache_table, [:set, :public, :named_table])
        {:ok, %{}}
      end

      def get_cached(key) do
        case :ets.lookup(:cache_table, key) do
          [{^key, value}] -> {:ok, value}
          [] -> :miss
        end
      end
      """,
      pattern_matching: """
      # Use pattern matching for efficiency
      def process_message({:data, payload}) when is_binary(payload) do
        # Fast path for binary data
      end

      def process_message({:data, payload}) when is_list(payload) do
        # Handle list data
      end

      def process_message(message) do
        # Fallback for other cases
      end
      """,
      tail_recursion: """
      # Use tail recursion for large iterations
      def sum_list(list), do: do_sum(list, 0)

      defp do_sum([], acc), do: acc
      defp do_sum([h | t], acc), do: do_sum(t, acc + h)
      """
    }
  end

  @doc """
  Security patterns and best practices.
  """
  def security_patterns do
    %{
      input_validation: """
      # Always validate external input
      def handle_user_input(input) do
        with {:ok, sanitized} <- sanitize_input(input),
             {:ok, validated} <- validate_format(sanitized),
             :ok <- check_permissions(validated) do
          process_input(validated)
        end
      end
      """,
      secrets_handling: """
      # Never hardcode secrets
      defp get_secret_key do
        System.get_env("SECRET_KEY") ||
          raise "SECRET_KEY environment variable not set"
      end
      """,
      defensive_coding: """
      # Defensive programming practices
      def safe_divide(a, b) when b != 0 do
        {:ok, a / b}
      end

      def safe_divide(_, 0) do
        {:error, :division_by_zero}
      end
      """
    }
  end
end
