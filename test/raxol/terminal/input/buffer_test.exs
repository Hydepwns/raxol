defmodule Raxol.Terminal.Input.BufferTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Input.{Buffer, Event, Event.MouseEvent, Event.KeyEvent}

  setup do
    {:ok, pid} = Buffer.start_link()
    %{pid: pid}
  end

  describe "input buffering" do
    test "processes complete sequences immediately", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "a")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%KeyEvent{key: "a", modifiers: []}] = events
    end

    test "buffers partial sequences", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      # Feed partial escape sequence
      Buffer.feed_input(pid, "\e[")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert events == []

      # Complete the sequence
      Buffer.feed_input(pid, "0;0;10;20M")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%MouseEvent{button: :left, action: :press, x: 10, y: 20}] = events
    end

    test "handles multiple sequences in one input", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "a\e[0;0;10;20Mb")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [
        %KeyEvent{key: "b", modifiers: []},
        %MouseEvent{button: :left, action: :press, x: 10, y: 20},
        %KeyEvent{key: "a", modifiers: []}
      ] = events
    end
  end

  describe "callback handling" do
    test "calls callback for each complete event", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "abc")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [
        %KeyEvent{key: "c", modifiers: []},
        %KeyEvent{key: "b", modifiers: []},
        %KeyEvent{key: "a", modifiers: []}
      ] = events
    end

    test "handles callback errors gracefully", %{pid: pid} do
      Buffer.register_callback(pid, fn _event -> raise "test error" end)

      # Should not crash
      Buffer.feed_input(pid, "a")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
    end
  end

  describe "buffer management" do
    test "clears buffer", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      # Feed partial sequence
      Buffer.feed_input(pid, "\e[")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert events == []

      # Clear buffer
      Buffer.clear_buffer(pid)

      # Feed complete sequence
      Buffer.feed_input(pid, "0;0;10;20M")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%MouseEvent{button: :left, action: :press, x: 10, y: 20}] = events
    end

    test "handles timeout for partial sequences", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      # Feed partial sequence
      Buffer.feed_input(pid, "\e[")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert events == []

      # Wait for timeout
      Process.sleep(150)

      # Feed more data
      Buffer.feed_input(pid, "0;0;10;20M")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%MouseEvent{button: :left, action: :press, x: 10, y: 20}] = events
    end
  end

  describe "sequence detection" do
    test "detects mouse sequences", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "\e[0;0;10;20M")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%MouseEvent{button: :left, action: :press, x: 10, y: 20}] = events
    end

    test "detects key sequences", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "\e[2;5A")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert [%KeyEvent{key: "A", modifiers: [:shift, :ctrl]}] = events
    end

    test "handles invalid sequences", %{pid: pid} do
      events = []
      Buffer.register_callback(pid, fn event -> events = [event | events] end)

      Buffer.feed_input(pid, "\e[invalid")
      assert_receive {:DOWN, _, :process, ^pid, :normal}
      assert events == []
    end
  end
end
