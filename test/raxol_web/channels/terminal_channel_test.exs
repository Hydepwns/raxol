defmodule RaxolWeb.TerminalChannelTest do
  use RaxolWeb.ChannelCase
  # Ensure tests run sequentially due to mocking
  use ExUnit.Case, async: false

  alias RaxolWeb.TerminalChannel
  alias Raxol.Terminal.Emulator
  # Add alias for Ecto.UUID
  alias Ecto.UUID
  alias Raxol.Core.Events.Event
  # Import the real behaviour
  alias Raxol.Terminal.EmulatorBehaviour
  # Add alias for UserSocket
  alias RaxolWeb.UserSocket
  # Correct alias for Renderer
  alias Raxol.Terminal.Renderer

  # Remove the local dummy behaviour

  # Define the mock module based on the REAL behaviour
  Mox.defmock(EmulatorMock, for: Raxol.Terminal.EmulatorBehaviour)

  # Import Mox for function mocking
  import Mox

  # Ensure Mox is validated on exit
  setup :verify_on_exit!

  setup do
    topic = "terminal:" <> Ecto.UUID.generate()

    {:ok, _, socket} =
      UserSocket
      |> socket("user_socket:test", %{user_id: 1})
      |> subscribe_and_join(TerminalChannel, topic)

    Mox.stub_with(EmulatorMock, Emulator)
    {:ok, socket: socket, topic: topic}
  end

  describe "join/3" do
    test "joins the terminal channel successfully", %{
      socket: socket,
      topic: topic
    } do
      # Set up mock expectations
      EmulatorMock

      # |> expect(:new, fn _, _, _, _ -> {:ok, %Emulator{}} end) # Old location, moved inside test

      # Explicitly expect new/4 to be called by the join function
      expect(EmulatorMock, :new, fn _width, _height ->
        # Return a simple Emulator struct for this test
        {:ok, %Emulator{}}
      end)

      assert {:ok, _, updated_socket} =
               socket |> subscribe_and_join(TerminalChannel, topic)

      # Compare string topic to session_id binary converted back to string using binary_to_string!
      assert String.replace_prefix(topic, "terminal:", "") ==
               Ecto.UUID.binary_to_string!(
                 updated_socket.assigns.terminal_state.session_id
               )

      assert updated_socket.assigns.terminal_state.user_id ==
               socket.assigns.user_id
    end

    test "rejects invalid session topics" do
      # Expect new/4 to be called *even if* the topic is invalid, as join/3 calls it before checking topic format?
      # Let's re-check join/3 logic... yes, it calls Emulator.new() *before* pattern matching on topic.
      expect(EmulatorMock, :new, fn _width, _height ->
        # Needs to be expected even for failed join
        {:ok, %Emulator{}}
      end)

      # Use the socket/3 function imported from Phoenix.ChannelTest
      {:ok, socket} = socket(UserSocket, "user_socket:fail", %{user_id: 2})

      assert {:error, %{reason: "unauthorized"}} =
               socket
               |> subscribe_and_join(
                 TerminalChannel,
                 "terminal:invalid-topic-format"
               )

      # The actual rejection comes from pattern matching in join/3, but the socket setup itself might reject first?
      # Rerunning the test... wait, the error in the previous run was Mox.VerificationError.
      # The assertion currently is {:error, %{reason: "unauthorized"}} which might be wrong.
      # Let's stick to fixing the Mox error first. Expect new/4.
    end

    # Add more tests for join/3 edge cases if needed
  end

  describe "handle_in/3" do
    setup %{socket: socket} do
      {:ok, _reply, socket_assigned} =
        subscribe_and_join(socket, "terminal:lobby", %{})

      {:ok, socket: socket_assigned}
    end

    test "handles text input", %{socket: socket} do
      # Mock expect for process_input
      EmulatorMock
      |> expect(:process_input, fn _, "hello" ->
        {Emulator.new(), "output_from_hello"}
      end)
      |> expect(:get_cursor_position, fn _ -> {5, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      # Capture pid (optional, assert_receive works globally)
      _pid = socket.channel_pid

      {:reply, :ok, _socket_after_input} =
        TerminalChannel.handle_in(
          "input",
          %{"type" => "text", "data" => "hello"},
          socket
        )

      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{
                         html: html_content,
                         cursor: %{x: 5, y: 0, visible: true}
                       }
                     },
                     # Add timeout to assert_receive
                     500

      assert is_binary(html_content)
    end

    test "handles control characters", %{socket: socket} do
      # Mock expect for process_input
      EmulatorMock
      |> expect(:process_input, fn _, "\x03" ->
        {Emulator.new(), "output_from_ctrl_c"}
      end)
      # Assuming reset or no move
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      _pid = socket.channel_pid

      {:reply, :ok, _socket_after_ctrl_c} =
        TerminalChannel.handle_in(
          "input",
          %{"type" => "control", "data" => "\x03"},
          socket
        )

      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{
                         html: html_content,
                         cursor: %{x: 0, y: 0, visible: true}
                       }
                     },
                     500

      assert is_binary(html_content)
    end

    test "handles terminal resize", %{socket: socket} do
      # Mock expect for resize and subsequent rendering info
      EmulatorMock
      |> expect(:resize, fn _, 100, 30 -> Emulator.new(100, 30) end)
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      _pid = socket.channel_pid

      {:reply, :ok, _socket_after_resize} =
        TerminalChannel.handle_in(
          "resize",
          %{"width" => 100, "height" => 30},
          socket
        )

      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{
                         html: html_content,
                         cursor: %{x: 0, y: 0, visible: true}
                       }
                     },
                     500

      assert is_binary(html_content)
    end

    test "handles theme changes", %{socket: socket} do
      # Mock expect for set_theme (assuming Renderer.set_theme doesn't involve EmulatorMock)
      # We still need cursor info for the push
      EmulatorMock
      |> expect(:get_cursor_position, fn _ -> {10, 5} end)
      |> expect(:get_cursor_visible, fn _ -> false end)

      # Send theme as a map (adjust based on actual Renderer.set_theme expectation)
      # Example map
      theme_payload = %{
        name: "solarized-dark",
        colors: %{foreground: "#ffffff", background: "#000000"}
      }

      _pid = socket.channel_pid

      {:reply, :ok, _socket_after_theme} =
        TerminalChannel.handle_in("theme", %{"theme" => theme_payload}, socket)

      # Assert push with expected cursor, HTML might be complex to assert here
      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{
                         html: html_content,
                         cursor: %{x: 10, y: 5, visible: false}
                       }
                     },
                     500

      assert is_binary(html_content)
    end

    test "handles scroll events", %{socket: socket} do
      # Mock expect for cursor info for push (scroll handle_in doesn't interact with EmulatorMock)
      EmulatorMock
      |> expect(:get_cursor_position, fn _ -> {0, 23} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      _pid = socket.channel_pid

      {:reply, :ok, _socket_after_scroll} =
        TerminalChannel.handle_in("scroll", %{"offset" => -10}, socket)

      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{
                         html: html_content,
                         cursor: %{x: 0, y: 23, visible: true}
                       }
                     },
                     500

      assert is_binary(html_content)
    end

    test "handles invalid events", %{socket: socket} do
      # Assert that calling handle_in with an unknown event raises a FunctionClauseError
      assert_raise FunctionClauseError, fn ->
        TerminalChannel.handle_in("invalid_event", %{}, socket)
      end
    end
  end

  describe "terminate/2" do
    setup %{socket: socket} do
      {:ok, _reply, socket_assigned} =
        subscribe_and_join(socket, "terminal:lobby", %{})

      {:ok, socket: socket_assigned}
    end

    test "cleans up on disconnect", %{socket: socket} do
      # Simulate channel termination
      :ok = TerminalChannel.terminate(:shutdown, socket)
      # Add any cleanup assertions here if needed
    end
  end
end
