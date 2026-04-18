defmodule Raxol.Animation.HelpersTest do
  use ExUnit.Case, async: true

  alias Raxol.Animation.Helpers
  alias Raxol.Animation.Hint

  describe "animate/2" do
    test "attaches a hint to an element" do
      element = %{type: :box, children: []}

      result = Helpers.animate(element, property: :opacity, to: 1.0)

      assert [%Hint{} = hint] = result.animation_hints
      assert hint.property == :opacity
      assert hint.to == 1.0
      assert hint.duration_ms == 300
      assert hint.easing == :ease_out_cubic
      assert hint.delay_ms == 0
    end

    test "uses custom options" do
      element = %{type: :text, content: "hello"}

      result =
        Helpers.animate(element,
          property: :color,
          from: :red,
          to: :blue,
          duration: 500,
          easing: :ease_in_out_cubic,
          delay: 100
        )

      assert [%Hint{} = hint] = result.animation_hints
      assert hint.property == :color
      assert hint.from == :red
      assert hint.to == :blue
      assert hint.duration_ms == 500
      assert hint.easing == :ease_in_out_cubic
      assert hint.delay_ms == 100
    end

    test "composes multiple hints via piping" do
      element =
        %{type: :box, children: []}
        |> Helpers.animate(property: :opacity, to: 1.0)
        |> Helpers.animate(property: :color, to: :cyan, duration: 200)

      assert length(element.animation_hints) == 2

      [color_hint, opacity_hint] = element.animation_hints
      assert opacity_hint.property == :opacity
      assert color_hint.property == :color
      assert color_hint.duration_ms == 200
    end

    test "preserves existing element fields" do
      element = %{
        type: :box,
        children: [],
        style: %{border: :single},
        id: "my-box"
      }

      result = Helpers.animate(element, property: :opacity, to: 1.0)

      assert result.type == :box
      assert result.children == []
      assert result.style == %{border: :single}
      assert result.id == "my-box"
    end

    test "requires :property option" do
      element = %{type: :box}

      assert_raise KeyError, ~r/key :property not found/, fn ->
        Helpers.animate(element, to: 1.0)
      end
    end

    test "works with elements that already have animation_hints" do
      element = %{
        type: :box,
        animation_hints: [%Hint{property: :width, to: 100}]
      }

      result = Helpers.animate(element, property: :height, to: 50)

      assert length(result.animation_hints) == 2
    end
  end

  describe "stagger/2" do
    test "applies incrementing delays across elements" do
      elements = [
        %{type: :box, id: "a"},
        %{type: :box, id: "b"},
        %{type: :box, id: "c"}
      ]

      result = Helpers.stagger(elements, property: :opacity, to: 1.0, duration: 300)

      assert length(result) == 3
      [a, b, c] = result

      [hint_a] = a.animation_hints
      [hint_b] = b.animation_hints
      [hint_c] = c.animation_hints

      assert hint_a.delay_ms == 0
      assert hint_b.delay_ms == 50
      assert hint_c.delay_ms == 100
    end

    test "uses custom offset" do
      elements = [%{type: :box}, %{type: :box}]
      [a, b] = Helpers.stagger(elements, property: :opacity, to: 1.0, offset: 200)

      assert hd(a.animation_hints).delay_ms == 0
      assert hd(b.animation_hints).delay_ms == 200
    end

    test "adds base delay to all elements" do
      elements = [%{type: :box}, %{type: :box}]
      [a, b] = Helpers.stagger(elements, property: :opacity, to: 1.0, delay: 100, offset: 50)

      assert hd(a.animation_hints).delay_ms == 100
      assert hd(b.animation_hints).delay_ms == 150
    end

    test "handles empty list" do
      assert Helpers.stagger([], property: :opacity, to: 1.0) == []
    end

    test "handles single element" do
      [result] = Helpers.stagger([%{type: :box}], property: :opacity, to: 1.0)
      assert hd(result.animation_hints).delay_ms == 0
    end
  end

  describe "sequence/2" do
    test "chains animations with cumulative delays" do
      result =
        %{type: :box}
        |> Helpers.sequence([
          [property: :opacity, to: 1.0, duration: 300],
          [property: :bg, to: :cyan, duration: 200],
          [property: :width, to: 40, duration: 400]
        ])

      assert length(result.animation_hints) == 3

      # Hints are prepended, so last added is first in list
      [width, bg, opacity] = result.animation_hints
      assert opacity.delay_ms == 0
      assert bg.delay_ms == 300
      assert width.delay_ms == 500
    end

    test "respects per-animation base delay" do
      result =
        %{type: :box}
        |> Helpers.sequence([
          [property: :opacity, to: 1.0, duration: 200],
          [property: :bg, to: :cyan, duration: 100, delay: 50]
        ])

      [bg, opacity] = result.animation_hints
      assert opacity.delay_ms == 0
      # 200 (first duration) + 50 (second base delay)
      assert bg.delay_ms == 250
    end

    test "handles single animation" do
      result =
        %{type: :box}
        |> Helpers.sequence([[property: :opacity, to: 1.0, duration: 500]])

      assert [hint] = result.animation_hints
      assert hint.delay_ms == 0
      assert hint.duration_ms == 500
    end

    test "handles empty animation list" do
      element = %{type: :box}
      assert Helpers.sequence(element, []) == element
    end
  end
end
