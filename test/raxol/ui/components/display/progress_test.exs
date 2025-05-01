defmodule Raxol.UI.Components.Display.ProgressTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Progress

  describe "init/1" do
    test "creates a progress bar with default props" do
      state = Progress.init(%{})

      assert state.progress == 0.0
      assert state.width == 20
      assert state.show_percentage == false
      assert state.animated == false
      assert state.label == nil

      assert state.animation_frame == 0
      assert is_integer(state.last_update)
    end

    test "creates a progress bar with custom props" do
      state =
        Progress.init(%{
          progress: 0.75,
          width: 30,
          show_percentage: true,
          animated: true,
          label: "Loading..."
        })

      assert state.progress == 0.75
      assert state.width == 30
      assert state.show_percentage == true
      assert state.animated == true
      assert state.label == "Loading..."
    end

    test "clamps progress value to valid range" do
      # Test with value below range
      below = Progress.init(%{progress: -0.5})
      assert below.progress == 0.0

      # Test with value above range
      above = Progress.init(%{progress: 1.5})
      assert above.progress == 1.0
    end
  end

  describe "update/2" do
    test "updates props" do
      state = Progress.init(%{progress: 0.3})
      {:noreply, updated, _cmd} = Progress.update({:update_props, %{progress: 0.6, width: 40}}, state)

      assert updated.progress == 0.6
      assert updated.width == 40
    end

    test "updates animation state when animated" do
      state = Progress.init(%{animated: true})

      # Set specific animation frame and update timestamp
      initial_frame = 3
      # Older than animation speed
      old_timestamp = System.monotonic_time(:millisecond) - 200

      state = %{
        state
        | animation_frame: initial_frame, last_update: old_timestamp
      }

      # Update should advance the animation frame
      {:noreply, updated, _cmd} = Progress.update(:tick, state)

      # The frame should have advanced
      assert updated.animation_frame != initial_frame
      assert updated.last_update > old_timestamp
    end

    test "doesn't update animation when not animated" do
      state = Progress.init(%{animated: false})

      # Set specific animation frame
      initial_frame = 3
      old_timestamp = System.monotonic_time(:millisecond) - 200

      state = %{
        state
        | animation_frame: initial_frame, last_update: old_timestamp
      }

      # Update should not change animation state
      {:noreply, updated, _cmd} = Progress.update(:tick, state)

      # The animation state should remain the same
      assert updated.animation_frame == initial_frame
      assert updated.last_update == old_timestamp
    end
  end

  describe "render/1" do
    test "renders basic progress bar" do
      state = Progress.init(%{progress: 0.5, width: 10})
      elements = Progress.render(state)

      # Should have box and progress text elements
      assert length(elements) == 2

      # Verify box element
      box = Enum.find(elements, fn e -> e.type == :box end)
      assert box != nil
      assert box.width == 10

      # Verify progress fill
      text = Enum.find(elements, fn e -> e.type == :text end)
      assert text != nil

      # For 50% completion in width 10 with 2 chars for borders, we expect 4 filled chars
      # Total internal width
      assert String.length(text.text) == 8
      # Filled part
      assert String.trim_trailing(text.text) |> String.length() == 4
    end

    test "renders percentage text when enabled" do
      state =
        Progress.init(%{progress: 0.75, width: 20, show_percentage: true})

      elements = Progress.render(state)

      # Should have box, progress fill, and percentage text
      assert length(elements) == 3

      # Find percentage text element (should be the first in the list)
      percentage =
        Enum.find(elements, fn e ->
          e.type == :text && e.attrs.bg == :transparent
        end)

      assert percentage != nil
      assert percentage.text =~ "75%"
    end

    test "renders label when provided" do
      state = Progress.init(%{progress: 0.3, label: "Downloading..."})
      elements = Progress.render(state)

      # Should include a label element
      assert length(elements) == 3

      # Find label element (should be at y = -1)
      label =
        Enum.find(elements, fn e ->
          e.type == :text && e.y == -1
        end)

      assert label != nil
      assert label.text == "Downloading..."
    end

    test "generates correct bar content for different progress values" do
      # Test empty bar
      empty_state = Progress.init(%{progress: 0.0, width: 10})
      empty_elements = Progress.render(empty_state)

      empty_fill =
        Enum.find(empty_elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      assert empty_fill.text == String.duplicate(" ", 8)

      # Test half-filled bar
      half_state = Progress.init(%{progress: 0.5, width: 10})
      half_elements = Progress.render(half_state)

      half_fill =
        Enum.find(half_elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      assert half_fill.text ==
               String.duplicate("█", 4) <> String.duplicate(" ", 4)

      # Test completely filled bar
      full_state = Progress.init(%{progress: 1.0, width: 10})
      full_elements = Progress.render(full_state)

      full_fill =
        Enum.find(full_elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      assert full_fill.text == String.duplicate("█", 8)
    end

    test "renders animation character when animated" do
      # Create animated progress bar with specific animation frame
      # Choose a specific frame for predictable test
      frame = 3

      state =
        Progress.init(%{
          progress: 0.5,
          width: 10,
          animated: true
        })

      state = %{state | animation_frame: frame, last_update: 0}

      elements = Progress.render(state)

      # Find the progress fill text
      fill =
        Enum.find(elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      # Should have animation character at position 4 (after 4 filled blocks)
      animation_char =
        Enum.at(Progress.module_info(:attributes)[:animation_chars], frame)

      expected =
        String.duplicate("█", 4) <> animation_char <> String.duplicate(" ", 3)

      assert fill.text == expected
    end
  end
end
