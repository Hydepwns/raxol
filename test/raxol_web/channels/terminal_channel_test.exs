defmodule RaxolWeb.TerminalChannelTest do
  use RaxolWeb.ChannelCase
  # Ensure tests run sequentially due to mocking
  use ExUnit.Case, async: false

  alias RaxolWeb.TerminalChannel
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Emulator
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

  # Helper to create emulator structs for testing
  defp create_emulator_struct(width \\ 80, height \\ 24) do
    screen_buffer = %Raxol.Terminal.ScreenBuffer{
      cells:
        List.duplicate(List.duplicate(%{char: " ", style: %{}}, width), height),
      width: width,
      height: height,
      cursor_position: {0, 0},
      cursor_visible: true
    }

    %Emulator{
      main_screen_buffer: screen_buffer,
      alternate_screen_buffer: screen_buffer,
      active_buffer_type: :main,
      width: width,
      height: height,
      cursor: %{
        position: {0, 0},
        style: :block,
        visible: true,
        blink_state: false
      },
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        single_shift: nil
      },
      window_state: %{
        iconified: false,
        maximized: false,
        position: {0, 0},
        size: {width, height},
        size_pixels: {width * 8, height * 16},
        stacking_order: :normal,
        previous_size: {width, height},
        saved_size: {width, height},
        icon_name: ""
      },
      state_stack: [],
      output_buffer: "",
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_limit: 1000,
      scrollback_buffer: [],
      window_title: nil,
      plugin_manager: nil,
      saved_cursor: nil,
      scroll_region: nil,
      sixel_state: nil,
      last_col_exceeded: false
    }
  end

  # Ensure Mox is validated on exit
  setup :verify_on_exit!

  setup do
    # Set up the mock modules for this test
    Application.put_env(:raxol, :terminal_emulator_module, EmulatorMock)
    Application.put_env(:raxol, :terminal_renderer_module, RendererMock)

    # Create a proper screen buffer with cells
    screen_buffer = %Raxol.Terminal.ScreenBuffer{
      cells: List.duplicate(List.duplicate(%{char: " ", style: %{}}, 80), 24),
      width: 80,
      height: 24,
      cursor_position: {0, 0},
      cursor_visible: true
    }

    # Create a proper emulator struct
    emulator_struct = create_emulator_struct()

    # Create a proper renderer struct
    renderer_struct = %Raxol.Terminal.Renderer{
      screen_buffer: screen_buffer,
      cursor: {0, 0},
      theme: %{},
      font_settings: %{}
    }

    # Set up default stubs for the mocks
    Mox.stub(EmulatorMock, :new, fn _width, _height, _opts ->
      emulator_struct
    end)

    Mox.stub(RendererMock, :new, fn _buffer -> renderer_struct end)
    Mox.stub(RendererMock, :render, fn _ -> "<html>test output</html>" end)
    Mox.stub(RendererMock, :set_theme, fn renderer, _theme -> renderer end)

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
        create_emulator_struct()
      end)

      expect(RendererMock, :new, fn _buffer ->
        %Raxol.Terminal.Renderer{
          screen_buffer: _buffer,
          cursor: {0, 0},
          theme: %{},
          font_settings: %{}
        }
      end)

      assert {:ok, _, updated_socket} =
               socket |> subscribe_and_join(TerminalChannel, topic)

      # Verify session ID and user ID
      assert String.replace_prefix(topic, "terminal:", "") ==
               updated_socket.assigns.terminal_state.session_id

      assert updated_socket.assigns.terminal_state.user_id ==
               socket.assigns.user_id
    end

    test "rejects invalid session topics" do
      # Expect new/3 to be called even for invalid topics
      expect(EmulatorMock, :new, fn _width, _height, _opts ->
        create_emulator_struct()
      end)

      expect(RendererMock, :new, fn _buffer ->
        %Raxol.Terminal.Renderer{
          screen_buffer: _buffer,
          cursor: {0, 0},
          theme: %{},
          font_settings: %{}
        }
      end)

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
        {create_emulator_struct(), "output_from_hello"}
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
        {create_emulator_struct(), "output_from_ctrl_c"}
      end)
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

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
      |> expect(:resize, fn _, 100, 30 ->
        create_emulator_struct(100, 30)
      end)
      |> expect(:get_cursor_position, fn _ -> {0, 0} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

      flush_mailbox()

      {:reply, :ok, _socket_after_resize} =
        TerminalChannel.handle_in(
          "resize",
          %{"width" => 100, "height" => 30},
          socket
        )

      assert_receive %Phoenix.Socket.Message{
                       event: "resize",
                       payload: %{
                         width: 100,
                         height: 30,
                         cursor: %{x: 0, y: 0, visible: true}
                       }
                     },
                     500
    end

    test "handles theme changes", %{socket: socket} do
      EmulatorMock
      |> expect(:get_cursor_position, fn _ -> {10, 5} end)
      |> expect(:get_cursor_visible, fn _ -> true end)

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
end
