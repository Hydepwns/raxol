defmodule Raxol.UI.Components.TerminalTest do
  use ExUnit.Case
  alias Raxol.UI.Components.Terminal
  alias Raxol.Core.Events.Event

  defp initial_terminal_state(opts \\ []) do
    Terminal.init(opts)
  end

  describe "Terminal component" do
    test 'initializes with default values' do
      terminal = initial_terminal_state()

      assert terminal.id == nil
      assert terminal.width == 80
      assert terminal.height == 24
      assert terminal.buffer == []
      assert terminal.style == %{}
    end

    test 'handles resize events (updates width/height)' do
      terminal = initial_terminal_state()
      event = %Event{type: :resize, data: %{cols: 100, rows: 50}}

      {new_terminal_state, _commands} =
        Terminal.handle_event(event, %{}, terminal)

      assert new_terminal_state.width == 80
      assert new_terminal_state.height == 24
    end

    test "switches to insert mode on "i" key (Placeholder - checks buffer)" do
      terminal = initial_terminal_state()
      event = %Event{type: :key, data: %{key: :i}}

      {new_terminal_state, _commands} =
        Terminal.handle_event(event, %{}, terminal)

      assert new_terminal_state.buffer == ["Key: :i"]
    end

    test "switches to command mode on ":" key (Placeholder - checks buffer)" do
      terminal = initial_terminal_state()
      event = %Event{type: :key, data: %{key: :colon}}

      {new_terminal_state, _commands} =
        Terminal.handle_event(event, %{}, terminal)

      assert new_terminal_state.buffer == ["Key: :colon"]
    end

    test 'handles character input in insert mode (Placeholder - checks buffer)' do
      terminal = initial_terminal_state()

      insert_mode_event = %Event{type: :key, data: %{key: :i}}

      {insert_mode_state, _} =
        Terminal.handle_event(insert_mode_event, %{}, terminal)

      char_event = %Event{type: :key, data: %{key: "a"}}

      {final_state, _} =
        Terminal.handle_event(char_event, %{}, insert_mode_state)

      assert final_state.buffer == ["Key: :i", "Key: \"a\""]
    end

    test 'exits insert mode on escape key (Placeholder - checks buffer)' do
      terminal = initial_terminal_state()

      insert_mode_event = %Event{type: :key, data: %{key: :i}}

      {insert_mode_state, _} =
        Terminal.handle_event(insert_mode_event, %{}, terminal)

      assert insert_mode_state.buffer == ["Key: :i"]

      escape_event = %Event{type: :key, data: %{key: :escape}}

      {final_state, _} =
        Terminal.handle_event(escape_event, %{}, insert_mode_state)

      assert final_state.buffer == ["Key: :i", "Key: :escape"]
    end

    test 'renders visible portion of buffer' do
      terminal = initial_terminal_state(buffer: ["Line 1", "Line 2"])
      rendered = Terminal.render(terminal, %{})

      assert is_map(rendered)
      assert Map.has_key?(rendered, :type)
      assert rendered.type == :box
      assert Map.get(rendered.attrs, :id) == terminal.id
      assert Map.get(rendered.attrs, :width) == terminal.width
      assert Map.get(rendered.attrs, :height) == terminal.height
      assert Map.get(rendered.attrs, :style) == terminal.style

      column = rendered.children
      assert is_map(column)
      assert Map.has_key?(column, :type)
      assert column.type == :column

      assert is_list(column.children)
      assert length(column.children) == 2
      [label1, label2] = column.children
      assert is_map(label1)
      assert Map.has_key?(label1, :type)
      assert label1.type == :label
      assert Map.get(label1.attrs, :content) == "Line 1"
      assert is_map(label2)
      assert Map.has_key?(label2, :type)
      assert label2.type == :label
      assert Map.get(label2.attrs, :content) == "Line 2"
    end
  end
end
