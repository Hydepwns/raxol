defmodule RaxolWeb.DemoTerminalChannel do
  @moduledoc """
  Phoenix Channel for demo terminal sessions.
  Handles input/output with security limits and command whitelisting.
  """

  use Phoenix.Channel
  require Logger

  alias Raxol.Demo.{CommandWhitelist, DemoHandler, SessionManager}

  @max_input_size 1024

  @impl true
  def join("demo:terminal:" <> session_id, _params, socket) do
    ip_address = get_ip_address(socket)

    case SessionManager.create_session(ip_address) do
      {:ok, ^session_id} ->
        send(self(), :send_welcome)

        socket =
          socket
          |> assign(:session_id, session_id)
          |> assign(:ip_address, ip_address)
          |> assign(:input_buffer, "")

        {:ok, socket}

      {:ok, different_id} ->
        SessionManager.remove_session(different_id)
        {:error, %{reason: "session_id_mismatch"}}

      {:error, :max_sessions_reached} ->
        Logger.warning(
          "Demo max sessions reached, rejecting from #{ip_address}"
        )

        {:error, %{reason: "server_busy"}}

      {:error, :max_sessions_per_ip_reached} ->
        Logger.warning("Demo max sessions per IP reached for #{ip_address}")
        {:error, %{reason: "too_many_sessions"}}
    end
  end

  @impl true
  def handle_info(:send_welcome, socket) do
    welcome = DemoHandler.welcome_message()
    push(socket, "output", %{data: welcome <> prompt()})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:animation_output, data}, socket) do
    push(socket, "output", %{data: data})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:animation_complete, socket) do
    push(socket, "output", %{data: prompt()})
    {:noreply, socket}
  end

  @impl true
  def handle_in("input", %{"data" => data}, socket)
      when byte_size(data) > @max_input_size do
    push(socket, "output", %{
      data: "\r\n\e[31mInput too large\e[0m\r\n" <> prompt()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("input", %{"data" => data}, socket) do
    SessionManager.touch_session(socket.assigns.session_id)

    result = process_input(data, socket.assigns.input_buffer)

    {output, new_buffer, should_close, animation} =
      case result do
        {o, b, c} -> {o, b, c, nil}
        {o, b, c, a} -> {o, b, c, a}
      end

    if output != "" do
      push(socket, "output", %{data: output})
    end

    # Handle animation if requested
    if animation do
      {:run_animation, fun} = animation
      channel_pid = self()

      spawn(fn ->
        # Create a custom IO device that sends to the channel
        run_web_animation(fun, channel_pid)
      end)
    end

    if should_close do
      {:stop, :normal, socket}
    else
      {:noreply, assign(socket, :input_buffer, new_buffer)}
    end
  end

  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if session_id = socket.assigns[:session_id] do
      SessionManager.remove_session(session_id)
    end

    :ok
  end

  defp process_input(data, buffer) do
    Enum.reduce(String.graphemes(data), {"", buffer, false}, fn char,
                                                                {output, buf,
                                                                 close} ->
      if close do
        {output, buf, close}
      else
        process_char(char, output, buf)
      end
    end)
  end

  defp process_char("\r", output, buffer) do
    execute_command(buffer, output)
  end

  defp process_char("\n", output, buffer) do
    execute_command(buffer, output)
  end

  # Handle backspace (DEL character, ASCII 127) and Ctrl+H (ASCII 8)
  defp process_char(<<127>>, output, buffer) do
    handle_backspace(output, buffer)
  end

  defp process_char(<<8>>, output, buffer) do
    handle_backspace(output, buffer)
  end

  defp process_char("\e", output, buffer) do
    {output, buffer, false}
  end

  defp process_char(char, output, buffer) do
    if String.printable?(char) and byte_size(buffer) < @max_input_size do
      {output <> char, buffer <> char, false}
    else
      {output, buffer, false}
    end
  end

  defp handle_backspace(output, "") do
    {output, "", false}
  end

  defp handle_backspace(output, buffer) do
    {output <> "\b \b", String.slice(buffer, 0..-2//1), false}
  end

  defp execute_command(command, output) do
    result = CommandWhitelist.execute(command)

    case result do
      {:ok, cmd_output} ->
        {output <> "\r\n" <> cmd_output <> prompt(), "", false}

      {:error, message} ->
        {output <> "\r\n\e[31m#{message}\e[0m\r\n" <> prompt(), "", false}

      {:animate, fun} ->
        # Return immediately and handle animation via spawned process
        {output <> "\r\n", "", false, {:run_animation, fun}}

      {:exit, message} ->
        {output <> "\r\n" <> message, "", true}
    end
  end

  defp prompt do
    "\e[32mraxol>\e[0m "
  end

  defp run_web_animation(fun, channel_pid) do
    # Run animation with {:web, pid} target - output goes via messages
    fun.({:web, channel_pid})
    send(channel_pid, :animation_complete)
  end

  defp get_ip_address(socket) do
    case socket.assigns[:peer_data] do
      %{address: address} -> format_ip(address)
      _ -> "unknown"
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ip({a, b, c, d, e, f, g, h}),
    do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"

  defp format_ip(other), do: inspect(other)
end
