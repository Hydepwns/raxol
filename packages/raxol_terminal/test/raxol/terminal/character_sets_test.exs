defmodule Raxol.Terminal.CharacterSetsTest do
  use ExUnit.Case
  # Keep this alias for state management if needed later
  # alias Raxol.Terminal.CharacterSets
  # Add alias for translation functions
  alias Raxol.Terminal.ANSI.CharacterTranslations

  setup do
    # Attempt to resize RenderingEngine buffer to minimize log output on failure.
    # This assumes RenderingEngine might be running and registered by this name.
    _ =
      GenServer.cast(
        Raxol.Core.Runtime.Rendering.Engine,
        {:update_size, %{width: 1, height: 1}}
      )

    :ok
  end

  describe "character set translation" do
    test "translates Latin-1 characters" do
      # Test control characters (use translate_string for consistency)
      assert CharacterTranslations.translate_string(<<0x00>>, :latin1) == <<0>>
      assert CharacterTranslations.translate_string(<<0x09>>, :latin1) == "\t"
      assert CharacterTranslations.translate_string(<<0x0A>>, :latin1) == "\n"
      assert CharacterTranslations.translate_string(<<0x0D>>, :latin1) == "\r"

      # Test special characters
      # Non-breaking space
      assert CharacterTranslations.translate_string(<<0xA0>>, :latin1) ==
               <<0xC2, 0xA0>>

      # Inverted exclamation mark
      assert CharacterTranslations.translate_string(<<0xA1>>, :latin1) == "¡"
      # Cent sign
      assert CharacterTranslations.translate_string(<<0xA2>>, :latin1) == "¢"
      # Pound sign
      assert CharacterTranslations.translate_string(<<0xA3>>, :latin1) == "£"
      # Currency sign
      assert CharacterTranslations.translate_string(<<0xA4>>, :latin1) == "¤"
      # Yen sign
      assert CharacterTranslations.translate_string(<<0xA5>>, :latin1) == "¥"

      # Test accented characters
      # Latin capital letter A with grave
      assert CharacterTranslations.translate_string(<<0xC0>>, :latin1) == "À"
      # Latin capital letter A with acute
      assert CharacterTranslations.translate_string(<<0xC1>>, :latin1) == "Á"
      # Latin capital letter A with circumflex
      assert CharacterTranslations.translate_string(<<0xC2>>, :latin1) == "Â"
      # Latin capital letter A with tilde
      assert CharacterTranslations.translate_string(<<0xC3>>, :latin1) == "Ã"
      # Latin capital letter A with diaeresis
      assert CharacterTranslations.translate_string(<<0xC4>>, :latin1) == "Ä"
      # Latin capital letter A with ring above
      assert CharacterTranslations.translate_string(<<0xC5>>, :latin1) == "Å"

      # Test lowercase accented characters
      # Latin small letter a with grave
      assert CharacterTranslations.translate_string(<<0xE0>>, :latin1) == "à"
      # Latin small letter a with acute
      assert CharacterTranslations.translate_string(<<0xE1>>, :latin1) == "á"
      # Latin small letter a with circumflex
      assert CharacterTranslations.translate_string(<<0xE2>>, :latin1) == "â"
      # Latin small letter a with tilde
      assert CharacterTranslations.translate_string(<<0xE3>>, :latin1) == "ã"
      # Latin small letter a with diaeresis
      assert CharacterTranslations.translate_string(<<0xE4>>, :latin1) == "ä"
      # Latin small letter a with ring above
      assert CharacterTranslations.translate_string(<<0xE5>>, :latin1) == "å"
    end

    test "handles unknown character sets" do
      # Test with an unknown character set
      assert CharacterTranslations.translate_string("A", :unknown) == "A"
    end

    test "handles US-ASCII character set" do
      # US-ASCII should return the character as is
      assert CharacterTranslations.translate_string("A", :us_ascii) == "A"
      assert CharacterTranslations.translate_string("a", :us_ascii) == "a"
      assert CharacterTranslations.translate_string("1", :us_ascii) == "1"
      assert CharacterTranslations.translate_string("!", :us_ascii) == "!"
    end
  end
end
