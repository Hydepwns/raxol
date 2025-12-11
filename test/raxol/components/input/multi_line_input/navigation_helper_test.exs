defmodule Raxol.UI.Components.Input.MultiLineInput.NavigationHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.MultiLineInput, as: State
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper

  # Utility to normalize dimensions
  defp normalize_dimensions(%{width: _, height: _} = dims), do: dims

  defp normalize_dimensions({w, h}) when is_integer(w) and is_integer(h),
    do: %{width: w, height: h}

  defp normalize_dimensions(_), do: %{width: 10, height: 5}

  # Helper to create a minimal state for testing
  defp create_state(
         lines,
         cursor \\ {0, 0},
         dimensions \\ {10, 5},
         scroll \\ {0, 0}
       ) do
    dims = normalize_dimensions(dimensions)

    %State{
      value: Enum.map_join(lines, "\n", & &1),
      placeholder: "",
      width: dims.width,
      height: dims.height,
      theme: test_theme(),
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

  defp test_theme, do: %{}

  describe "move_cursor/2" do
    test ~c"moves cursor left" do
      state = create_state(["hello"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 2}
    end

    test ~c"moves cursor right" do
      state = create_state(["hello"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {0, 4}
    end

    test ~c"moves cursor up" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end

    test ~c"moves cursor down" do
      state = create_state(["hello", "world"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :down)
      assert new_state.cursor_pos == {1, 3}
    end

    test ~c"move left wraps to previous line" do
      state = create_state(["abc", "def"], {1, 0})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 3}
    end

    test ~c"move right wraps to next line" do
      state = create_state(["abc", "def"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {1, 0}
    end

    test ~c"move up clamps column if previous line is shorter" do
      state = create_state(["hi", "world"], {1, 4})
      new_state = NavigationHelper.move_cursor(state, :up)
      # Clamps to end of "hi"
      assert new_state.cursor_pos == {0, 2}
    end

    test ~c"move down clamps column if next line is shorter" do
      state = create_state(["world", "hi"], {0, 4})
      new_state = NavigationHelper.move_cursor(state, :down)
      # Clamps to end of "hi"
      assert new_state.cursor_pos == {1, 2}
    end

    test ~c"move up stays at first line" do
      state = create_state(["hello", "world"], {0, 3})
      new_state = NavigationHelper.move_cursor(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end

    test ~c"move down stays at last line" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor(state, :down)
      assert new_state.cursor_pos == {1, 3}
    end

    test ~c"move left stays at beginning of document" do
      state = create_state(["hello", "world"], {0, 0})
      new_state = NavigationHelper.move_cursor(state, :left)
      assert new_state.cursor_pos == {0, 0}
    end

    test ~c"move right stays at end of document" do
      state = create_state(["hello", "world"], {1, 5})
      new_state = NavigationHelper.move_cursor(state, :right)
      assert new_state.cursor_pos == {1, 5}
    end
  end

  describe "move_cursor_line_start/1" do
    test ~c"moves cursor to column 0" do
      state = create_state(["hello"], {0, 4})
      new_state = NavigationHelper.move_cursor_line_start(state)
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "move_cursor_line_end/1" do
    test ~c"moves cursor to end of current line" do
      state = create_state(["hello", "world"], {0, 2})
      new_state = NavigationHelper.move_cursor_line_end(state)
      assert new_state.cursor_pos == {0, 5}
    end
  end

  describe "move_cursor_page/2" do
    test ~c"moves cursor up by page height (viewport height)" do
      # 5 lines visible
      state = create_state(Enum.map(0..10, &"line #{&1}"), {10, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :up)
      # 10 - 5 = 5
      assert new_state.cursor_pos == {5, 3}
    end

    test ~c"moves cursor to first line if page up goes past start" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {3, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :up)
      assert new_state.cursor_pos == {0, 3}
    end
  end

  describe "move_cursor_page/2 down" do
    test ~c"moves cursor down by page height (viewport height)" do
      # 5 lines visible
      state = create_state(Enum.map(0..10, &"line #{&1}"), {1, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :down)
      # 1 + 5 = 6
      assert new_state.cursor_pos == {6, 3}
    end

    test ~c"moves cursor to last line if page down goes past end" do
      state = create_state(Enum.map(0..10, &"line #{&1}"), {8, 3}, {15, 5})
      new_state = NavigationHelper.move_cursor_page(state, :down)
      assert new_state.cursor_pos == {10, 3}
    end
  end

  describe "move_cursor_doc_start/1" do
    test ~c"moves cursor to {0, 0}" do
      state = create_state(["hello", "world"], {1, 3})
      new_state = NavigationHelper.move_cursor_doc_start(state)
      assert new_state.cursor_pos == {0, 0}
    end
  end

  describe "move_cursor_doc_end/1" do
    test ~c"moves cursor to end of the last line" do
      state = create_state(["hello", "world"], {0, 1})
      new_state = NavigationHelper.move_cursor_doc_end(state)
      assert new_state.cursor_pos == {1, 5}
    end
  end

  describe "normalize_selection/1" do
    test ~c"returns nil tuple when no selection exists" do
      state =
        create_state(["hello"])
        |> Map.put(:selection_start, nil)
        |> Map.put(:selection_end, nil)

      assert NavigationHelper.normalize_selection(state) == {nil, nil}
    end

    test ~c"returns original tuples when start is before end" do
      state =
        create_state(["hello", "world"], {0, 0})
        |> Map.put(:selection_start, {0, 1})
        |> Map.put(:selection_end, {1, 2})
        # Need value for pos_to_index
        |> Map.put(:value, "hello\nworld")

      assert NavigationHelper.normalize_selection(state) == {{0, 1}, {1, 2}}
    end

    test ~c"swaps tuples when start is after end" do
      state =
        create_state(["hello", "world"], {0, 0})
        |> Map.put(:selection_start, {1, 2})
        |> Map.put(:selection_end, {0, 1})
        # Need value for pos_to_index
        |> Map.put(:value, "hello\nworld")

      assert NavigationHelper.normalize_selection(state) == {{0, 1}, {1, 2}}
    end
  end

  describe "line_in_selection?/3" do
    test ~c"returns true if line index is within normalized range" do
      assert NavigationHelper.line_in_selection?(1, {0, 1}, {2, 3}) == true
      assert NavigationHelper.line_in_selection?(0, {0, 1}, {2, 3}) == true
      assert NavigationHelper.line_in_selection?(2, {0, 1}, {2, 3}) == true
    end

    test ~c"returns true if line index is within swapped range" do
      assert NavigationHelper.line_in_selection?(1, {2, 3}, {0, 1}) == true
      assert NavigationHelper.line_in_selection?(0, {2, 3}, {0, 1}) == true
      assert NavigationHelper.line_in_selection?(2, {2, 3}, {0, 1}) == true
    end

    test ~c"returns false if line index is outside range" do
      assert NavigationHelper.line_in_selection?(3, {0, 1}, {2, 3}) == false
      assert NavigationHelper.line_in_selection?(-1, {0, 1}, {2, 3}) == false
    end

    test ~c"returns false if selection is nil" do
      assert NavigationHelper.line_in_selection?(1, nil, {2, 3}) == false
      assert NavigationHelper.line_in_selection?(1, {0, 1}, nil) == false
      assert NavigationHelper.line_in_selection?(1, nil, nil) == false
    end
  end

  describe "select_all/1" do
    test ~c"sets selection start to {0, 0} and end to end of document" do
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
    test ~c"sets selection_start and selection_end to nil" do
      state =
        create_state(["hello"], {0, 2})
        |> Map.put(:selection_start, {0, 1})
        |> Map.put(:selection_end, {0, 4})

      new_state = NavigationHelper.clear_selection(state)

      assert new_state.selection_start == nil
      assert new_state.selection_end == nil
    end
  end
end
