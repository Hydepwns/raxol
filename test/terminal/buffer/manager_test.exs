defmodule Raxol.Terminal.Buffer.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer

  describe "scrollback buffer" do
    test "clears scrollback buffer when clearing entire display" do
      manager = Manager.new(80, 24)

      # Add some content to scrollback buffer
      manager = %{
        manager
        | scrollback_buffer: [
            ScreenBuffer.new(80, 24),
            ScreenBuffer.new(80, 24)
          ]
      }

      # Clear entire display with scrollback
      manager = Manager.clear_entire_display_with_scrollback(manager)

      # Check scrollback buffer is cleared
      assert manager.scrollback_buffer == []

      # Check damage regions
      damage_regions = Manager.get_damage_regions(manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}
    end

    test "maintains scrollback buffer when clearing display without scrollback" do
      manager = Manager.new(80, 24)

      # Add some content to scrollback buffer
      scrollback = [
        ScreenBuffer.new(80, 24),
        ScreenBuffer.new(80, 24)
      ]

      manager = %{manager | scrollback_buffer: scrollback}

      # Clear entire display without scrollback
      manager = Manager.clear_entire_display(manager)

      # Check scrollback buffer is unchanged
      assert manager.scrollback_buffer == scrollback

      # Check damage regions
      damage_regions = Manager.get_damage_regions(manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}
    end
  end

  describe "scrolling" do
    test "scrolls up and maintains scrollback buffer" do
      manager = Manager.new(80, 24)

      # Write some text
      manager = Manager.write_char(manager, "A")
      manager = Manager.move_cursor(manager, 0, 1)
      manager = Manager.write_char(manager, "B")

      # Scroll up
      manager = Manager.scroll_up(manager, 1)

      # Check scrollback buffer
      assert length(manager.scrollback_buffer) == 1

      assert Cell.get_char(List.first(List.first(manager.scrollback_buffer))) ==
               "A"

      # Check damage regions
      damage_regions = Manager.get_damage_regions(manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}
    end

    test "scrolls down and restores from scrollback" do
      manager = Manager.new(80, 24)

      # Write some text and scroll up
      manager = Manager.write_char(manager, "A")
      manager = Manager.scroll_up(manager, 1)
      manager = Manager.scroll_down(manager, 1)

      # Check scrollback buffer is empty
      assert manager.scrollback_buffer == []

      # Check damage regions
      damage_regions = Manager.get_damage_regions(manager)
      assert length(damage_regions) == 1
      assert hd(damage_regions) == {0, 0, 79, 23}
    end

    test "respects scrollback limit" do
      # Small scrollback limit
      manager = Manager.new(80, 24, 2)

      # Write text and scroll multiple times
      manager = Manager.write_char(manager, "A")
      manager = Manager.scroll_up(manager, 3)

      # Check scrollback limit
      assert length(manager.scrollback_buffer) == 2
    end
  end

  describe "scroll region" do
    test "sets and clears scroll region" do
      manager = Manager.new(80, 24)
      manager = Manager.set_scroll_region(manager, 5, 15)
      assert manager.active_buffer.scroll_region == {5, 15}

      manager = Manager.clear_scroll_region(manager)
      assert manager.active_buffer.scroll_region == nil
    end

    test "respects scroll region boundaries" do
      manager = Manager.new(80, 24)
      manager = Manager.set_scroll_region(manager, 5, 15)

      # Write some text
      manager = Manager.write_char(manager, "A")
      manager = Manager.move_cursor(manager, 0, 20)
      manager = Manager.write_char(manager, "B")

      # Scroll up
      manager = Manager.scroll_up(manager, 1)

      # Check that only the scroll region was affected
      assert Cell.get_char(ScreenBuffer.get_cell(manager.active_buffer, 0, 4)) ==
               "A"

      assert Cell.get_char(ScreenBuffer.get_cell(manager.active_buffer, 0, 20)) ==
               "B"
    end
  end

  describe "selection" do
    test "starts and updates selection" do
      manager = Manager.new(80, 24)
      manager = Manager.start_selection(manager, 10, 5)
      assert manager.active_buffer.selection == {{10, 5}, nil}

      manager = Manager.update_selection(manager, 20, 10)
      assert manager.active_buffer.selection == {{10, 5}, {20, 10}}
    end

    test "gets selected text" do
      manager = Manager.new(80, 24)

      # Write some text
      manager = Manager.write_char(manager, "Hello")
      manager = Manager.move_cursor(manager, 0, 1)
      manager = Manager.write_char(manager, "World")

      # Select the text
      manager = Manager.start_selection(manager, 0, 0)
      manager = Manager.update_selection(manager, 4, 1)

      assert Manager.get_selection(manager) == "Hello\nWorld"
    end

    test "checks if position is in selection" do
      manager = Manager.new(80, 24)
      manager = Manager.start_selection(manager, 10, 5)
      manager = Manager.update_selection(manager, 20, 10)

      assert Manager.is_in_selection?(manager, 15, 7) == true
      assert Manager.is_in_selection?(manager, 5, 5) == false
      assert Manager.is_in_selection?(manager, 25, 7) == false
    end

    test "gets selection boundaries" do
      manager = Manager.new(80, 24)
      manager = Manager.start_selection(manager, 10, 5)
      manager = Manager.update_selection(manager, 20, 10)

      assert Manager.get_selection_boundaries(manager) == {{10, 5}, {20, 10}}
    end
  end
end
