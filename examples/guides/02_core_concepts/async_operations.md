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
  operation_ref = make_ref()
  Task.async(fn -> load_data(operation_ref) end)
  # Set a timeout
  Process.send_after(self(), {:timeout, operation_ref}, 5000)
  {:ok, %{ref: operation_ref, status: :loading}, []}
end

def update({:timeout, ref}, %{ref: ref, status: :loading} = state) do
  # Operation timed out
  {:ok, %{state | status: :timeout}, []}
end
```

For more complex scenarios, consider using `Task.Supervisor` for proper task management and cancellation.
