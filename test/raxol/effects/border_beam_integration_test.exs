defmodule Raxol.Effects.BorderBeamIntegrationTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Renderer.View.Components.Box
  alias Raxol.Core.Renderer.View.LayoutHelpers

  describe "prop-based DSL" do
    test "box stores border_beam hint when border_beam: true" do
      element = Box.new(border: :single, border_beam: true)

      assert [%{type: :border_beam}] = element.animation_hints
    end

    test "box with border_beam: false has empty animation_hints" do
      element = Box.new(border: :single, border_beam: false)

      assert element.animation_hints == []
    end

    test "box accepts border_beam_opts for variant customization" do
      element =
        Box.new(
          border: :single,
          border_beam: true,
          border_beam_opts: [variant: :ocean, duration: 3000]
        )

      assert [hint] = element.animation_hints
      assert hint.variant == :ocean
      assert hint.duration_ms == 3000
    end

    test "panel passes border_beam through to box" do
      element = LayoutHelpers.panel(border: :rounded, border_beam: true)

      assert [%{type: :border_beam}] = element.animation_hints
    end
  end
end
