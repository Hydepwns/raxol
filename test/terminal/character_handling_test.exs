defmodule Raxol.Terminal.CharacterHandlingTest do
  use ExUnit.Case
  alias Raxol.Terminal.CharacterHandling

  describe "wide character detection" do
    test "identifies wide characters correctly" do
      assert CharacterHandling.is_wide?("中")
      assert CharacterHandling.is_wide?("日")
      refute CharacterHandling.is_wide?("a")
      refute CharacterHandling.is_wide?("1")
    end
  end

  describe "character width" do
    test "calculates character width correctly" do
      assert CharacterHandling.char_width("中") == 2
      assert CharacterHandling.char_width("日") == 2
      assert CharacterHandling.char_width("a") == 1
      assert CharacterHandling.char_width("1") == 1
    end
  end

  describe "combining characters" do
    test "handles combining characters correctly" do
      # Using a proper combining character sequence for 'é'
      assert CharacterHandling.is_combining?("\u0301")  # Combining acute accent
      assert CharacterHandling.char_width("e\u0301") == 1  # 'é' should be width 1
    end
  end

  describe "bidirectional text" do
    test "processes bidirectional text correctly" do
      # Using a proper RTL character sequence
      text = "Hello \u202E World"  # \u202E is RTL mark
      assert CharacterHandling.process_bidirectional(text) == "Hello World"
    end
  end

  describe "string width" do
    test "calculates string width correctly" do
      assert CharacterHandling.string_width("Hello") == 5
      assert CharacterHandling.string_width("Hello 世界") == 9  # 5 + 2*2
      assert CharacterHandling.string_width("Hello\u0301") == 6  # 'é' counts as 1
    end
  end
end
