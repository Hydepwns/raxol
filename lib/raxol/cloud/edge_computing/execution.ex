defmodule Raxol.Cloud.EdgeComputing.Execution do
  @moduledoc """
  Function execution logic for edge computing.
  """

  import Raxol.Guards

  alias Raxol.Cloud.EdgeComputing.{Core, Queue}

  @doc """
  Executes a function at the edge or in the cloud based on current mode and conditions.

  ## Options

  * `:force_edge` - Force execution at the edge even in hybrid mode (default: false)
  * `:force_cloud` - Force execution in the cloud even in hybrid mode (default: false)
  * `:fallback_fn` - Function to execute if primary execution fails (default: nil)
  * `:timeout` - Timeout in milliseconds for the operation (default: 5000)
  * `:retry` - Number of retry attempts (default: from config)

  ## Examples

      iex> execute(fn -> process_data(data) end)
      {:ok, result}
  """
  def execute(func, opts \\ []) when function?(func, 0) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
    state = Core.get_state()

    execute_location = determine_execution_location(state, opts)

    case execute_location do
      :edge ->
        execute_at_edge(func, opts)

      :cloud ->
        execute_in_cloud(func, opts)

      :hybrid ->
        # Try edge first, fallback to cloud
        case execute_at_edge(func, opts) do
          {:ok, result} ->
            {:ok, result}

          {:error, _reason} ->
            # Log the edge failure
            record_metric(:edge_failure)
            # Try cloud as fallback
            execute_in_cloud(func, opts)
        end
    end
  end

  # Private functions

  defp determine_execution_location(state, opts) do
    force_edge = Keyword.get(opts, :force_edge, false)
    force_cloud = Keyword.get(opts, :force_cloud, false)

    cond do
      # Check forced options
      force_edge ->
        :edge

      force_cloud ->
        :cloud

      # Check configured mode
      state.mode == :edge_only ->
        :edge

      state.mode == :cloud_only ->
        :cloud

      # If hybrid, check cloud status
      state.mode == :hybrid and state.cloud_status != :connected ->
        :edge

      # If hybrid, check if function is prioritized for edge
      state.mode == :hybrid and prioritized_for_edge?(opts[:function_name]) ->
        :edge

      # If hybrid, check resource availability for optimal execution
      state.mode == :hybrid ->
        :hybrid

      # Default to edge
      true ->
        :edge
    end
  end

  defp prioritized_for_edge?(function_name) do
    state = Core.get_state()

    function_name && function_name in state.config.priority_functions
  end

  defp execute_at_edge(func, opts) do
    # Record metric
    record_metric(:edge_request)

    # Execute with timeout
    timeout = Keyword.get(opts, :timeout, 5000)

    task = Task.async(func)

    try do
      result = Task.await(task, timeout)
      {:ok, result}
    catch
      :exit, {:timeout, _} ->
        _ = Task.shutdown(task)
        {:error, :timeout}

      kind, reason ->
        _ = Task.shutdown(task)
        {:error, {kind, reason}}
    end
  end

  defp execute_in_cloud(func, opts) do
    # Record metric
    record_metric(:cloud_request)

    state = Core.get_state()

    # Check if we're connected to the cloud
    if state.cloud_status == :connected do
      # Execute the function in the cloud
      try do
        # Simulate cloud execution
        _result = func.()
        :ok
      rescue
        _ ->
          # In a real implementation, we would track attempts
          :retry
      end
    else
      # We're offline, queue the operation for later
      operation_id =
        Queue.enqueue_operation(:function, %{function: func, options: opts})

      # Return queued status
      {:ok, %{status: :queued, operation_id: operation_id}}
    end
  end

  defp record_metric(metric_type) do
    Core.with_state(fn state ->
      updated_metrics =
        case metric_type do
          :edge_request ->
            Map.update!(state.metrics, :edge_requests, &(&1 + 1))

          :cloud_request ->
            Map.update!(state.metrics, :cloud_requests, &(&1 + 1))

          :edge_failure ->
            Map.update!(state.metrics, :edge_failures, &(&1 + 1))

          _other ->
            # Handle any other metric types
            state.metrics
        end

      %{state | metrics: updated_metrics}
    end)
  end
end
