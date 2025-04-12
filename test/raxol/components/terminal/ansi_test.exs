defmodule Raxol.Components.Terminal.ANSITest do
  use ExUnit.Case
  alias Raxol.Components.Terminal.ANSI

  @initial_state %{
    cursor: {0, 0},
    style: %{},
    screen: %{},
    buffer: [],
    dimensions: {80, 24}
  }

  test "processes basic text input" do
    state = ANSI.process("Hello", @initial_state)
    assert state.buffer == ["Hello"]
    assert state.cursor == {5, 0}
  end

  test "processes ANSI color codes" do
    state = ANSI.process("\e[31mRed\e[0m", @initial_state)
    assert state.buffer == ["Red"]
    assert state.style == %{color: :red}
  end

  test "processes cursor movement" do
    state = ANSI.process("\e[5;10H", @initial_state)
    # 1-based to 0-based conversion
    assert state.cursor == {9, 4}
  end

  test "processes multiple ANSI codes" do
    state = ANSI.process("\e[31m\e[44mColored\e[0m", @initial_state)
    assert state.buffer == ["Colored"]
    assert state.style == %{color: :red, background: :blue}
  end

  test "handles line wrapping" do
    state = ANSI.process(String.duplicate("a", 85), @initial_state)
    # 80 chars per line, 5 chars on second line
    assert state.cursor == {5, 1}
  end

  test "processes cursor up movement" do
    state = ANSI.process("\e[5A", %{@initial_state | cursor: {0, 10}})
    assert state.cursor == {0, 5}
  end

  test "processes cursor down movement" do
    state = ANSI.process("\e[3B", %{@initial_state | cursor: {0, 0}})
    assert state.cursor == {0, 3}
  end

  test "processes cursor forward movement" do
    state = ANSI.process("\e[5C", %{@initial_state | cursor: {0, 0}})
    assert state.cursor == {5, 0}
  end

  test "processes cursor backward movement" do
    state = ANSI.process("\e[3D", %{@initial_state | cursor: {10, 0}})
    assert state.cursor == {7, 0}
  end

  test "processes screen clearing" do
    state = ANSI.process("\e[2J", %{@initial_state | buffer: ["Some text"]})
    assert state.buffer == []
  end

  test "processes line clearing" do
    state = ANSI.process("\e[2K", %{@initial_state | buffer: ["Some text"]})
    assert state.buffer == []
  end

  test "processes text styles" do
    state = ANSI.process("\e[1;4mBold and Underline\e[0m", @initial_state)
    assert state.style == %{bold: true, underline: true}
  end

  test "handles invalid ANSI codes gracefully" do
    state = ANSI.process("\e[999mInvalid\e[0m", @initial_state)
    assert state.buffer == ["Invalid"]
    assert state.style == %{}
  end

  test "processes bright colors" do
    state = ANSI.process("\e[91mBright Red\e[0m", @initial_state)
    assert state.style == %{color: :red}
  end

  test "processes background colors" do
    state = ANSI.process("\e[41mRed Background\e[0m", @initial_state)
    assert state.style == %{background: :red}
  end

  test "processes bright background colors" do
    state = ANSI.process("\e[101mBright Red Background\e[0m", @initial_state)
    assert state.style == %{background: :red}
  end
end
