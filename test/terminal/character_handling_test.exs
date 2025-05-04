defmodule Raxol.Terminal.CharacterHandlingTest do
  use ExUnit.Case
  alias Raxol.Terminal.CharacterHandling

  describe "wide character detection" do
    test "identifies wide characters correctly" do
      assert CharacterHandling.is_wide_char?("中")
      assert CharacterHandling.is_wide_char?("日")
      refute CharacterHandling.is_wide_char?("a")
      refute CharacterHandling.is_wide_char?("1")
    end
  end

  describe "character width" do
    test "calculates character width correctly" do
      assert CharacterHandling.get_char_width("中") == 2
      assert CharacterHandling.get_char_width("日") == 2
      assert CharacterHandling.get_char_width("a") == 1
      assert CharacterHandling.get_char_width("1") == 1
    end
  end

  describe "combining characters" do
    test "handles combining characters correctly" do
      # Using a proper combining character sequence for 'é'
      # Combining acute accent
      assert CharacterHandling.is_combining_char?("\u0301")
      # 'é' should be width 1
      assert CharacterHandling.get_char_width("e\u0301") == 1
    end
  end

  describe "bidirectional text" do
    test "processes bidirectional text correctly" do
      # Using a proper RTL character sequence
      # \u202E is RTL mark
      text = "Hello \u202E World"
      # Assert the structure returned by process_bidi_text
      assert CharacterHandling.process_bidi_text(text) == [LTR: "Hello ", RTL: "World"]
    end
  end

  describe "string width" do
    test "calculates string width correctly" do
      assert CharacterHandling.get_string_width("Hello") == 5
      # 5 + 2*2
      assert CharacterHandling.get_string_width("Hello 世界") == 9
      # 'é' counts as 1
      assert CharacterHandling.get_string_width("Hello\u0301") == 5 # Width doesn't include combining char
    end
  end
end
