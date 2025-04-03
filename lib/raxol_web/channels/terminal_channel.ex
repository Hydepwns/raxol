defmodule RaxolWeb.TerminalChannel do
  use RaxolWeb, :channel
  alias Raxol.{Terminal, Auth, Session}
  alias Terminal.{Emulator, ANSI, Input}

  @impl true
  def join("terminal:" <> session_id, %{"token" => token}, socket) do
    case Auth.validate_token(session_id, token) do
      {:ok, user_id} ->
        case Session.get_session(session_id) do
          {:ok, session} ->
            {:ok, assign(socket, 
              session_id: session_id,
              user_id: user_id,
              emulator: session.emulator
            )}
          {:error, _} ->
            {:error, %{reason: "session_not_found"}}
        end
      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("input", %{"event" => event}, socket) do
    case Input.validate_event(event) do
      {:ok, event} ->
        # Process input event and send response
        response = process_terminal_input(socket.assigns.emulator, event)
        broadcast_terminal_output(socket, response)
        {:noreply, socket}
      
      {:error, _} ->
        {:reply, {:error, %{reason: "invalid_event"}}, socket}
    end
  end

  @impl true
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    emulator = socket.assigns.emulator
    emulator = %{emulator | width: width, height: height}
    
    {:noreply, assign(socket, emulator: emulator)}
  end

  @impl true
  def terminate(reason, socket) do
    # Clean up session on disconnect
    Auth.cleanup_user_session(socket.assigns.session_id)
    :ok
  end

  # Private functions

  defp process_terminal_input(emulator, event) do
    case event do
      {:key, key, _} ->
        process_key_input(emulator, key)
      
      {:mouse, x, y, button, _} ->
        process_mouse_input(emulator, x, y, button)
    end
  end

  defp process_key_input(emulator, key) do
    case key do
      :up -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x, emulator.cursor_y - 1])
      :down -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x, emulator.cursor_y + 1])
      :left -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x - 1, emulator.cursor_y])
      :right -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x + 1, emulator.cursor_y])
      :enter -> "\r\n"
      :backspace -> "\b \b"
      :delete -> ANSI.generate_sequence(:delete_char, [])
      :home -> ANSI.generate_sequence(:cursor_move, [0, emulator.cursor_y])
      :end -> ANSI.generate_sequence(:cursor_move, [emulator.width - 1, emulator.cursor_y])
      :page_up -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x, 0])
      :page_down -> ANSI.generate_sequence(:cursor_move, [emulator.cursor_x, emulator.height - 1])
      char when is_atom(char) -> Atom.to_string(char)
      _ -> ""
    end
  end

  defp process_mouse_input(emulator, x, y, button) do
    case button do
      :left -> ANSI.generate_sequence(:cursor_move, [x, y])
      :right -> ""
      :middle -> ""
      :release -> ""
    end
  end

  defp broadcast_terminal_output(socket, output) do
    broadcast!(socket, "output", %{output: output})
  end
end 