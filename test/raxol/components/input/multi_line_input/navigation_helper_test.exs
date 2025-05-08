defmodule Raxol.Components.Input.MultiLineInput.NavigationHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Input.MultiLineInput, as: State
  alias Raxol.Components.Input.MultiLineInput.NavigationHelper

  # Helper to create a minimal state for testing
  defp create_state(
         lines,
         cursor \\ {0, 0},
         dimensions \\ {10, 5},
         scroll \\ {0, 0}
       ) do
    %State{
      value: Enum.join(lines, "\n"),
      placeholder: "",
      width: elem(dimensions, 0),
      height: elem(dimensions, 1),
      style: %{},
      wrap: :word,
      cursor_pos: cursor,
      scroll_offset: scroll,
      selection_start: nil,
      selection_end: nil,
      history: Raxol.Terminal.Commands.History.new(100),
      shift_held: false,
      focused: false,
      on_change: nil,
      lines: lines,
      id: "test_mle"
    }
  end

  describe "move_cursor/2" do
    test "moves cursor left" do
      state = create_state(["hello"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 2}
    end

    test "moves cursor right" do
      state = create_state(["hello"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {0, 4}
    end

    test "moves cursor up" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end

    test "moves cursor down" do
      state = create_state(["hello", "world"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :down)
      assert new_state.cursor_pos == {1, 3}
    end

    test "move left wraps to previous line" do
      state = create_state(["abc", "def"], {1, 0})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 3}
    end

    test "move right wraps to next line" do
      state = create_state(["abc", "def"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {1, 0}
    end

    test "move up clamps column if previous line is shorter" do
      state = create_state(["hi", "world"], {1, 4})
      new_state = NavigationHelper.move_cursor(state, :up)
      # Clamps to end of "hi"
      assert new_state.cursor_pos == {0, 2}
    end

    test "move down clamps column if next line is shorter" do
      state = create_state(["world", "hi"], {0, 4})
      new_state = NavigationHelper.move_cursor(state, :down)
      # Clamps to end of "hi"
      assert new_state.cursor_pos == {1, 2}
    end

    test "move up stays at first line" do
      state = create_state(["hello", "world"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end

    test "move down stays at last line" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor(state, :down)
      assert new_state.cursor_pos == {1, 3}
    end

    test "move left stays at beginning of document" do
      state = create_state(["hello", "world"], {0, 0})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 0}
    end

    test "move right stays at end of document" do
      state = create_state(["hello", "world"], {1, 5})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {1, 5}
    end
  end

  describe "move_cursor_line_start/1" do
    test "moves cursor to column 0" do
      state = create_state(["hello"], {0, 4})
      new_state = NavigationHelper.move_cursor_line_start(state)
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "move_cursor_line_end/1" do
    test "moves cursor to end of current line" do
      state = create_state(["hello", "world"], {0, 2})
      new_state = NavigationHelper.move_cursor_line_end(state)
      assert new_state.cursor_pos == {0, 5}
    end
  end

  describe "move_cursor_page/2" do
    test "moves cursor up by page height (viewport height)" do
      # 5 lines visible
      state = create_state(Enum.map(0..10, &"line #{&1}"), {10, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :up)
      # 10 - 5 = 5
      assert new_state.cursor_pos == {5, 3}
    end

    test "moves cursor to first line if page up goes past start" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {3, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end
  end

  describe "move_cursor_page/2 down" do
    test "moves cursor down by page height (viewport height)" do
      # 5 lines visible
      state = create_state(Enum.map(0..10, &"line #{&1}"), {1, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :down)
      # 1 + 5 = 6
      assert new_state.cursor_pos == {6, 3}
    end

    test "moves cursor to last line if page down goes past end" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {8, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :down)
      assert new_state.cursor_pos == {10, 3}
    end
  end

  describe "move_cursor_doc_start/1" do
    test "moves cursor to {0, 0}" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor_doc_start(state)
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "move_cursor_doc_end/1" do
    test "moves cursor to end of the last line" do
      state = create_state(["hello", "world"], {0, 1})
      new_state = NavigationHelper.move_cursor_doc_end(state)
      assert new_state.cursor_pos == {1, 5}
    end
  end

  describe "normalize_selection/1" do
    test "returns nil tuple when no selection exists" do
      state =
        create_state(["hello"])
        |> Map.put(:selection_start, nil)
        |> Map.put(:selection_end, nil)

      assert NavigationHelper.normalize_selection(state) == {nil, nil}
    end

    test "returns original tuples when start is before end" do
      state =
        create_state(["hello", "world"], {0, 0})
        |> Map.put(:selection_start, {0, 1})
        |> Map.put(:selection_end, {1, 2})
        # Need value for pos_to_index
        |> Map.put(:value, "hello\nworld")

      assert NavigationHelper.normalize_selection(state) == {{0, 1}, {1, 2}}
    end

    test "swaps tuples when start is after end" do
      state =
        create_state(["hello", "world"], {0, 0})
        |> Map.put(:selection_start, {1, 2})
        |> Map.put(:selection_end, {0, 1})
        # Need value for pos_to_index
        |> Map.put(:value, "hello\nworld")

      assert NavigationHelper.normalize_selection(state) == {{0, 1}, {1, 2}}
    end
  end

  describe "is_line_in_selection?/3" do
    test "returns true if line index is within normalized range" do
      assert NavigationHelper.is_line_in_selection?(1, {0, 1}, {2, 3}) == true
      assert NavigationHelper.is_line_in_selection?(0, {0, 1}, {2, 3}) == true
      assert NavigationHelper.is_line_in_selection?(2, {0, 1}, {2, 3}) == true
    end

    test "returns true if line index is within swapped range" do
      assert NavigationHelper.is_line_in_selection?(1, {2, 3}, {0, 1}) == true
      assert NavigationHelper.is_line_in_selection?(0, {2, 3}, {0, 1}) == true
      assert NavigationHelper.is_line_in_selection?(2, {2, 3}, {0, 1}) == true
    end

    test "returns false if line index is outside range" do
      assert NavigationHelper.is_line_in_selection?(3, {0, 1}, {2, 3}) == false
      assert NavigationHelper.is_line_in_selection?(-1, {0, 1}, {2, 3}) == false
    end

    test "returns false if selection is nil" do
      assert NavigationHelper.is_line_in_selection?(1, nil, {2, 3}) == false
      assert NavigationHelper.is_line_in_selection?(1, {0, 1}, nil) == false
      assert NavigationHelper.is_line_in_selection?(1, nil, nil) == false
    end
  end

  describe "select_all/1" do
    test "sets selection start to {0, 0} and end to end of document" do
      state = create_state(["hello", "world there"], {1, 2})
      new_state = NavigationHelper.select_all(state)

      assert new_state.selection_start == {0, 0}
      # Since the implementation calculates based on the actual lines,
      # we should expect the correct endpoint
      # end of "world there"
      assert new_state.selection_end == {1, 11}
    end
  end

  describe "clear_selection/1" do
    test "sets selection_start and selection_end to nil" do
      state =
        create_state(["hello"], {0, 2})
        |> Map.put(:selection_start, {0, 1})
        |> Map.put(:selection_end, {0, 4})

      new_state = NavigationHelper.clear_selection(state)

      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end
  end

  # TODO: Add tests for ensure_cursor_visible, word movement
end
