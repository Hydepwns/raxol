defmodule Raxol.Terminal.CharacterSetsTest do
  use ExUnit.Case
  alias Raxol.Terminal.CharacterSets

  describe "character set translation" do
    test "translates Latin-1 characters" do
      # Test control characters
      assert CharacterSets.translate(<<0x00>>, :latin1) == " "
      assert CharacterSets.translate(<<0x09>>, :latin1) == "\t"
      assert CharacterSets.translate(<<0x0A>>, :latin1) == "\n"
      assert CharacterSets.translate(<<0x0D>>, :latin1) == "\r"

      # Test special characters
      # Non-breaking space
      assert CharacterSets.translate(<<0xA0>>, :latin1) == " "
      # Inverted exclamation mark
      assert CharacterSets.translate(<<0xA1>>, :latin1) == "¡"
      # Cent sign
      assert CharacterSets.translate(<<0xA2>>, :latin1) == "¢"
      # Pound sign
      assert CharacterSets.translate(<<0xA3>>, :latin1) == "£"
      # Currency sign
      assert CharacterSets.translate(<<0xA4>>, :latin1) == "¤"
      # Yen sign
      assert CharacterSets.translate(<<0xA5>>, :latin1) == "¥"

      # Test accented characters
      # Latin capital letter A with grave
      assert CharacterSets.translate(<<0xC0>>, :latin1) == "À"
      # Latin capital letter A with acute
      assert CharacterSets.translate(<<0xC1>>, :latin1) == "Á"
      # Latin capital letter A with circumflex
      assert CharacterSets.translate(<<0xC2>>, :latin1) == "Â"
      # Latin capital letter A with tilde
      assert CharacterSets.translate(<<0xC3>>, :latin1) == "Ã"
      # Latin capital letter A with diaeresis
      assert CharacterSets.translate(<<0xC4>>, :latin1) == "Ä"
      # Latin capital letter A with ring above
      assert CharacterSets.translate(<<0xC5>>, :latin1) == "Å"

      # Test lowercase accented characters
      # Latin small letter a with grave
      assert CharacterSets.translate(<<0xE0>>, :latin1) == "à"
      # Latin small letter a with acute
      assert CharacterSets.translate(<<0xE1>>, :latin1) == "á"
      # Latin small letter a with circumflex
      assert CharacterSets.translate(<<0xE2>>, :latin1) == "â"
      # Latin small letter a with tilde
      assert CharacterSets.translate(<<0xE3>>, :latin1) == "ã"
      # Latin small letter a with diaeresis
      assert CharacterSets.translate(<<0xE4>>, :latin1) == "ä"
      # Latin small letter a with ring above
      assert CharacterSets.translate(<<0xE5>>, :latin1) == "å"
    end

    test "handles unknown character sets" do
      # Test with an unknown character set
      assert CharacterSets.translate("A", :unknown) == "A"
    end

    test "handles US-ASCII character set" do
      # US-ASCII should return the character as is
      assert CharacterSets.translate("A", :us_ascii) == "A"
      assert CharacterSets.translate("a", :us_ascii) == "a"
      assert CharacterSets.translate("1", :us_ascii) == "1"
      assert CharacterSets.translate("!", :us_ascii) == "!"
    end
  end
end
