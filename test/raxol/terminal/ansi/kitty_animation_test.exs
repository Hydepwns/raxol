defmodule Raxol.Terminal.ANSI.KittyAnimationTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.KittyAnimation

  describe "create_animation/1" do
    test "creates animation with valid dimensions" do
      {:ok, anim} = KittyAnimation.create_animation(%{
        width: 100,
        height: 100
      })

      assert anim.width == 100
      assert anim.height == 100
      assert anim.format == :rgba
      assert anim.frame_rate == 30
      assert anim.loop_mode == :infinite
      assert anim.frames == []
      assert anim.current_frame == 0
      assert anim.state == :stopped
      assert is_integer(anim.image_id)
    end

    test "accepts custom options" do
      {:ok, anim} = KittyAnimation.create_animation(%{
        width: 50,
        height: 50,
        format: :rgb,
        frame_rate: 60,
        loop_mode: :once,
        image_id: 42
      })

      assert anim.format == :rgb
      assert anim.frame_rate == 60
      assert anim.loop_mode == :once
      assert anim.image_id == 42
    end

    test "returns error for invalid dimensions" do
      assert {:error, :invalid_dimensions} = KittyAnimation.create_animation(%{width: 0, height: 100})
      assert {:error, :invalid_dimensions} = KittyAnimation.create_animation(%{width: 100, height: 0})
      assert {:error, :invalid_dimensions} = KittyAnimation.create_animation(%{})
    end
  end

  describe "add_frame/3" do
    test "adds frame with default duration" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, frame_rate: 30})

      anim = KittyAnimation.add_frame(anim, "frame_data")

      assert length(anim.frames) == 1

      frame = hd(anim.frames)
      assert frame.data == "frame_data"
      assert frame.duration_ms == 33  # 1000 / 30
      assert frame.index == 0
    end

    test "adds frame with custom duration" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = KittyAnimation.add_frame(anim, "frame_data", duration_ms: 100)

      frame = hd(anim.frames)
      assert frame.duration_ms == 100
    end

    test "adds multiple frames with correct indices" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")
        |> KittyAnimation.add_frame("f3")

      assert length(anim.frames) == 3

      [f1, f2, f3] = anim.frames
      assert f1.index == 0
      assert f2.index == 1
      assert f3.index == 2
    end
  end

  describe "get_frame/1" do
    test "returns current frame" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      frame = KittyAnimation.get_frame(anim)

      assert frame.data == "f1"
      assert frame.index == 0
    end

    test "returns nil for empty animation" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      assert KittyAnimation.get_frame(anim) == nil
    end
  end

  describe "get_frame/2" do
    test "returns frame by index" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")
        |> KittyAnimation.add_frame("f3")

      assert KittyAnimation.get_frame(anim, 0).data == "f1"
      assert KittyAnimation.get_frame(anim, 1).data == "f2"
      assert KittyAnimation.get_frame(anim, 2).data == "f3"
    end

    test "returns nil for out of bounds index" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = KittyAnimation.add_frame(anim, "f1")

      assert KittyAnimation.get_frame(anim, 5) == nil
    end
  end

  describe "next_frame/1" do
    test "advances frame in forward direction" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, loop_mode: :infinite})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")
        |> KittyAnimation.add_frame("f3")

      {:ok, anim} = KittyAnimation.next_frame(anim)
      assert anim.current_frame == 1

      {:ok, anim} = KittyAnimation.next_frame(anim)
      assert anim.current_frame == 2
    end

    test "wraps around in infinite mode" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, loop_mode: :infinite})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      anim = %{anim | current_frame: 1}

      {:ok, anim} = KittyAnimation.next_frame(anim)
      assert anim.current_frame == 0
    end

    test "completes in once mode" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, loop_mode: :once})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      anim = %{anim | current_frame: 1}

      {:complete, anim} = KittyAnimation.next_frame(anim)
      assert anim.state == :stopped
    end

    test "ping-pong reverses direction" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, loop_mode: :ping_pong})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")
        |> KittyAnimation.add_frame("f3")

      # Forward to end
      anim = %{anim | current_frame: 2, direction: :forward}
      {:ok, anim} = KittyAnimation.next_frame(anim)

      assert anim.direction == :backward
      assert anim.current_frame == 1
    end

    test "returns complete for empty animation" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      {:complete, ^anim} = KittyAnimation.next_frame(anim)
    end
  end

  describe "generate_sequences/1" do
    test "generates escape sequences for frames" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 2, height: 2})

      anim = anim
        |> KittyAnimation.add_frame("RGBA")
        |> KittyAnimation.add_frame("BGRA")

      sequences = KittyAnimation.generate_sequences(anim)

      assert length(sequences) == 2

      # First frame should be full transmit
      assert hd(sequences) =~ "\e_G"
      assert hd(sequences) =~ "a=T"
    end
  end

  describe "GenServer behavior" do
    test "starts animation player" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      {:ok, pid} = KittyAnimation.start(anim)

      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "get_state returns current animation state" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = KittyAnimation.add_frame(anim, "f1")

      {:ok, pid} = KittyAnimation.start(anim)

      state = KittyAnimation.get_state(pid)

      assert state.width == 10
      assert state.height == 10
      assert length(state.frames) == 1

      GenServer.stop(pid)
    end

    test "play starts playback" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.play(pid)

      # Give it a moment to update state
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.state == :playing

      GenServer.stop(pid)
    end

    test "pause stops playback" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = KittyAnimation.add_frame(anim, "f1")

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.play(pid)
      Process.sleep(10)

      KittyAnimation.pause(pid)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.state == :paused

      GenServer.stop(pid)
    end

    test "stop resets animation" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.play(pid)
      Process.sleep(50)

      KittyAnimation.stop(pid)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.state == :stopped
      assert state.current_frame == 0

      GenServer.stop(pid)
    end

    test "seek jumps to specific frame" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")
        |> KittyAnimation.add_frame("f3")

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.seek(pid, 2)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.current_frame == 2

      GenServer.stop(pid)
    end

    test "seek clamps to valid range" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10})

      anim = anim
        |> KittyAnimation.add_frame("f1")
        |> KittyAnimation.add_frame("f2")

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.seek(pid, 100)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.current_frame == 1  # Clamped to last frame

      GenServer.stop(pid)
    end

    test "set_frame_rate changes playback speed" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, frame_rate: 30})

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.set_frame_rate(pid, 60)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.frame_rate == 60

      GenServer.stop(pid)
    end

    test "set_loop_mode changes loop behavior" do
      {:ok, anim} = KittyAnimation.create_animation(%{width: 10, height: 10, loop_mode: :infinite})

      {:ok, pid} = KittyAnimation.start(anim)

      KittyAnimation.set_loop_mode(pid, :once)
      Process.sleep(10)

      state = KittyAnimation.get_state(pid)
      assert state.loop_mode == :once

      GenServer.stop(pid)
    end
  end
end
