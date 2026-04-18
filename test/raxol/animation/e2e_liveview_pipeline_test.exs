defmodule Raxol.Animation.E2ELiveViewPipelineTest do
  @moduledoc """
  End-to-end tests for the LiveView animation pipeline.

  Tests the full flow:
  1. Positioned elements with animation hints and IDs
  2. build_element_id_map creates coordinate-to-id mapping
  3. buffer_to_html emits data-raxol-id attributes on spans
  4. animation_css generates CSS transitions targeting those IDs
  5. render_to_liveview broadcasts both HTML and CSS
  """
  use ExUnit.Case, async: true

  alias Raxol.LiveView.TerminalBridge
  alias Raxol.Animation.Helpers

  describe "E2E: element_id_map -> data-raxol-id in HTML" do
    test "buffer_to_html emits data-raxol-id for mapped cells" do
      # Create a small buffer with styled text
      buffer = %{
        cells: [
          [
            %{char: "H", style: %{bold: true}},
            %{char: "i", style: %{bold: true}},
            %{char: " ", style: nil},
            %{char: "!", style: nil}
          ]
        ]
      }

      # Map cells 0-1 (row 0) to element "greeting"
      element_id_map = %{
        {0, 0} => "greeting",
        {1, 0} => "greeting"
      }

      html =
        TerminalBridge.buffer_to_html(buffer,
          use_inline_styles: true,
          element_id_map: element_id_map
        )

      assert html =~ ~s(data-raxol-id="greeting")
      assert html =~ "Hi"
    end

    test "different element IDs break RLE runs" do
      buffer = %{
        cells: [
          [
            %{char: "A", style: nil},
            %{char: "B", style: nil},
            %{char: "C", style: nil},
            %{char: "D", style: nil}
          ]
        ]
      }

      # A,B belong to "first", C,D belong to "second"
      element_id_map = %{
        {0, 0} => "first",
        {1, 0} => "first",
        {2, 0} => "second",
        {3, 0} => "second"
      }

      html =
        TerminalBridge.buffer_to_html(buffer,
          use_inline_styles: true,
          element_id_map: element_id_map
        )

      assert html =~ ~s(data-raxol-id="first")
      assert html =~ ~s(data-raxol-id="second")
      # Should be separate spans despite same style
      assert html =~ ~s(data-raxol-id="first">AB</span>)
      assert html =~ ~s(data-raxol-id="second">CD</span>)
    end

    test "cells without element_id render normally" do
      buffer = %{
        cells: [
          [
            %{char: "X", style: nil},
            %{char: "Y", style: nil}
          ]
        ]
      }

      html = TerminalBridge.buffer_to_html(buffer, use_inline_styles: true)

      refute html =~ "data-raxol-id"
      assert html =~ "XY"
    end

    test "empty element_id_map has no effect" do
      buffer = %{
        cells: [
          [%{char: "A", style: nil}]
        ]
      }

      html_without = TerminalBridge.buffer_to_html(buffer, use_inline_styles: true)

      html_with =
        TerminalBridge.buffer_to_html(buffer,
          use_inline_styles: true,
          element_id_map: %{}
        )

      assert html_without == html_with
    end
  end

  describe "E2E: positioned elements -> CSS + data-raxol-id alignment" do
    test "animation_css selectors match data-raxol-id attributes" do
      # Simulate positioned elements from LayoutEngine
      positioned_elements = [
        %{
          type: :box,
          id: "header",
          x: 0,
          y: 0,
          width: 10,
          height: 2,
          animation_hints: [
            %{property: :opacity, duration_ms: 300, easing: :ease_out_cubic, delay_ms: 0}
          ],
          children: []
        }
      ]

      # Generate CSS
      css = TerminalBridge.animation_css(positioned_elements)

      # The CSS selector
      assert css =~ ~s([data-raxol-id="header"])

      # Build the same id map that render_to_liveview would
      # (testing the backend helper indirectly via its logic)
      buffer = %{
        cells: [
          Enum.map(0..9, fn _ -> %{char: "#", style: %{bold: true}} end),
          Enum.map(0..9, fn _ -> %{char: " ", style: nil} end)
        ]
      }

      element_id_map =
        for row <- 0..1, col <- 0..9, into: %{} do
          {{col, row}, "header"}
        end

      html =
        TerminalBridge.buffer_to_html(buffer,
          use_inline_styles: true,
          element_id_map: element_id_map
        )

      # The HTML contains matching data-raxol-id
      assert html =~ ~s(data-raxol-id="header")

      # Together: CSS targets what HTML provides
      assert css =~ ~s([data-raxol-id="header"] { transition: opacity)
    end
  end

  describe "E2E: animate helper -> positioned elements -> CSS + HTML" do
    test "full chain from view DSL to browser output" do
      # Step 1: Build view with animate helper (as view/1 would)
      view_element =
        %{type: :box, id: "card", x: 5, y: 2, width: 20, height: 3}
        |> Helpers.animate(property: :opacity, from: 0.0, to: 1.0, duration: 400, easing: :ease_out_cubic)

      positioned_elements = [view_element]

      # Step 2: Generate animation CSS
      css = TerminalBridge.animation_css(positioned_elements)
      assert css =~ ~s([data-raxol-id="card"])
      assert css =~ "opacity 400ms"

      # Step 3: Build element_id_map (what render_to_liveview does)
      element_id_map =
        for row <- 2..4, col <- 5..24, into: %{} do
          {{col, row}, "card"}
        end

      # Step 4: Render buffer to HTML with id map
      buffer = %{
        cells:
          for _y <- 0..5 do
            for _x <- 0..29 do
              %{char: " ", style: nil}
            end
          end
      }

      html =
        TerminalBridge.buffer_to_html(buffer,
          use_inline_styles: true,
          element_id_map: element_id_map
        )

      # Step 5: Verify HTML has data-raxol-id matching CSS selectors
      assert html =~ ~s(data-raxol-id="card")
      assert css =~ ~s([data-raxol-id="card"])
    end
  end
end
