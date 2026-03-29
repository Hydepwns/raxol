defmodule Raxol.UI.TextMeasureTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.TextMeasure

  describe "display_width/1" do
    test "ASCII text" do
      assert TextMeasure.display_width("hello") == 5
      assert TextMeasure.display_width("") == 0
      assert TextMeasure.display_width(" ") == 1
    end

    test "CJK characters count as 2 columns" do
      # Each CJK char = 2 columns
      assert TextMeasure.display_width("中") == 2
      assert TextMeasure.display_width("中文") == 4
      assert TextMeasure.display_width("日本語") == 6
    end

    test "mixed ASCII and CJK" do
      # "hi" = 2, "中" = 2
      assert TextMeasure.display_width("hi中") == 4
      # "a" = 1, "中" = 2, "b" = 1
      assert TextMeasure.display_width("a中b") == 4
    end

    test "fullwidth ASCII variants count as 2 columns" do
      # U+FF21 = fullwidth 'A'
      assert TextMeasure.display_width("\uFF21") == 2
    end

    test "Hangul syllables count as 2 columns" do
      # U+AC00 = first Hangul syllable
      assert TextMeasure.display_width("\uAC00") == 2
    end
  end

  describe "char_display_width/1" do
    test "ASCII char is 1 column" do
      assert TextMeasure.char_display_width("a") == 1
      assert TextMeasure.char_display_width(" ") == 1
    end

    test "CJK char is 2 columns" do
      assert TextMeasure.char_display_width("中") == 2
    end
  end

  describe "split_at_display_width/2" do
    test "splits ASCII at character boundary" do
      {left, right} = TextMeasure.split_at_display_width("hello", 3)
      assert left == "hel"
      assert right == "lo"
    end

    test "does not split CJK character in half" do
      # Width 3 can fit "hi" (2) but not "hi中" (4)
      {left, right} = TextMeasure.split_at_display_width("hi中文", 3)
      assert left == "hi"
      assert right == "中文"
    end

    test "splits at exact CJK boundary" do
      # Width 4 fits "hi中" exactly (2+2)
      {left, right} = TextMeasure.split_at_display_width("hi中文", 4)
      assert left == "hi中"
      assert right == "文"
    end
  end

  describe "layout integration" do
    test "Elements.measure uses display width for CJK text" do
      result = Raxol.UI.Layout.Elements.measure(:text, %{text: "中文"})
      assert result.width == 4
    end

    test "Elements.measure uses display width for mixed text" do
      result = Raxol.UI.Layout.Elements.measure(:text, %{text: "hi中"})
      assert result.width == 4
    end

    test "Elements.measure checkbox with CJK label" do
      result = Raxol.UI.Layout.Elements.measure(:checkbox, %{label: "中文"})
      # 4 (prefix "[x] ") + 4 (CJK display width)
      assert result.width == 8
    end
  end

  describe "cell rendering integration" do
    test "CJK text produces correctly positioned cells" do
      style = %{fg: :white, bg: :black}
      cells = Raxol.UI.ElementRenderer.render_text(0, 0, "中文", style, %{})

      # Two cells: first at x=0, second at x=2 (not x=1)
      assert length(cells) == 2
      [{x0, _, char0, _, _, _}, {x1, _, char1, _, _, _}] = cells
      assert x0 == 0
      assert char0 == "中"
      assert x1 == 2
      assert char1 == "文"
    end

    test "mixed ASCII+CJK produces correctly positioned cells" do
      style = %{fg: :white, bg: :black}
      cells = Raxol.UI.ElementRenderer.render_text(0, 0, "a中b", style, %{})

      assert length(cells) == 3
      [{x0, _, _, _, _, _}, {x1, _, _, _, _, _}, {x2, _, _, _, _, _}] = cells
      # a=1col, 中=2col, b=1col
      assert x0 == 0
      assert x1 == 1
      assert x2 == 3
    end
  end
end
