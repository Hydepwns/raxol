defmodule RaxolWeb.TerminalChannelTest do
  use RaxolWeb.ChannelCase
  alias RaxolWeb.TerminalChannel
  alias Raxol.Terminal.{Emulator, Input, Renderer}

  describe "join/3" do
    test "joins the terminal channel successfully" do
      assert {:ok, _, socket} =
               subscribe_and_join(TerminalChannel, "terminal:test")

      assert socket.assigns.terminal_state.session_id == "test"
      assert %Emulator{} = socket.assigns.terminal_state.emulator
      assert %Input{} = socket.assigns.terminal_state.input
      assert %Renderer{} = socket.assigns.terminal_state.renderer
    end
  end

  describe "handle_in/3" do
    setup do
      {:ok, _, socket} = subscribe_and_join(TerminalChannel, "terminal:test")
      %{socket: socket}
    end

    test "handles text input", %{socket: socket} do
      ref = push(socket, "input", %{"data" => "Hello"})
      assert_reply(ref, :ok)

      assert_push("output", %{
        html: html,
        cursor: %{x: x, y: y, visible: true}
      })

      assert html =~ "Hello"
      assert x == 5
      assert y == 0
    end

    test "handles control characters", %{socket: socket} do
      ref = push(socket, "input", %{"data" => "\r\n"})
      assert_reply(ref, :ok)

      assert_push("output", %{
        html: html,
        cursor: %{x: x, y: y, visible: true}
      })

      assert x == 0
      assert y == 1
    end

    test "handles terminal resize", %{socket: socket} do
      ref = push(socket, "resize", %{"width" => 40, "height" => 12})
      assert_reply(ref, :ok)

      assert_push("output", %{
        html: html,
        cursor: %{x: x, y: y, visible: true}
      })

      assert html =~ ~r/style="width: 560px/
      assert html =~ ~r/height: 201.6px/
    end

    test "handles scrolling", %{socket: socket} do
      ref = push(socket, "scroll", %{"offset" => 10})
      assert_reply(ref, :ok)
      assert_push("output", %{html: html})
      assert html =~ ~r/terminal/
    end

    test "handles theme changes", %{socket: socket} do
      theme = %{
        background: "#111111",
        foreground: "#eeeeee",
        cursor: "#ff0000"
      }

      ref = push(socket, "theme", %{"theme" => theme})
      assert_reply(ref, :ok)
      assert_push("output", %{html: html})
      assert html =~ ~r/background-color: #111111/
      assert html =~ ~r/color: #eeeeee/
      assert html =~ ~r/cursor.*#ff0000/
    end
  end

  describe "terminate/2" do
    test "cleans up on disconnect" do
      {:ok, _, socket} = subscribe_and_join(TerminalChannel, "terminal:test")
      assert :ok = Phoenix.Channel.leave(socket)
    end
  end
end
