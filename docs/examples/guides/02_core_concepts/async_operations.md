# Asynchronous Operations in Raxol

This guide explains how to perform asynchronous operations in Raxol applications.

## Overview

Asynchronous operations in Raxol follow a message-passing pattern. Instead of blocking the UI thread, operations run in separate processes and communicate with the main application via messages.

## Basic Pattern

The basic pattern for asynchronous operations is:

1. Start an operation in a separate process (using `Task`, `GenServer`, etc.)
2. Have that process send a message back to the application when complete
3. Handle the message in the application's `update` function

## Example: Asynchronous Data Loading

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_context) do
    # Start an async operation immediately
    Task.async(fn -> load_data() end)
    {:ok, %{status: :loading, data: nil}, []}
  end

  @impl true
  def update(message, state) do
    case message do
      {:data_loaded, data} ->
        # Handle the completed async operation
        {:ok, %{state | status: :loaded, data: data}, []}

      {:error, reason} ->
        # Handle errors
        {:ok, %{state | status: :error, error: reason}, []}

      :reload ->
        # Start a new async operation
        Task.async(fn -> load_data() end)
        {:ok, %{state | status: :loading}, []}

      _ ->
        {:ok, state, []}
    end
  end

  @impl true
  def handle_event({:task_result, task_ref, result}, state) do
    # This callback handles results from Task.async
    case result do
      {:ok, data} -> {:ok, state, [{:dispatch, {:data_loaded, data}}]}
      {:error, reason} -> {:ok, state, [{:dispatch, {:error, reason}}]}
    end
  end

  @impl true
  def view(state) do
    view do
      panel title: "Data Viewer" do
        case state.status do
          :loading -> text(content: "Loading data...")
          :loaded -> display_data(state.data)
          :error -> text(content: "Error: #{state.error}")
        end
        button(label: "Reload", on_click: :reload)
      end
    end
  end

  defp load_data do
    # Simulate network request
    :timer.sleep(1000)
    {:ok, ["Data", "loaded", "successfully"]}
  end

  defp display_data(data) do
    box do
      for item <- data do
        text(content: item)
      end
    end
  end
end
```

## Best Practices

1. **Show Loading States**: Always update the UI to indicate an operation is in progress
2. **Handle Errors**: Always handle potential errors from async operations
3. **Cancellation**: Consider how to handle cancellation of long-running operations
4. **Rate Limiting**: Prevent spamming of async operations (e.g., debounce user input)
5. **Resource Cleanup**: Ensure proper cleanup of resources when operations complete or fail
6. **State Management**: Keep track of operation state in your application model
7. **Error Recovery**: Implement retry mechanisms for failed operations when appropriate

## Using Tasks

For simple operations, `Task.async/1` and `Task.start/1` are convenient:

```elixir
# When you want the result
Task.async(fn -> expensive_operation() end)

# When you don't need the result
Task.start(fn ->
  expensive_operation()
  # You can still send a message when done
  send(self(), :operation_complete)
end)
```

## Using GenServers

For more complex operations, consider using a GenServer:

```elixir
# In your application
def update(:start_operation, state) do
  {:ok, pid} = MyApp.Worker.start_link(%{caller: self()})
  MyApp.Worker.perform_operation(pid, some_args)
  {:ok, state, []}
end

# Worker implementation
defmodule MyApp.Worker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def perform_operation(pid, args) do
    GenServer.cast(pid, {:perform, args})
  end

  @impl true
  def init(opts) do
    {:ok, %{caller: opts.caller}}
  end

  @impl true
  def handle_cast({:perform, args}, state) do
    result = do_expensive_work(args)
    send(state.caller, {:operation_result, result})
    # GenServer can terminate after sending result
    {:stop, :normal, state}
  end
end
```

## Timeouts and Cancellation

Consider implementing timeouts for operations that might take too long:

```elixir
def init(_) do
  operation_id = System.unique_integer([:positive])
  Task.async(fn -> load_data(operation_id) end)
  # Set a timeout
  Process.send_after(self(), {:timeout, operation_id}, 5000)
  {:ok, %{id: operation_id, status: :loading}, []}
end

def update({:timeout, id}, %{id: id, status: :loading} = state) do
  # Operation timed out
  {:ok, %{state | status: :timeout}, []}
end
```

For more complex scenarios, consider using `Task.Supervisor` for proper task management and cancellation:

```elixir
defmodule MyApp.TaskSupervisor do
  use Task.Supervisor

  def start_link(init_arg) do
    Task.Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    %{strategy: :one_for_one}
  end

  def start_task(fun) do
    Task.Supervisor.start_child(__MODULE__, fun)
  end
end
```

## Error Handling

Always implement proper error handling for async operations:

```elixir
def update({:task_result, _ref, {:ok, result}}, state) do
  {:ok, %{state | data: result, status: :loaded}, []}
end

def update({:task_result, _ref, {:error, reason}}, state) do
  {:ok, %{state | error: reason, status: :error}, []}
end

def update({:task_result, _ref, :exit}, state) do
  {:ok, %{state | error: "Task crashed", status: :error}, []}
end
```

## Resource Management

For operations that require resource cleanup:

```elixir
defmodule MyApp.ResourceManager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {:ok, %{resources: %{}, caller: opts.caller}}
  end

  def handle_cast({:start_operation, id, args}, state) do
    # Start operation and track resource
    resource = acquire_resource()
    task = Task.async(fn -> do_work(resource, args) end)

    new_resources = Map.put(state.resources, id, {task, resource})
    {:noreply, %{state | resources: new_resources}}
  end

  def handle_info({:task_result, task_ref, result}, state) do
    # Find and cleanup resource
    {id, {^task_ref, resource}} = Enum.find(state.resources, fn {_, {t, _}} -> t.ref == task_ref end)
    release_resource(resource)

    # Send result to caller
    send(state.caller, {:operation_complete, id, result})

    # Remove from tracking
    new_resources = Map.delete(state.resources, id)
    {:noreply, %{state | resources: new_resources}}
  end
end
```
