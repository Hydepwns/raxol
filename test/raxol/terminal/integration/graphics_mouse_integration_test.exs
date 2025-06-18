defmodule Raxol.Terminal.Integration.GraphicsMouseIntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.Graphics.UnifiedGraphics
  alias Raxol.Terminal.Mouse.UnifiedMouse

  setup do
    {:ok, _graphics_pid} = UnifiedGraphics.start_link()
    {:ok, _mouse_pid} = UnifiedMouse.start_link()
    :ok
  end

  describe "graphics and mouse integration" do
    test 'creates graphics and mouse contexts' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)

      assert graphics_state.config.width == 800
      assert graphics_state.config.height == 600
      assert mouse_state.config.tracking == :all
    end

    test 'processes mouse events with graphics context' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      # Render some graphics
      data = <<0, 0, 0, 255, 255, 255, 255, 255>>
      assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)

      # Process mouse event
      event = %{
        button: :left,
        action: :press,
        modifiers: [:shift],
        x: 100,
        y: 200
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)

      # Verify states
      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)

      assert graphics_state.buffer == data
      assert mouse_state.position == {100, 200}
      assert mouse_state.button_state == %{left: :pressed}
    end

    test 'updates graphics based on mouse position' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      # Process mouse movement
      event = %{
        button: :none,
        action: :move,
        modifiers: [],
        x: 150,
        y: 250
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)

      # Update graphics at mouse position
      # Red pixel
      data = <<255, 0, 0, 255>>
      assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)

      # Verify states
      assert {:ok, {150, 250}} = UnifiedMouse.get_mouse_position(mouse_id)

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.buffer == data
    end

    test 'handles mouse drag with graphics' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      # Start drag
      start_event = %{
        button: :left,
        action: :press,
        modifiers: [],
        x: 100,
        y: 100
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, start_event)

      # Drag
      drag_event = %{
        button: :left,
        action: :drag,
        modifiers: [],
        x: 200,
        y: 200
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, drag_event)

      # End drag
      end_event = %{
        button: :left,
        action: :release,
        modifiers: [],
        x: 200,
        y: 200
      }

      assert :ok = UnifiedMouse.process_mouse_event(mouse_id, end_event)

      # Verify states
      assert {:ok, mouse_state} = UnifiedMouse.get_mouse_state(mouse_id)
      assert mouse_state.position == {200, 200}
      assert mouse_state.button_state == %{}
    end

    test 'cleans up graphics and mouse contexts' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      assert :ok = UnifiedGraphics.cleanup()
      assert :ok = UnifiedMouse.cleanup()

      assert UnifiedGraphics.get_graphics() == []
      assert UnifiedMouse.get_mice() == []
    end
  end

  describe "error handling" do
    test 'handles invalid graphics and mouse operations' do
      assert {:error, :graphics_not_found} =
               UnifiedGraphics.get_graphics_state(999)

      assert {:error, :mouse_not_found} = UnifiedMouse.get_mouse_state(999)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.render_graphics(999, <<>>)

      assert {:error, :mouse_not_found} =
               UnifiedMouse.process_mouse_event(999, %{})
    end
  end

  describe "performance" do
    test 'handles rapid mouse events efficiently' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      # Generate a sequence of mouse events
      events =
        for i <- 1..1000 do
          %{
            button: :left,
            action: :move,
            modifiers: [],
            x: i,
            y: i
          }
        end

      # Measure processing time
      {time, _} =
        :timer.tc(fn ->
          Enum.each(events, fn event ->
            assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)
          end)
        end)

      # Assert performance requirements (1ms per event)
      assert time < 1_000_000
    end

    test 'handles rapid graphics updates efficiently' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()

      # Generate a sequence of graphics updates
      updates =
        for i <- 1..100 do
          <<i, i, i, 255>>
        end

      # Measure processing time
      {time, _} =
        :timer.tc(fn ->
          Enum.each(updates, fn data ->
            assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)
          end)
        end)

      # Assert performance requirements (10ms per update)
      assert time < 1_000_000
    end

    test 'handles concurrent mouse and graphics operations' do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, mouse_id} = UnifiedMouse.create_mouse()

      # Generate concurrent operations
      mouse_events =
        for i <- 1..500 do
          %{
            button: :left,
            action: :move,
            modifiers: [],
            x: i,
            y: i
          }
        end

      graphics_updates =
        for i <- 1..500 do
          <<i, i, i, 255>>
        end

      # Measure processing time
      {time, _} =
        :timer.tc(fn ->
          Task.async_stream(
            Enum.zip(mouse_events, graphics_updates),
            fn {event, data} ->
              assert :ok = UnifiedMouse.process_mouse_event(mouse_id, event)
              assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)
            end,
            max_concurrency: 4
          )
          |> Stream.run()
        end)

      # Assert performance requirements (20ms per pair of operations)
      assert time < 10_000_000
    end
  end
end
