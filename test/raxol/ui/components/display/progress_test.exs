defmodule Raxol.UI.Components.Display.ProgressTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Progress

  describe "create/1" do
    test "creates a progress bar with default props" do
      progress = Progress.create(%{})

      assert progress.props.progress == 0.0
      assert progress.props.width == 20
      assert progress.props.show_percentage == false
      assert progress.props.animated == false
      assert progress.props.label == nil

      assert progress.state.animation_frame == 0
      assert is_integer(progress.state.last_update)
    end

    test "creates a progress bar with custom props" do
      progress =
        Progress.create(%{
          progress: 0.75,
          width: 30,
          show_percentage: true,
          animated: true,
          label: "Loading..."
        })

      assert progress.props.progress == 0.75
      assert progress.props.width == 30
      assert progress.props.show_percentage == true
      assert progress.props.animated == true
      assert progress.props.label == "Loading..."
    end

    test "clamps progress value to valid range" do
      # Test with value below range
      below = Progress.create(%{progress: -0.5})
      assert below.props.progress == 0.0

      # Test with value above range
      above = Progress.create(%{progress: 1.5})
      assert above.props.progress == 1.0
    end
  end

  describe "update/2" do
    test "updates props" do
      progress = Progress.create(%{progress: 0.3})
      updated = Progress.update(progress, %{progress: 0.6, width: 40})

      assert updated.props.progress == 0.6
      assert updated.props.width == 40
    end

    test "updates animation state when animated" do
      progress = Progress.create(%{animated: true})

      # Set specific animation frame and update timestamp
      initial_frame = 3
      # Older than animation speed
      old_timestamp = System.monotonic_time(:millisecond) - 200

      progress = %{
        progress
        | state: %{animation_frame: initial_frame, last_update: old_timestamp}
      }

      # Update should advance the animation frame
      updated = Progress.update(progress, %{animated: true})

      # The frame should have advanced
      assert updated.state.animation_frame != initial_frame
      assert updated.state.last_update > old_timestamp
    end

    test "doesn't update animation when not animated" do
      progress = Progress.create(%{animated: false})

      # Set specific animation frame
      initial_frame = 3
      old_timestamp = System.monotonic_time(:millisecond) - 200

      progress = %{
        progress
        | state: %{animation_frame: initial_frame, last_update: old_timestamp}
      }

      # Update should not change animation state
      updated = Progress.update(progress, %{width: 40})

      # The animation state should remain the same
      assert updated.state.animation_frame == initial_frame
      assert updated.state.last_update == old_timestamp
    end
  end

  describe "render/2" do
    test "renders basic progress bar" do
      progress = Progress.create(%{progress: 0.5, width: 10})
      elements = Progress.render(progress, %{})

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
      progress =
        Progress.create(%{progress: 0.75, width: 20, show_percentage: true})

      elements = Progress.render(progress, %{})

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
      progress = Progress.create(%{progress: 0.3, label: "Downloading..."})
      elements = Progress.render(progress, %{})

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
      empty = Progress.create(%{progress: 0.0, width: 10})
      empty_elements = Progress.render(empty, %{})

      empty_fill =
        Enum.find(empty_elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      assert empty_fill.text == String.duplicate(" ", 8)

      # Test half-filled bar
      half = Progress.create(%{progress: 0.5, width: 10})
      half_elements = Progress.render(half, %{})

      half_fill =
        Enum.find(half_elements, fn e ->
          e.type == :text && e.x == 1 && e.y == 0
        end)

      assert half_fill.text ==
               String.duplicate("█", 4) <> String.duplicate(" ", 4)

      # Test completely filled bar
      full = Progress.create(%{progress: 1.0, width: 10})
      full_elements = Progress.render(full, %{})

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

      progress =
        Progress.create(%{
          progress: 0.5,
          width: 10,
          animated: true
        })

      progress = %{progress | state: %{animation_frame: frame, last_update: 0}}

      elements = Progress.render(progress, %{})

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
