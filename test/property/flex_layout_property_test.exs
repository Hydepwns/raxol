defmodule Raxol.Property.FlexLayoutTest do
  @moduledoc """
  Property tests for flex layout behavior.

  Bug (#215): Flex.row/column defaults align: :start instead of CSS spec's
  :stretch. This makes the || :stretch fallback in build_flex_attrs dead code,
  causing children to get content-width instead of parent-width on the cross
  axis. Result: space_between produces no spacing.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Raxol.Test.PropertyGenerators

  alias Raxol.Core.Renderer.View.Layout.Flex
  alias Raxol.UI.Layout.Engine
  alias Raxol.UI.TextMeasure

  # -- Property 7: Flex defaults match CSS spec --

  describe "Flex default align (#215 root cause)" do
    property "Flex.row/1 defaults align to :stretch" do
      check all(children <- flex_children_gen(1, 3), max_runs: 100) do
        flex = Flex.row(children: children)

        assert flex.align == :stretch,
               "Flex.row should default align to :stretch (CSS spec), got #{inspect(flex.align)}"
      end
    end

    property "Flex.column/1 defaults align to :stretch" do
      check all(children <- flex_children_gen(1, 3), max_runs: 100) do
        flex = Flex.column(children: children)

        assert flex.align == :stretch,
               "Flex.column should default align to :stretch (CSS spec), got #{inspect(flex.align)}"
      end
    end

    property "Flex.row/1 explicit align overrides default" do
      check all(
              children <- flex_children_gen(1, 3),
              align <- member_of([:start, :center, :end, :stretch]),
              max_runs: 200
            ) do
        flex = Flex.row(children: children, align: align)
        assert flex.align == align
      end
    end
  end

  # -- Property 8: space_between distributes gaps --

  describe "space_between produces spacing (#215 symptom)" do
    property "space_between with 2+ children in wide parent produces non-zero gaps" do
      check all(
              children <- flex_children_gen(2, 4),
              parent_width <- integer(80..200),
              max_runs: 300
            ) do
        flex = %{
          type: :flex,
          direction: :row,
          justify: :space_between,
          align: :stretch,
          gap: 0,
          wrap: false,
          style: [],
          children: children
        }

        elements =
          Engine.process_element(
            flex,
            layout_space(%{width: parent_width}),
            []
          )

        text_elements =
          elements
          |> Enum.filter(&(&1.type == :text))
          |> Enum.sort_by(& &1.x)

        if length(text_elements) >= 2 do
          xs = Enum.map(text_elements, & &1.x)

          # First child should be at or near left edge
          assert hd(xs) <= 2,
                 "space_between: first child should be at left edge, got x=#{hd(xs)}"

          # Children should be spread out, not bunched together
          gaps =
            xs
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.map(fn [a, b] -> b - a end)

          assert Enum.all?(gaps, &(&1 > 0)),
                 "space_between: children should have positive spacing, got gaps=#{inspect(gaps)}"

          # Last child should extend toward right edge (within reason)
          last_x = List.last(xs)

          assert last_x > div(parent_width, 2),
                 "space_between: last child at x=#{last_x} should be past midpoint of #{parent_width}-wide parent"
        end
      end
    end
  end

  # -- Property 9: stretch gives children parent cross-axis dimension --

  describe "align stretch cross-axis (#215 consequence)" do
    property "row children with align:stretch get full parent width allocated" do
      check all(
              children <- flex_children_gen(2, 3),
              parent_width <- integer(80..200),
              max_runs: 200
            ) do
        flex = %{
          type: :flex,
          direction: :row,
          justify: :space_between,
          align: :stretch,
          gap: 0,
          wrap: false,
          style: [],
          children: children
        }

        elements =
          Engine.process_element(
            flex,
            layout_space(%{width: parent_width}),
            []
          )

        text_elements =
          elements
          |> Enum.filter(&(&1.type == :text))
          |> Enum.sort_by(& &1.x)

        if length(text_elements) >= 2 do
          # With space_between and stretch, the total span should cover
          # most of the parent width
          min_x = hd(text_elements).x
          last_el = List.last(text_elements)
          max_x = last_el.x + TextMeasure.display_width(last_el.text)

          span = max_x - min_x

          assert span > div(parent_width, 2),
                 "stretched row children should span more than half the parent width (#{parent_width}), got span=#{span}"
        end
      end
    end
  end
end
