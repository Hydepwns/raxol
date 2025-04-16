defmodule Raxol.Components.TerminalTest do
  use ExUnit.Case
  alias Raxol.ComponentHelpers
  alias Raxol.Components.Terminal

  describe "Terminal component" do
    test "initializes with default values" do
      terminal = ComponentHelpers.create_test_component(Terminal)

      assert terminal.state.buffer == ["$ "]
      assert terminal.state.cursor == {2, 0}
      assert terminal.state.dimensions == {80, 24}
      assert terminal.state.mode == :normal
      assert terminal.state.history == []
      assert terminal.state.history_index == 0
      assert terminal.state.scroll_offset == 0
    end

    test "handles resize events" do
      terminal = ComponentHelpers.create_test_component(Terminal)

      {state, _} =
        ComponentHelpers.simulate_event(terminal, :resize, %{
          cols: 100,
          rows: 50
        })

      assert state.dimensions == {100, 50}
    end

    test "switches to insert mode on 'i' key" do
      terminal = ComponentHelpers.create_test_component(Terminal)
      {state, _} = ComponentHelpers.simulate_event(terminal, :key, %{key: :i})

      assert state.mode == :insert
    end

    test "switches to command mode on ':' key" do
      terminal = ComponentHelpers.create_test_component(Terminal)

      {state, _} =
        ComponentHelpers.simulate_event(terminal, :key, %{key: :colon})

      assert state.mode == :command
    end

    test "handles character input in insert mode" do
      terminal = ComponentHelpers.create_test_component(Terminal)

      # Enter insert mode
      {state, _} = ComponentHelpers.simulate_event(terminal, :key, %{key: :i})

      # Type a character
      {state, _} = ComponentHelpers.simulate_event(state, :key, %{key: "a"})

      # Moved one position right
      assert state.cursor == {3, 0}
    end

    test "exits insert mode on escape key" do
      terminal = ComponentHelpers.create_test_component(Terminal)

      # Enter insert mode
      {state, _} = ComponentHelpers.simulate_event(terminal, :key, %{key: :i})
      assert state.mode == :insert

      # Exit insert mode
      {state, _} = ComponentHelpers.simulate_event(state, :key, %{key: :escape})
      assert state.mode == :normal
    end

    test "renders visible portion of buffer" do
      terminal = ComponentHelpers.create_test_component(Terminal)
      rendered = ComponentHelpers.render_component(terminal)

      assert rendered.type == :terminal
      assert rendered.attrs.content == "$ "
      assert rendered.attrs.cursor == {2, 0}
      assert rendered.attrs.dimensions == {80, 24}
    end
  end
end
