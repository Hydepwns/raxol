defmodule Raxol.Terminal.ANSI.CharacterTranslationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterTranslations

  describe "translate_char/2" do
    test "returns original character for us_ascii charset" do
      assert CharacterTranslations.translate_char(?a, :us_ascii) == ?a
      assert CharacterTranslations.translate_char(?A, :us_ascii) == ?A
      assert CharacterTranslations.translate_char(?1, :us_ascii) == ?1
      assert CharacterTranslations.translate_char(?@, :us_ascii) == ?@
    end

    test "translates pound symbol in uk charset" do
      assert CharacterTranslations.translate_char(0x23, :uk) == ?£
      assert CharacterTranslations.translate_char(?a, :uk) == ?a
    end

    test "translates French-specific characters" do
      assert CharacterTranslations.translate_char(0x23, :french) == ?£
      assert CharacterTranslations.translate_char(0x40, :french) == ?à
      assert CharacterTranslations.translate_char(0x5B, :french) == ?é
      assert CharacterTranslations.translate_char(0x5C, :french) == ?ê
      assert CharacterTranslations.translate_char(0x5D, :french) == ?è
      assert CharacterTranslations.translate_char(0x5E, :french) == ?ë
      assert CharacterTranslations.translate_char(0x5F, :french) == ?ï
      assert CharacterTranslations.translate_char(0x60, :french) == ?î
      assert CharacterTranslations.translate_char(0x7B, :french) == ?ù
      assert CharacterTranslations.translate_char(0x7C, :french) == ?ô
      assert CharacterTranslations.translate_char(0x7D, :french) == ?è
      assert CharacterTranslations.translate_char(0x7E, :french) == ?û
    end

    test "translates German-specific characters" do
      assert CharacterTranslations.translate_char(0x5B, :german) == ?Ä
      assert CharacterTranslations.translate_char(0x5C, :german) == ?Ö
      assert CharacterTranslations.translate_char(0x5D, :german) == ?Ü
      assert CharacterTranslations.translate_char(0x5E, :german) == ?^
      assert CharacterTranslations.translate_char(0x5F, :german) == ?_
      assert CharacterTranslations.translate_char(0x60, :german) == ?`
      assert CharacterTranslations.translate_char(0x7B, :german) == ?ä
      assert CharacterTranslations.translate_char(0x7C, :german) == ?ö
      assert CharacterTranslations.translate_char(0x7D, :german) == ?ü
      assert CharacterTranslations.translate_char(0x7E, :german) == ?ß
    end

    test "translates Latin-1 specific characters" do
      # Non-breaking space
      assert CharacterTranslations.translate_char(0xA0, :latin1) == ?\ 
      assert CharacterTranslations.translate_char(0xA1, :latin1) == ?¡
      assert CharacterTranslations.translate_char(0xA2, :latin1) == ?¢
      assert CharacterTranslations.translate_char(0xA3, :latin1) == ?£
      assert CharacterTranslations.translate_char(0xC0, :latin1) == ?À
      assert CharacterTranslations.translate_char(0xC1, :latin1) == ?Á
      assert CharacterTranslations.translate_char(0xE0, :latin1) == ?à
      assert CharacterTranslations.translate_char(0xE1, :latin1) == ?á
      assert CharacterTranslations.translate_char(0xFF, :latin1) == ?ÿ
    end

    test "returns original character for unsupported charset" do
      assert CharacterTranslations.translate_char(?a, :unsupported) == ?a
    end
  end

  describe "translate_string/2" do
    test "translates string using French charset" do
      assert CharacterTranslations.translate_string("Hello", :french) == "Hello"
      assert CharacterTranslations.translate_string("café", :french) == "café"
    end

    test "translates string using German charset" do
      assert CharacterTranslations.translate_string("Hello", :german) == "Hello"

      assert CharacterTranslations.translate_string("München", :german) ==
               "München"
    end

    test "translates string using Latin-1 charset" do
      assert CharacterTranslations.translate_string("Hello", :latin1) == "Hello"
      assert CharacterTranslations.translate_string("café", :latin1) == "café"
    end
  end
end
