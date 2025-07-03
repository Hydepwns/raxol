defmodule RaxolWeb.TerminalChannelTest do
  use RaxolWeb.ChannelCase
  use Raxol.DataCase
  # Ensure tests run sequentially due to mocking
  use ExUnit.Case, async: false

  alias RaxolWeb.TerminalChannel
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Core.Events.Event
  alias Raxol.Terminal.EmulatorBehaviour
  alias RaxolWeb.UserSocket
  alias Raxol.Terminal.Renderer

  # Remove the local dummy behaviour

  # Define the mock module based on the REAL behaviour
  Mox.defmock(EmulatorMock, for: Raxol.Terminal.EmulatorBehaviour)

  # Add RendererMock for the Renderer behaviour
  Mox.defmock(RendererMock, for: Raxol.Terminal.RendererBehaviour)

  # Import Mox for function mocking
  import Mox
  # import Raxol.TestHelpers
  import Raxol.Test.TestHelper

  # Helper to flush and print all messages in the mailbox
  defp flush_mailbox do
    receive do
      msg ->
        flush_mailbox()
    after
      100 -> :ok
    end
  end

  # Ensure Mox is validated on exit
  setup :verify_on_exit!

  setup do
    # Generate a unique topic for each test
    topic = "terminal:" <> Ecto.UUID.generate()

    # Create and join socket
    {:ok, _, socket} =
      UserSocket
      |> socket("user_socket:test", %{user_id: 1})
      |> subscribe_and_join(TerminalChannel, topic)

    # Return test context
    {:ok, socket: socket, topic: topic}
  end

  describe "join/3" do
    test "joins the terminal channel successfully", %{
      socket: socket,
      topic: topic
    } do
      # Set up mock expectations
      expect(EmulatorMock, :new, fn _width, _height, _opts ->
        {:ok, %EmulatorStruct{}}
      end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      assert {:ok, _, updated_socket} =
               socket |> subscribe_and_join(TerminalChannel, topic)

      # Verify session ID and user ID
      assert String.replace_prefix(topic, "terminal:", "") ==
               updated_socket.assigns.terminal_state.session_id

      assert updated_socket.assigns.terminal_state.user_id ==
               socket.assigns.user_id
    end

    test "rejects invalid session topics" do
      # Expect new/4 to be called even for invalid topics
      expect(EmulatorMock, :new, fn _width, _height, _opts ->
        {:ok, %EmulatorStruct{}}
      end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      socket = socket(UserSocket, "user_socket:fail", %{user_id: 2})

      assert {:error, %{reason: "unauthorized"}} =
               socket
               |> subscribe_and_join(
                 TerminalChannel,
                 "terminal:invalid-topic-format"
               )
    end

    # Add more tests for join/3 edge cases if needed
  end

  describe "handle_in/3" do
    setup %{socket: socket} do
      topic = "terminal:" <> Ecto.UUID.generate()
      {:ok, _reply, socket_assigned} = subscribe_and_join(socket, topic, %{})
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

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      flush_mailbox()

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
                     500

      assert is_binary(html_content)
    end

    test "handles control characters", %{socket: socket} do
      EmulatorMock
      |> expect(:process_input, fn _, "\x03" ->
        {Emulator.new(), "output_from_ctrl_c"}
      end)
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      flush_mailbox()

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
      EmulatorMock
      |> expect(:resize, fn _, 100, 30 -> Emulator.new(100, 30) end)
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      flush_mailbox()

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
      EmulatorMock
      |> expect(:get_cursor_position, fn _ -> {10, 5} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      flush_mailbox()

      {:reply, :ok, _socket_after_theme} =
        TerminalChannel.handle_in(
          "theme",
          %{"theme" => %{"name" => "dark"}},
          socket
        )

      assert_receive %Phoenix.Socket.Message{
                       event: "output",
                       payload: %{html: html_content}
                     },
                     500

      assert is_binary(html_content)
    end

    test "handles scroll events", %{socket: socket} do
      EmulatorMock
      |> expect(:get_cursor_position, fn _ -> {0, 23} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      expect(RendererMock, :render, fn _ -> "<html>test output</html>" end)

      flush_mailbox()

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
      topic = "terminal:" <> Ecto.UUID.generate()
      {:ok, _reply, socket_assigned} = subscribe_and_join(socket, topic, %{})
      {:ok, socket: socket_assigned}
    end

    test "cleans up on disconnect", %{socket: socket} do
      # Simulate channel termination
      :ok = TerminalChannel.terminate(:shutdown, socket)
      # Add any cleanup assertions here if needed
    end
  end

  setup_all do
    Application.put_env(:raxol, :terminal_emulator_module, EmulatorMock)
    Application.put_env(:raxol, :terminal_renderer_module, RendererMock)
    Mox.stub(RendererMock, :new, fn _ -> %{} end)
    Mox.stub(RendererMock, :render, fn _ -> "<html>test output</html>" end)
    Mox.stub(RendererMock, :set_theme, fn renderer, _theme -> renderer end)
    on_exit(fn ->
      Application.delete_env(:raxol, :terminal_emulator_module)
      Application.delete_env(:raxol, :terminal_renderer_module)
    end)
    :ok
  end
end
