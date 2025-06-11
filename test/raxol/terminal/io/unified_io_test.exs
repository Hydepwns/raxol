defmodule Raxol.Terminal.IO.UnifiedIOTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.IO.UnifiedIO

  setup do
    # Start the UnifiedIO process
    {:ok, pid} = UnifiedIO.start_link()
    %{pid: pid}
  end

  describe "initialization" do
    test "initializes with default values", %{pid: pid} do
      assert :ok = UnifiedIO.init_terminal(80, 24, %{
        scrollback_limit: 1000,
        memory_limit: 50 * 1024 * 1024,
        command_history_limit: 1000,
        rendering: %{
          fps: 60,
          theme: %{
            foreground: :white,
            background: :black
          },
          font_settings: %{
            size: 12
          }
        }
      })
    end

    test "initializes with custom config", %{pid: pid} do
      custom_config = %{
        scrollback_limit: 2000,
        memory_limit: 100 * 1024 * 1024,
        command_history_limit: 2000,
        rendering: %{
          fps: 30,
          theme: %{
            foreground: :green,
            background: :black
          },
          font_settings: %{
            size: 14
          }
        }
      }

      assert :ok = UnifiedIO.init_terminal(100, 40, custom_config)
    end
  end

  describe "input processing" do
    test "processes keyboard input", %{pid: pid} do
      assert {:ok, []} = UnifiedIO.process_input(%{type: :key, key: "a"})
    end

    test "processes special keys", %{pid: pid} do
      assert {:ok, []} = UnifiedIO.process_input(%{type: :special_key, key: :up})
      assert {:ok, []} = UnifiedIO.process_input(%{type: :special_key, key: :down})
      assert {:ok, []} = UnifiedIO.process_input(%{type: :special_key, key: :enter})
    end

    test "processes mouse events", %{pid: pid} do
      mouse_event = %{
        type: :mouse,
        event_type: :press,
        button: 1,
        x: 10,
        y: 20
      }

      assert {:ok, []} = UnifiedIO.process_input(mouse_event)
    end

    test "handles invalid input events", %{pid: pid} do
      assert {:error, "Invalid event type: :invalid"} =
        UnifiedIO.process_input(%{type: :invalid})
    end
  end

  describe "output processing" do
    test "processes output data", %{pid: pid} do
      assert {:ok, []} = UnifiedIO.process_output("Hello, World!\n")
    end

    test "processes multiline output", %{pid: pid} do
      multiline = "Line 1\nLine 2\nLine 3\n"
      assert {:ok, []} = UnifiedIO.process_output(multiline)
    end

    test "handles empty output", %{pid: pid} do
      assert {:ok, []} = UnifiedIO.process_output("")
    end
  end

  describe "configuration" do
    test "updates configuration", %{pid: pid} do
      new_config = %{
        scrollback_limit: 2000,
        memory_limit: 100 * 1024 * 1024,
        command_history_limit: 2000,
        rendering: %{
          fps: 30,
          theme: %{
            foreground: :green,
            background: :black
          },
          font_settings: %{
            size: 14
          }
        }
      }

      assert :ok = UnifiedIO.update_config(new_config)
    end

    test "sets individual config values", %{pid: pid} do
      assert :ok = UnifiedIO.set_config_value([:rendering, :fps], 30)
      assert :ok = UnifiedIO.set_config_value([:scrollback_limit], 2000)
    end

    test "resets configuration to defaults", %{pid: pid} do
      assert :ok = UnifiedIO.reset_config()
    end
  end

  describe "terminal operations" do
    test "resizes terminal", %{pid: pid} do
      assert :ok = UnifiedIO.resize(100, 40)
    end

    test "sets cursor visibility", %{pid: pid} do
      assert :ok = UnifiedIO.set_cursor_visibility(true)
      assert :ok = UnifiedIO.set_cursor_visibility(false)
    end
  end

  describe "performance" do
    test "handles rapid input events efficiently", %{pid: pid} do
      # Generate a sequence of input events
      events = for i <- 1..1000 do
        %{type: :key, key: "a#{i}"}
      end

      # Measure processing time
      {time, _} = :timer.tc(fn ->
        Enum.each(events, fn event ->
          {:ok, _} = UnifiedIO.process_input(event)
        end)
      end)

      # Assert performance requirements (1ms per event)
      assert time < 1_000_000
    end

    test "handles large output efficiently", %{pid: pid} do
      # Generate large output
      large_output = String.duplicate("Hello, World!\n", 1000)

      # Measure processing time
      {time, _} = :timer.tc(fn ->
        {:ok, _} = UnifiedIO.process_output(large_output)
      end)

      # Assert performance requirements (10ms for 1000 lines)
      assert time < 10_000_000
    end
  end
end
