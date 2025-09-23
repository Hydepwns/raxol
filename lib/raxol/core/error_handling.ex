defmodule Raxol.Core.ErrorHandling do
  @moduledoc """
  Functional error handling patterns for Raxol.

  This module provides composable error handling utilities to replace
  try/catch blocks with more functional patterns. It implements Result
  and Option types along with safe execution functions.

  ## Philosophy

  Instead of using try/catch for error handling, we use:
  - Result types ({:ok, value} | {:error, reason})
  - Safe execution wrappers
  - Pipeline-friendly error handling
  - Explicit error propagation

  ## Examples

      # Instead of try/catch
      result = safe_call(fn -> risky_operation() end)
      
      # Chain operations safely
      with {:ok, data} <- fetch_data(),
           {:ok, processed} <- process_data(data),
           {:ok, result} <- save_result(processed) do
        {:ok, result}
      end
      
      # Safe binary operations
      safe_deserialize(binary_data)
  """

  require Logger

  @type result(ok) :: {:ok, ok} | {:error, term()}
  @type result(ok, error) :: {:ok, ok} | {:error, error}

  # ========================================
  # Core Safe Execution Functions
  # ========================================

  @doc """
  Safely executes a function and returns a Result type.

  ## Examples

      iex> safe_call(fn -> 1 + 1 end)
      {:ok, 2}
      
      iex> safe_call(fn -> raise "oops" end)
      {:error, %RuntimeError{message: "oops"}}
  """
  @spec safe_call((-> any())) :: {:ok, any()} | {:error, Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
  def safe_call(fun) when is_function(fun, 0) do
    {:ok, fun.()}
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
    :throw, value -> {:error, {:throw, value}}
    kind, reason -> {:error, {kind, reason}}
  end

  @doc """
  Safely executes a function and returns error details with stacktrace for re-raising.

  ## Examples

      iex> safe_call_with_info(fn -> 42 end)
      {:ok, 42}
      
      iex> safe_call_with_info(fn -> raise "oops" end)
      {:error, {:error, %RuntimeError{message: "oops"}, [...]}}
  """
  @spec safe_call_with_info((-> any())) ::
          {:ok, any()} | {:error, {atom(), any(), list()}}
  def safe_call_with_info(fun) when is_function(fun, 0) do
    {:ok, fun.()}
  rescue
    error -> {:error, {:error, error, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  @doc """
  Safely executes a function with a fallback value on error.

  ## Examples

      iex> safe_call_with_default(fn -> raise "oops" end, 42)
      42
  """
  @spec safe_call_with_default((-> any()), any()) :: any()
  def safe_call_with_default(fun, default) when is_function(fun, 0) do
    case safe_call(fun) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end

  @doc """
  Safely executes a function with error logging.

  ## Examples

      safe_call_with_logging(fn -> process() end, "Processing failed")
  """
  @spec safe_call_with_logging((-> any()), String.t()) :: result(any())
  def safe_call_with_logging(fun, context) when is_function(fun, 0) do
    case safe_call(fun) do
      {:ok, _} = success ->
        success

      {:error, reason} = error ->
        Logger.error("#{context}: #{inspect(reason)}")
        error
    end
  end

  # ========================================
  # Binary Operations
  # ========================================

  @doc """
  Safely deserializes Erlang terms from binary data.

  ## Examples

      iex> binary = :erlang.term_to_binary({:ok, "data"})
      iex> safe_deserialize(binary)
      {:ok, {:ok, "data"}}
      
      iex> safe_deserialize("invalid")
      {:error, :invalid_binary}
  """
  @spec safe_deserialize(binary()) :: {:ok, term()} | {:error, :invalid_binary}
  def safe_deserialize(binary) when is_binary(binary) do
    safe_call(fn -> :erlang.binary_to_term(binary, [:safe]) end)
    |> normalize_deserialize_error()
  end

  defp normalize_deserialize_error({:error, _}) do
    {:error, :invalid_binary}
  end

  defp normalize_deserialize_error(result), do: result

  @doc """
  Safely serializes a term to binary.
  """
  @spec safe_serialize(term()) :: result(binary())
  def safe_serialize(term) do
    safe_call(fn -> :erlang.term_to_binary(term) end)
  end

  # ========================================
  # File Operations
  # ========================================

  @doc """
  Safely reads and deserializes a file.

  ## Examples

      safe_read_term("/path/to/file")
  """
  @spec safe_read_term(Path.t()) :: {:ok, term()} | {:error, atom()}
  def safe_read_term(path) do
    with {:ok, binary} <- File.read(path),
         {:ok, term} <- safe_deserialize(binary) do
      {:ok, term}
    end
  end

  @doc """
  Safely writes a term to a file.
  """
  @spec safe_write_term(Path.t(), term()) :: result(:ok)
  def safe_write_term(path, term) do
    with {:ok, binary} <- safe_serialize(term),
         :ok <- File.write(path, binary) do
      {:ok, :ok}
    end
  end

  # ========================================
  # Module Operations
  # ========================================

  @doc """
  Safely calls a module function if it's exported.

  ## Examples

      safe_apply(MyModule, :init, [])
  """
  @spec safe_apply(module(), atom(), list()) :: {:ok, any()} | {:error, atom()}
  def safe_apply(module, function, args) do
    case function_exported?(module, function, length(args)) do
      true -> safe_call(fn -> apply(module, function, args) end)
      false -> {:error, :function_not_exported}
    end
  end

  @doc """
  Safely makes a GenServer call with proper error handling.

  ## Examples

      safe_genserver_call(MyServer, :get_state)
  """
  @spec safe_genserver_call(GenServer.server(), any(), timeout()) ::
          result(any())
  def safe_genserver_call(server, message, timeout \\ 5000) do
    try do
      result = GenServer.call(server, message, timeout)
      {:ok, result}
    catch
      :exit, {:noproc, _} -> {:error, :not_available}
      :exit, {:timeout, _} -> {:error, :timeout}
      kind, reason -> {:error, {kind, reason}}
    end
  end

  @doc """
  Safely calls an optional callback on a module.
  Returns {:ok, nil} if the callback doesn't exist.
  """
  @spec safe_callback(module(), atom(), list()) :: {:ok, any()} | {:error, Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
  def safe_callback(module, function, args) do
    case function_exported?(module, function, length(args)) do
      true -> safe_call(fn -> apply(module, function, args) end)
      false -> {:ok, nil}
    end
  end

  # ========================================
  # Arithmetic Operations
  # ========================================

  @doc """
  Safely performs arithmetic with a fallback for nil values.

  ## Examples

      safe_arithmetic(fn x -> x + 10 end, nil, 0)
      # => 10 (uses fallback 0, then adds 10)
  """
  @spec safe_arithmetic((number() -> number()), any(), number()) :: number()
  def safe_arithmetic(fun, value, fallback \\ 0) do
    safe_value =
      case is_number(value) do
        true -> value
        false -> fallback
      end

    case safe_call(fn -> fun.(safe_value) end) do
      {:ok, result} when is_number(result) -> result
      _ -> fallback
    end
  end

  # ========================================
  # Pipeline Helpers
  # ========================================

  @doc """
  Maps over a Result type.

  ## Examples

      {:ok, 5}
      |> map(fn x -> x * 2 end)
      # => {:ok, 10}
  """
  @spec map(result(a), (a -> b)) :: result(b) when a: any(), b: any()
  def map({:ok, value}, fun) when is_function(fun, 1) do
    safe_call(fn -> fun.(value) end)
  end

  def map({:error, _} = error, _fun), do: error

  @doc """
  FlatMaps over a Result type.

  ## Examples

      {:ok, 5}
      |> flat_map(fn x -> {:ok, x * 2} end)
      # => {:ok, 10}
  """
  @spec flat_map(result(a), (a -> result(b))) :: result(b)
        when a: any(), b: any()
  def flat_map({:ok, value}, fun) when is_function(fun, 1) do
    case safe_call(fn -> fun.(value) end) do
      {:ok, result} -> result
      error -> error
    end
  end

  def flat_map({:error, _} = error, _fun), do: error

  @doc """
  Unwraps a Result or returns a default value.

  ## Examples

      unwrap_or({:ok, 42}, 0)     # => 42
      unwrap_or({:error, _}, 0)   # => 0
  """
  @spec unwrap_or(result(a), a) :: a when a: any()
  def unwrap_or({:ok, value}, _default), do: value
  def unwrap_or({:error, _}, default), do: default

  @doc """
  Unwraps a Result or calls a function to get default.

  ## Examples

      unwrap_or_else({:error, :not_found}, fn -> fetch_default() end)
  """
  @spec unwrap_or_else(result(a), (-> a)) :: a when a: any()
  def unwrap_or_else({:ok, value}, _fun), do: value
  def unwrap_or_else({:error, _}, fun) when is_function(fun, 0), do: fun.()

  # ========================================
  # Cleanup Helpers
  # ========================================

  @doc """
  Ensures a cleanup function is called even if the main function fails.

  ## Examples

      with_cleanup(
        fn -> open_resource() end,
        fn resource -> close_resource(resource) end
      )
  """
  @spec with_cleanup((-> result(a)), (a -> any())) :: result(a) when a: any()
  def with_cleanup(main_fun, cleanup_fun) when is_function(cleanup_fun, 1) do
    case safe_call(main_fun) do
      {:ok, value} = success ->
        _ = safe_call(fn -> cleanup_fun.(value) end)
        success

      error ->
        error
    end
  end

  @doc """
  Ensures cleanup is called regardless of success or failure.
  """
  @spec ensure_cleanup((-> any()), (-> any())) :: {:ok, any()} | {:error, Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
  def ensure_cleanup(main_fun, cleanup_fun) do
    result = safe_call(main_fun)
    _ = safe_call(cleanup_fun)
    result
  end

  # ========================================
  # Batch Operations
  # ========================================

  @doc """
  Safely executes multiple operations, collecting all results.

  ## Examples

      safe_batch([
        fn -> operation1() end,
        fn -> operation2() end,
        fn -> operation3() end
      ])
      # => [{:ok, result1}, {:error, error2}, {:ok, result3}]
  """
  @spec safe_batch([(-> any())]) :: [result(any())]
  def safe_batch(functions) when is_list(functions) do
    Enum.map(functions, &safe_call/1)
  end

  @doc """
  Executes operations until one fails.
  """
  @spec safe_sequence([(-> any())]) :: result([any()])
  def safe_sequence(functions) when is_list(functions) do
    do_safe_sequence(functions, [])
  end

  defp do_safe_sequence([], results) do
    {:ok, Enum.reverse(results)}
  end

  defp do_safe_sequence([fun | rest], results) do
    case safe_call(fun) do
      {:ok, result} -> do_safe_sequence(rest, [result | results])
      error -> error
    end
  end
end
