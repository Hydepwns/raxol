defmodule Raxol.UI.Theming.Ansi256AgreementTest do
  @moduledoc """
  The forward and reverse 256-color lookups must describe the same palette.

  `Raxol.UI.Theming.Colors.ansi_to_rgb/1` (index -> RGB) resolves through
  `Raxol.Style.Colors.Color.from_ansi/1` -> `Formats.ansi_to_rgb/1`, which
  computed the 6x6x6 cube as `n * 51`. `find_closest_256_color/1` (RGB ->
  index) searches `@ansi_216_colors`, built from the real xterm ramp
  `55 + n * 40`. The two therefore described different palettes: every cube
  index but the 8 that coincide with a basic color failed to round-trip, and
  no test noticed.

  Both sides now share `Raxol.Core.Colors.Ansi256`.
  """
  use ExUnit.Case, async: true

  alias Raxol.Style.Colors.Formats
  alias Raxol.UI.Theming.Colors

  # Cube indices whose RGB is byte-identical to one of the basic 16 colors.
  # `find_closest_256_color/1` searches basic colors first and legitimately
  # returns the lower index for these, so they cannot round-trip and are not
  # expected to.
  @basic_aliases [196, 201, 226, 231, 46, 51, 21, 16]

  # The 4 cube indices whose RGB is achromatic (`r == g == b`).
  # `Formats.rgb_to_ansi/1` routes those to the grayscale ramp, so they do not
  # round-trip to themselves -- true before the ramp move as well.
  @achromatic_cube [59, 102, 145, 188]

  describe "cube round-trip" do
    test "every cube index round-trips, except exact basic-color aliases" do
      mismatches =
        for index <- 16..231,
            index not in @basic_aliases,
            rgb = Colors.ansi_to_rgb(index),
            Colors.find_closest_256_color(rgb) != index,
            do: {index, rgb, Colors.find_closest_256_color(rgb)}

      assert mismatches == [],
             "forward and reverse lookups disagree for: #{inspect(mismatches)}"
    end

    test "the basic-color aliases resolve to their basic index, not the cube" do
      # Not incidental: these are the only indices where the cube duplicates a
      # basic color, and preferring the lower index is the intended behaviour.
      assert Colors.find_closest_256_color(Colors.ansi_to_rgb(231)) == 15
      assert Colors.find_closest_256_color(Colors.ansi_to_rgb(16)) == 0
    end
  end

  describe "forward lookup" do
    test "agrees with the shared table across the whole cube and ramp" do
      for index <- 16..255 do
        assert Colors.ansi_to_rgb(index) ==
                 Raxol.Core.Colors.Ansi256.to_rgb(index),
               "index #{index} disagrees with Raxol.Core.Colors.Ansi256"
      end
    end

    test "uses the xterm ramp, not the naive linear one" do
      assert Colors.ansi_to_rgb(17) == {0, 0, 95}
      refute Colors.ansi_to_rgb(17) == {0, 0, 51}
    end
  end

  # `Raxol.UI.Theming.Colors` is only ONE of the two reverse lookups.
  # `Formats.rgb_to_ansi/1` is the other, and the tests above cannot see it:
  # they never call it. It kept quantizing with `div(v * 6, 256)` -- the exact
  # inverse of the deleted `n * 51` ladder -- after `ansi_to_rgb/1` moved to
  # the xterm ramp, so the pair stopped round-tripping for 208 of 216 indices
  # while this file stayed green.
  describe "Formats is the other half of the same pair" do
    test "every cube index round-trips through rgb_to_ansi/ansi_to_rgb" do
      mismatches =
        for index <- 16..231,
            index not in @achromatic_cube,
            rgb = Formats.ansi_to_rgb(index),
            Formats.rgb_to_ansi(rgb) != index,
            do: {index, rgb, Formats.rgb_to_ansi(rgb)}

      assert mismatches == [],
             "Formats encode/decode disagree for: #{inspect(mismatches)}"
    end

    test "the achromatic cube entries prefer the nearer grayscale index" do
      # Unchanged from before the ramp move: the `r == g == b` branch has
      # always preferred the grayscale ramp, which is within 4 per channel.
      # Pinned so the exemption above stays honest rather than open-ended.
      for index <- @achromatic_cube do
        {v, v, v} = Formats.ansi_to_rgb(index)
        resolved = Formats.rgb_to_ansi({v, v, v})

        assert resolved in 232..255
        {r, _, _} = Formats.ansi_to_rgb(resolved)
        assert abs(r - v) <= 4
      end
    end

    test "quantizes to the xterm ramp, not the naive linear one" do
      # The concrete regression: Adaptive.adapt_color/1 composes exactly this
      # pair, so a full cube step of error lands on every adapted colour.
      assert Formats.rgb_to_ansi({95, 0, 0}) == 52
      refute Formats.rgb_to_ansi({95, 0, 0}) == 88

      assert Formats.ansi_to_rgb(17) == {0, 0, 95}
      assert Formats.rgb_to_ansi({0, 0, 95}) == 17
    end
  end
end
