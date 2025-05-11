defmodule Raxol.Terminal.ANSI.CharacterTranslationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.CharacterTranslations

  describe "translate_char/2" do
    test "returns original character for us_ascii charset" do
      assert CharacterTranslations.translate_char(?a, :us_ascii) == <<0x61::utf8>>
      assert CharacterTranslations.translate_char(?A, :us_ascii) == <<0x41::utf8>>
      assert CharacterTranslations.translate_char(?1, :us_ascii) == <<0x31::utf8>>
      assert CharacterTranslations.translate_char(?@, :us_ascii) == <<0x40::utf8>>
    end

    test "translates pound symbol in uk charset" do
      assert CharacterTranslations.translate_char(0x23, :uk) == <<0x23::utf8>>
      assert CharacterTranslations.translate_char(?a, :uk) == <<0x61::utf8>>
    end

    test "translates French-specific characters" do
      assert CharacterTranslations.translate_char(0x23, :french) == <<0x23::utf8>>
      assert CharacterTranslations.translate_char(0x40, :french) == <<0x40::utf8>>
      assert CharacterTranslations.translate_char(0x5B, :french) == <<0x5B::utf8>>
      assert CharacterTranslations.translate_char(0x5C, :french) == <<0x5C::utf8>>
      assert CharacterTranslations.translate_char(0x5D, :french) == <<0x5D::utf8>>
      assert CharacterTranslations.translate_char(0x5E, :french) == <<0x5E::utf8>>
      assert CharacterTranslations.translate_char(0x5F, :french) == <<0x5F::utf8>>
      assert CharacterTranslations.translate_char(0x60, :french) == <<0x60::utf8>>
      assert CharacterTranslations.translate_char(0x7B, :french) == <<0x7B::utf8>>
      assert CharacterTranslations.translate_char(0x7C, :french) == <<0x7C::utf8>>
      assert CharacterTranslations.translate_char(0x7D, :french) == <<0x7D::utf8>>
      assert CharacterTranslations.translate_char(0x7E, :french) == <<0x7E::utf8>>
    end

    test "translates German-specific characters" do
      assert CharacterTranslations.translate_char(0x5B, :german) == <<0x5B::utf8>>
      assert CharacterTranslations.translate_char(0x5C, :german) == <<0x5C::utf8>>
      assert CharacterTranslations.translate_char(0x5D, :german) == <<0x5D::utf8>>
      assert CharacterTranslations.translate_char(0x7B, :german) == <<0x7B::utf8>>
      assert CharacterTranslations.translate_char(0x7C, :german) == <<0x7C::utf8>>
      assert CharacterTranslations.translate_char(0x7D, :german) == <<0x7D::utf8>>
      assert CharacterTranslations.translate_char(0x7E, :german) == <<0x7E::utf8>>
    end

    test "translates Latin-1 specific characters" do
      assert CharacterTranslations.translate_char(0xA0, :latin1) == <<0xA0::utf8>>
      assert CharacterTranslations.translate_char(0xA1, :latin1) == <<0xA1::utf8>>
      assert CharacterTranslations.translate_char(0xA2, :latin1) == <<0xA2::utf8>>
      assert CharacterTranslations.translate_char(0xA3, :latin1) == <<0xA3::utf8>>
      assert CharacterTranslations.translate_char(0xA4, :latin1) == <<0xA4::utf8>>
      assert CharacterTranslations.translate_char(0xA5, :latin1) == <<0xA5::utf8>>
    end

    test "handles invalid characters gracefully" do
      assert CharacterTranslations.translate_char(0x80, :us_ascii) == <<0x80::utf8>>
      assert CharacterTranslations.translate_char(0xFF, :latin1) == <<0xFF::utf8>>
    end
  end

  describe "translate_string/2" do
    test "translates string using French charset" do
      assert CharacterTranslations.translate_string("Hello", :french) == "Hello"
      assert CharacterTranslations.translate_string("café", :french) == "café"
      assert CharacterTranslations.translate_string("àéèêëîïôùû", :french) == "àéèêëîïôùû"
    end

    test "translates string using German charset" do
      assert CharacterTranslations.translate_string("Hello", :german) == "Hello"
      assert CharacterTranslations.translate_string("München", :german) == "München"
      assert CharacterTranslations.translate_string("ÄÖÜäöüß", :german) == "ÄÖÜäöüß"
    end

    test "translates string using Latin-1 charset" do
      assert CharacterTranslations.translate_string("Hello", :latin1) == "Hello"
      assert CharacterTranslations.translate_string("café", :latin1) == "café"
      assert CharacterTranslations.translate_string("£¥©®", :latin1) == "£¥©®"
    end

    test "handles empty strings" do
      assert CharacterTranslations.translate_string("", :us_ascii) == ""
      assert CharacterTranslations.translate_string("", :french) == ""
      assert CharacterTranslations.translate_string("", :german) == ""
      assert CharacterTranslations.translate_string("", :latin1) == ""
    end

    test "handles strings with invalid characters" do
      assert CharacterTranslations.translate_string("Hello\x80World", :us_ascii) == "Hello\x80World"
      assert CharacterTranslations.translate_string("Hello\xFFWorld", :latin1) == "Hello\xFFWorld"
    end
  end
end
