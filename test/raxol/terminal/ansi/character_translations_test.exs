defmodule Raxol.Terminal.ANSI.CharacterTranslationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterTranslations

  describe "translate_char/2" do
    test ~c"returns original character for us_ascii charset" do
      assert CharacterTranslations.translate_char(?a, :us_ascii) ==
               <<0x61::utf8>>

      assert CharacterTranslations.translate_char(?A, :us_ascii) ==
               <<0x41::utf8>>

      assert CharacterTranslations.translate_char(?1, :us_ascii) ==
               <<0x31::utf8>>

      assert CharacterTranslations.translate_char(?@, :us_ascii) ==
               <<0x40::utf8>>
    end

    test ~c"translates pound symbol in uk charset" do
      assert CharacterTranslations.translate_char(0x23, :uk) == <<0xA3::utf8>>
      assert CharacterTranslations.translate_char(?a, :uk) == <<0x61::utf8>>
    end

    test ~c"translates French-specific characters" do
      assert CharacterTranslations.translate_char(0x23, :french) ==
               <<0xA3::utf8>>

      assert CharacterTranslations.translate_char(0x40, :french) ==
               <<0xE0::utf8>>

      assert CharacterTranslations.translate_char(0x5B, :french) ==
               <<0xB0::utf8>>

      assert CharacterTranslations.translate_char(0x5C, :french) ==
               <<0xE7::utf8>>

      assert CharacterTranslations.translate_char(0x5D, :french) ==
               <<0xA7::utf8>>

      assert CharacterTranslations.translate_char(0x5E, :french) ==
               <<0x5E::utf8>>

      assert CharacterTranslations.translate_char(0x5F, :french) ==
               <<0x5F::utf8>>

      assert CharacterTranslations.translate_char(0x60, :french) ==
               <<0x60::utf8>>

      assert CharacterTranslations.translate_char(0x7B, :french) ==
               <<0xE9::utf8>>

      assert CharacterTranslations.translate_char(0x7C, :french) ==
               <<0xF9::utf8>>

      assert CharacterTranslations.translate_char(0x7D, :french) ==
               <<0xE8::utf8>>

      assert CharacterTranslations.translate_char(0x7E, :french) ==
               <<0xF9::utf8>>
    end

    test ~c"translates German-specific characters" do
      assert CharacterTranslations.translate_char(0x5B, :german) ==
               <<0xC4::utf8>>

      assert CharacterTranslations.translate_char(0x5C, :german) ==
               <<0xD6::utf8>>

      assert CharacterTranslations.translate_char(0x5D, :german) ==
               <<0xDC::utf8>>

      assert CharacterTranslations.translate_char(0x7B, :german) ==
               <<0xE4::utf8>>

      assert CharacterTranslations.translate_char(0x7C, :german) ==
               <<0xF6::utf8>>

      assert CharacterTranslations.translate_char(0x7D, :german) ==
               <<0xFC::utf8>>

      assert CharacterTranslations.translate_char(0x7E, :german) ==
               <<0xDF::utf8>>
    end

    test ~c"translates Latin-1 specific characters" do
      assert CharacterTranslations.translate_char(0xA0, :latin1) ==
               <<0xA0::utf8>>

      assert CharacterTranslations.translate_char(0xA1, :latin1) ==
               <<0xA1::utf8>>

      assert CharacterTranslations.translate_char(0xA2, :latin1) ==
               <<0xA2::utf8>>

      assert CharacterTranslations.translate_char(0xA3, :latin1) ==
               <<0xA3::utf8>>

      assert CharacterTranslations.translate_char(0xA4, :latin1) ==
               <<0xA4::utf8>>

      assert CharacterTranslations.translate_char(0xA5, :latin1) ==
               <<0xA5::utf8>>
    end

    test ~c"handles invalid characters gracefully" do
      assert CharacterTranslations.translate_char(0x80, :us_ascii) ==
               <<0x80::utf8>>

      assert CharacterTranslations.translate_char(0xFF, :latin1) ==
               <<0xFF::utf8>>
    end
  end

  describe "translate_string/2" do
    test ~c"translates string using French charset" do
      assert CharacterTranslations.translate_string("Hello", :french) == "Hello"
      assert CharacterTranslations.translate_string("café", :french) == "café"

      assert CharacterTranslations.translate_string("àéèêëîïôùû", :french) ==
               "àéèêëîïôùû"
    end

    test ~c"translates string using German charset" do
      assert CharacterTranslations.translate_string("Hello", :german) == "Hello"

      assert CharacterTranslations.translate_string("München", :german) ==
               "München"

      assert CharacterTranslations.translate_string("ÄÖÜäöüß", :german) ==
               "ÄÖÜäöüß"
    end

    test ~c"translates string using Latin-1 charset" do
      assert CharacterTranslations.translate_string("Hello", :latin1) == "Hello"
      assert CharacterTranslations.translate_string("café", :latin1) == "café"
      assert CharacterTranslations.translate_string("£¥©®", :latin1) == "£¥©®"
    end

    test ~c"handles empty strings" do
      assert CharacterTranslations.translate_string("", :us_ascii) == ""
      assert CharacterTranslations.translate_string("", :french) == ""
      assert CharacterTranslations.translate_string("", :german) == ""
      assert CharacterTranslations.translate_string("", :latin1) == ""
    end

    test ~c"handles strings with invalid characters" do
      # Test with valid UTF-8 string containing non-ASCII characters
      result1 =
        CharacterTranslations.translate_string("Hello€World", :us_ascii)

      # Non-ASCII characters should be preserved as UTF-8
      assert result1 == "Hello€World"

      # Test translation with a character that can be translated
      result2 =
        CharacterTranslations.translate_string("Hello#World", :uk)

      # # should be translated to £ in UK character set
      assert result2 =~ "£"
    end
  end
end
