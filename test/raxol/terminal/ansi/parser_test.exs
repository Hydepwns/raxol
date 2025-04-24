defmodule Raxol.Terminal.ANSI.ParserTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.Parser

  test "parses cursor movement sequences" do
    assert Parser.parse_sequence("\e[5A") == {:cursor_up, 5}
    assert Parser.parse_sequence("\e[B") == {:cursor_down, 1}
    assert Parser.parse_sequence("\e[10C") == {:cursor_forward, 10}
    assert Parser.parse_sequence("\e[2D") == {:cursor_backward, 2}
    assert Parser.parse_sequence("\e[5;10H") == {:cursor_move, 5, 10}
    assert Parser.parse_sequence("\e[H") == {:cursor_move, 1, 1}
    assert Parser.parse_sequence("\e[S") == {:cursor_save}
    assert Parser.parse_sequence("\e[T") == {:cursor_restore}
  end

  test "parses SGR (color and attribute) sequences" do
    assert Parser.parse_sequence("\e[31m") == {:text_attributes, [{:foreground_basic, 1}]}
    assert Parser.parse_sequence("\e[42m") == {:text_attributes, [{:background_basic, 2}]}
    assert Parser.parse_sequence("\e[1m") == {:text_attributes, [:bold]}
    assert Parser.parse_sequence("\e[0m") == {:reset_attributes}

    # Multiple attributes
    assert Parser.parse_sequence("\e[31;1;4m") ==
      {:text_attributes, [:underline, :bold, {:foreground_basic, 1}]}

    # 256-color mode
    assert Parser.parse_sequence("\e[38;5;100m") ==
      {:text_attributes, [{:foreground_256, 100}]}

    # RGB color
    assert Parser.parse_sequence("\e[38;2;100;150;200m") ==
      {:text_attributes, [{:foreground_true, 100, 150, 200}]}
  end

  test "parses screen manipulation sequences" do
    assert Parser.parse_sequence("\e[2J") == {:clear_screen, 2}
    assert Parser.parse_sequence("\e[K") == {:clear_line, 0}
    assert Parser.parse_sequence("\e[1K") == {:clear_line, 1}
    assert Parser.parse_sequence("\e[5L") == {:insert_line, 5}
  end

  test "parses mode sequences" do
    assert Parser.parse_sequence("\e[?25h") == {:set_mode, 25, true}
    assert Parser.parse_sequence("\e[?1049l") == {:set_mode, 1049, false}
  end

  test "parses device status sequences" do
    assert Parser.parse_sequence("\e[6n") == {:device_status, 6}
  end

  test "parses charset sequences" do
    assert Parser.parse_sequence("\e(B") == {:designate_charset, 0, "B"}
    assert Parser.parse_sequence("\e)0") == {:designate_charset, 1, "0"}
  end

  test "parses OSC sequences" do
    assert Parser.parse_sequence("\e]0;window title\a") == {:osc, 0, "window title"}
  end

  test "handles unknown sequences" do
    assert match?({:unknown, _}, Parser.parse_sequence("\e[999X"))
  end
end
