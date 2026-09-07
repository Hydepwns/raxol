defmodule Raxol.UI.BorderRendererTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.BorderRenderer

  # `get_border_chars/1` is public API of a published package, and its accepted
  # set is documented twice: `@type border_style` and the comment above the
  # function. Delegating straight to `Raxol.UI.Theming.BorderChars.get/1`
  # widened it from five names to nine without either saying so, which is
  # invisible in every other test because the extra four simply started
  # returning glyphs where they had returned the `:none` set.
  @documented [:single, :double, :rounded, :ascii, :none]
  @not_accepted [:bold, :heavy, :dashed, :dashed_fine]

  describe "get_border_chars/1" do
    test "every documented style resolves to its own glyph set" do
      for style <- @documented -- [:none] do
        chars = BorderRenderer.get_border_chars(style)

        assert is_map(chars)

        refute chars == BorderRenderer.get_border_chars(:none),
               "#{inspect(style)} resolved to the :none set"
      end
    end

    test "a style outside the documented set falls back to :none" do
      none = BorderRenderer.get_border_chars(:none)

      for style <- @not_accepted do
        assert BorderRenderer.get_border_chars(style) == none,
               "#{inspect(style)} is not in @type border_style, so it must " <>
                 "fall back to :none rather than silently widening this " <>
                 "function's public contract"
      end
    end

    test "an unknown style falls back to :none rather than raising" do
      none = BorderRenderer.get_border_chars(:none)

      assert BorderRenderer.get_border_chars(:no_such_style) == none
      assert BorderRenderer.get_border_chars(nil) == none
    end
  end
end
