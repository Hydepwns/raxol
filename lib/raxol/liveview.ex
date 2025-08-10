defmodule Raxol.LiveView do
  @moduledoc """
  Phoenix LiveView integration for Raxol.

  Brings familiar LiveView patterns to terminal applications,
  including assigns, events, and lifecycle hooks.
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer
      import Raxol.LiveView

      def mount(terminal, params \\ %{}, session \\ %{}) do
        {:ok, pid} = start_link(terminal, params, session)
        pid
      end

      def start_link(terminal, params, session) do
        GenServer.start_link(__MODULE__, {terminal, params, session})
      end

      @impl GenServer
      def init({terminal, params, session}) do
        socket = %{
          assigns: %{},
          changed: %{},
          terminal: terminal,
          connected?: true
        }

        case mount(params, session, socket) do
          {:ok, socket} ->
            send(self(), :render)
            {:ok, socket}

          {:error, reason} ->
            {:stop, reason}
        end
      end

      @impl GenServer
      def handle_info(:render, socket) do
        rendered = render(socket.assigns)
        write_to_terminal(socket.terminal, rendered)
        {:noreply, %{socket | changed: %{}}}
      end

      # Handle Phoenix-style events
      def handle_event(event, params) do
        GenServer.call(self(), {:handle_event, event, params})
      end

      @impl GenServer
      def handle_call({:handle_event, event, params}, _from, socket) do
        case handle_event(event, params, socket) do
          {:noreply, new_socket} ->
            send(self(), :render)
            {:reply, :ok, new_socket}

          {:reply, reply, new_socket} ->
            send(self(), :render)
            {:reply, reply, new_socket}
        end
      end

      # Default implementations
      def handle_event(_event, _params, socket) do
        {:noreply, socket}
      end

      defp write_to_terminal(terminal, content) when is_binary(content) do
        Raxol.Terminal.Buffer.write(terminal, content)
      end

      defp write_to_terminal(terminal, {:safe, iodata}) do
        content = IO.iodata_to_binary(iodata)
        Raxol.Terminal.Buffer.write(terminal, content)
      end

      defoverridable mount: 3, handle_event: 3
    end
  end

  @doc """
  Assigns values to the socket, similar to Phoenix LiveView.
  """
  def assign(socket, key, value) when is_atom(key) do
    assign(socket, [{key, value}])
  end

  def assign(socket, assigns) when is_map(assigns) do
    assign(socket, Map.to_list(assigns))
  end

  def assign(socket, assigns) when is_list(assigns) do
    Enum.reduce(assigns, socket, fn {key, value}, acc ->
      %{
        acc
        | assigns: Map.put(acc.assigns, key, value),
          changed: Map.put(acc.changed, key, true)
      }
    end)
  end

  @doc """
  Updates an assign using a function.
  """
  def update(socket, key, fun) when is_atom(key) and is_function(fun, 1) do
    current_value = Map.get(socket.assigns, key)
    new_value = fun.(current_value)
    assign(socket, key, new_value)
  end

  @doc """
  Pushes an event to the terminal (for actions like navigation).
  """
  def push_event(socket, event, payload \\ %{}) do
    # In a real implementation, this would send events to the terminal
    send(self(), {:push_event, event, payload})
    socket
  end
end
