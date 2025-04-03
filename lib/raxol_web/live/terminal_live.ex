defmodule RaxolWeb.TerminalLive do
  use RaxolWeb, :live_view
  alias Raxol.Terminal.{Emulator, ANSI, Input}

  @impl true
  def mount(_params, _session, socket) do
    emulator = Emulator.new(80, 24)
    
    if connected?(socket) do
      {:ok, _} = RaxolWeb.Endpoint.subscribe("terminal:default")
      {:ok, assign(socket, 
        emulator: emulator,
        input_buffer: "",
        output_buffer: "",
        connected: true
      )}
    else
      {:ok, assign(socket, 
        emulator: emulator,
        input_buffer: "",
        output_buffer: "",
        connected: false
      )}
    end
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    case process_key(key) do
      {:ok, event} ->
        handle_terminal_event(socket, event)
      :ignore ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("input", %{"value" => value}, socket) do
    {:noreply, assign(socket, input_buffer: value)}
  end

  @impl true
  def handle_event("minimize", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("maximize", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "output", payload: %{output: output}}, socket) do
    emulator = socket.assigns.emulator
    emulator = process_terminal_output(emulator, output)
    
    {:noreply, assign(socket, 
      emulator: emulator,
      output_buffer: Emulator.to_string(emulator)
    )}
  end

  # Private functions

  defp process_key(key) do
    case key do
      "ArrowUp" -> {:ok, {:key, :up, []}}
      "ArrowDown" -> {:ok, {:key, :down, []}}
      "ArrowLeft" -> {:ok, {:key, :left, []}}
      "ArrowRight" -> {:ok, {:key, :right, []}}
      "Enter" -> {:ok, {:key, :enter, []}}
      "Backspace" -> {:ok, {:key, :backspace, []}}
      "Delete" -> {:ok, {:key, :delete, []}}
      "Home" -> {:ok, {:key, :home, []}}
      "End" -> {:ok, {:key, :end, []}}
      "PageUp" -> {:ok, {:key, :page_up, []}}
      "PageDown" -> {:ok, {:key, :page_down, []}}
      "F1" -> {:ok, {:key, :f1, []}}
      "F2" -> {:ok, {:key, :f2, []}}
      "F3" -> {:ok, {:key, :f3, []}}
      "F4" -> {:ok, {:key, :f4, []}}
      char when byte_size(char) == 1 -> {:ok, {:key, String.to_atom(char), []}}
      _ -> :ignore
    end
  end

  defp handle_terminal_event(socket, event) do
    if socket.assigns.connected do
      send_terminal_input(socket, event)
    end
    
    {:noreply, socket}
  end

  defp process_terminal_output(emulator, output) do
    output
    |> String.graphemes()
    |> Enum.reduce(emulator, fn char, acc ->
      if String.starts_with?(char, "\e") do
        ANSI.process_escape(acc, char)
      else
        Emulator.write(acc, char)
      end
    end)
  end

  defp send_terminal_input(socket, event) do
    RaxolWeb.Endpoint.broadcast("terminal:default", "input", %{event: event})
  end
end 