defmodule RaxolWeb.DemoTerminalChannelTest do
  use ExUnit.Case, async: false

  # These tests require the Phoenix endpoint to be running.
  # NOT tagged :integration because ExUnit's --only (include) overrides --exclude,
  # so --only integration --exclude skip_on_ci would still run these and fail.
  # Run locally with: mix test test/raxol_web/channels/demo_terminal_channel_test.exs
  @moduletag :skip_on_ci
  @moduletag :endpoint

  import Phoenix.ChannelTest

  alias Raxol.Demo.SessionManager

  @endpoint RaxolWeb.Endpoint

  setup do
    start_supervised!(SessionManager)

    {:ok, socket} =
      Phoenix.ChannelTest.connect(RaxolWeb.UserSocket, %{},
        connect_info: %{peer_data: %{address: {127, 0, 0, 1}}}
      )

    {:ok, socket: socket}
  end

  describe "join/3" do
    test "successfully joins with valid session", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, _socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})
    end

    test "receives welcome message after join", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, _socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", %{data: data})
      assert data =~ "Raxol" or data =~ "RAXOL"
    end

    test "rejects when max sessions per IP reached", %{socket: socket} do
      for i <- 1..10 do
        session_id = generate_session_id()

        {:ok, _, _} =
          subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

        leave(socket)

        {:ok, socket} =
          Phoenix.ChannelTest.connect(RaxolWeb.UserSocket, %{},
            connect_info: %{peer_data: %{address: {127, 0, 0, i + 1}}}
          )
      end

      session_id = generate_session_id()

      {:error, %{reason: reason}} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert reason in ["too_many_sessions", "session_id_mismatch"]
    end
  end

  describe "handle_in input" do
    test "echoes typed characters", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      push(socket, "input", %{"data" => "h"})
      assert_push("output", %{data: "h"})
    end

    test "executes command on enter", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      push(socket, "input", %{"data" => "help\r"})
      assert_push("output", %{data: output})
      assert output =~ "help" or output =~ "Available"
    end

    test "handles backspace", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      push(socket, "input", %{"data" => "ab\x7f"})
      assert_push("output", %{data: data})
      assert data == "ab\b \b"
    end

    test "rejects oversized input", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      large_input = String.duplicate("a", 1025)
      push(socket, "input", %{"data" => large_input})

      assert_push("output", %{data: output})
      assert output =~ "Input too large"
    end

    test "unknown commands return error", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      push(socket, "input", %{"data" => "unknowncommand\r"})
      assert_push("output", %{data: output})
      assert output =~ "Unknown command"
    end

    test "shell injection attempts are rejected", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      injections = [
        "; cat /etc/passwd",
        "$(whoami)",
        "`id`",
        "| ls -la",
        "& rm -rf /"
      ]

      for injection <- injections do
        push(socket, "input", %{"data" => "#{injection}\r"})
        assert_push("output", %{data: output})

        assert output =~ "Unknown command" or output =~ "error",
               "Injection should be rejected: #{injection}"
      end
    end
  end

  describe "exit command" do
    test "closes channel on exit", %{socket: socket} do
      session_id = generate_session_id()

      {:ok, _, socket} =
        subscribe_and_join(socket, "demo:terminal:#{session_id}", %{})

      assert_push("output", _welcome)

      push(socket, "input", %{"data" => "exit\r"})
      assert_push("output", %{data: output})
      assert output =~ "Goodbye"
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
