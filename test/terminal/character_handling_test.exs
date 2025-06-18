defmodule Raxol.Terminal.CharacterHandlingTest do
  use ExUnit.Case
  alias Raxol.Terminal.CharacterHandling

  describe "wide character detection" do
    test 'identifies wide characters correctly' do
      assert CharacterHandling.is_wide_char?(?中)
      assert CharacterHandling.is_wide_char?(?日)
      refute CharacterHandling.is_wide_char?(?a)
      refute CharacterHandling.is_wide_char?(?1)
    end
  end

  describe "character width" do
    test 'calculates character width correctly' do
      assert Raxol.Terminal.CharacterHandling.get_char_width("中") == 2
      assert Raxol.Terminal.CharacterHandling.get_char_width("日") == 2
      assert Raxol.Terminal.CharacterHandling.get_char_width("a") == 1
      assert Raxol.Terminal.CharacterHandling.get_char_width("1") == 1
    end
  end

  describe "combining characters" do
    test 'handles combining characters correctly' do
      assert Raxol.Terminal.CharacterHandling.is_combining_char?(0x0301)
      assert Raxol.Terminal.CharacterHandling.get_char_width("e\u0301") == 1
    end
  end

  describe "bidirectional text" do
    # TODO: Skipping this test as the current process_bidi_text implementation
    #       is a placeholder and does not fully implement the Unicode Bidirectional Algorithm.
    #       A proper fix requires a more sophisticated approach.
    # @tag :skip # Unskipping the test
    test 'processes bidirectional text correctly' do
      # Using a proper RTL character sequence
      # \u202E is RTL mark
      text = "Hello \u202E World"
      # Assert the structure returned by process_bidi_text
      # The function returns a list of tuples, not a keyword list.
      assert CharacterHandling.process_bidi_text(text) == [
               {:LTR, "Hello "},
               {:RTL, " World"}
             ]
    end
  end

  describe "string width" do
    test 'calculates string width correctly' do
      assert Raxol.Terminal.CharacterHandling.get_string_width("Hello") == 5
      # 5 (Hello) + 1 (space) + 2 (世) + 2 (界) = 10
      assert Raxol.Terminal.CharacterHandling.get_string_width("Hello 世界") == 10
      # 'e' + combining accent = width 1. 5 + 0 = 5
      # Width doesn't include combining char
      assert Raxol.Terminal.CharacterHandling.get_string_width("Hello\u0301") ==
               5
    end
  end
end
