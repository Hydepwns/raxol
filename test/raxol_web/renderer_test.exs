defmodule RaxolWeb.RendererTest do
  use ExUnit.Case, async: true

  alias RaxolWeb.Renderer

  @moduletag :raxol_web

  describe "new/0" do
    test "creates a new renderer with empty state" do
      renderer = Renderer.new()

      assert renderer.html_char_cache != %{}
      assert renderer.style_class_cache == %{}
      assert renderer.previous_buffer == nil
      assert renderer.previous_html == nil
      assert renderer.render_count == 0
      assert renderer.cache_hits == 0
      assert renderer.cache_misses == 0
    end

    test "pre-populates character cache with common chars" do
      renderer = Renderer.new()

      # Check that common characters are cached
      default_style = %{
        bold: false,
        italic: false,
        underline: false,
        reverse: false,
        fg_color: nil,
        bg_color: nil
      }

      cache_key = {" ", default_style}
      assert Map.has_key?(renderer.html_char_cache, cache_key)
    end
  end

  describe "render/2" do
    test "renders a simple buffer on first call" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "H", style: %{bold: false, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, new_renderer} = Renderer.render(renderer, buffer)

      assert is_binary(html)
      assert html =~ "raxol-terminal"
      assert html =~ "raxol-line"
      assert html =~ "raxol-cell"
      assert html =~ "H"
      assert new_renderer.render_count == 1
      assert new_renderer.previous_buffer == buffer
      assert new_renderer.previous_html == html
    end

    test "returns cached HTML when buffer unchanged" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "A", style: %{bold: false, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html1, renderer2} = Renderer.render(renderer, buffer)
      {html2, renderer3} = Renderer.render(renderer2, buffer)

      assert html1 == html2
      assert renderer3.render_count == 1
    end

    test "re-renders when buffer changes" do
      renderer = Renderer.new()

      buffer1 = %{
        lines: [
          %{cells: [%{char: "A", style: %{bold: false, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      buffer2 = %{
        lines: [
          %{cells: [%{char: "B", style: %{bold: false, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html1, renderer2} = Renderer.render(renderer, buffer1)
      {html2, renderer3} = Renderer.render(renderer2, buffer2)

      assert html1 != html2
      assert html1 =~ "A"
      assert html2 =~ "B"
      assert renderer3.render_count == 2
    end

    test "renders multiple lines correctly" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]},
          %{cells: [%{char: "B", style: %{}}]},
          %{cells: [%{char: "C", style: %{}}]}
        ],
        width: 1,
        height: 3
      }

      {html, _} = Renderer.render(renderer, buffer)

      assert html =~ "A"
      assert html =~ "B"
      assert html =~ "C"

      # Should have 3 line divs
      line_count = html |> String.split("raxol-line") |> length() |> Kernel.-(1)
      assert line_count == 3
    end

    test "handles empty buffer" do
      renderer = Renderer.new()

      buffer = %{lines: [], width: 0, height: 0}

      {html, new_renderer} = Renderer.render(renderer, buffer)

      assert is_binary(html)
      assert html =~ "raxol-terminal"
      assert new_renderer.render_count == 1
    end

    test "renders styled cells with CSS classes" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{
            cells: [
              %{
                char: "X",
                style: %{
                  bold: true,
                  italic: false,
                  underline: false,
                  reverse: false,
                  fg_color: :red,
                  bg_color: nil
                }
              }
            ]
          }
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)

      assert html =~ "raxol-bold"
      assert html =~ "raxol-fg-red"
    end

    test "escapes HTML special characters" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "<", style: %{}}]},
          %{cells: [%{char: ">", style: %{}}]},
          %{cells: [%{char: "&", style: %{}}]},
          %{cells: [%{char: "\"", style: %{}}]}
        ],
        width: 1,
        height: 4
      }

      {html, _} = Renderer.render(renderer, buffer)

      # Verify special chars are escaped as entities in span content
      assert html =~ ">&lt;</span>"
      assert html =~ ">&gt;</span>"
      assert html =~ ">&amp;</span>"
      assert html =~ ">&quot;</span>"
    end
  end

  describe "stats/1" do
    test "returns performance statistics" do
      renderer = Renderer.new()

      stats = Renderer.stats(renderer)

      assert stats.render_count == 0
      assert stats.cache_hits == 0
      assert stats.cache_misses == 0
      assert stats.hit_ratio == 0.0
    end

    test "tracks cache hit ratio correctly" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: " ", style: %{bold: false, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {_, new_renderer} = Renderer.render(renderer, buffer)
      stats = Renderer.stats(new_renderer)

      assert stats.render_count == 1
      assert stats.cache_hits > 0 || stats.cache_misses > 0
      assert stats.hit_ratio >= 0.0 and stats.hit_ratio <= 1.0
    end
  end

  describe "invalidate_cache/1" do
    test "clears all cached data" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]}
        ],
        width: 1,
        height: 1
      }

      {_, renderer_with_cache} = Renderer.render(renderer, buffer)
      invalidated = Renderer.invalidate_cache(renderer_with_cache)

      assert invalidated.previous_buffer == nil
      assert invalidated.previous_html == nil
      assert invalidated.html_char_cache != %{}
      assert invalidated.style_class_cache == %{}
    end

    test "forces re-render after cache invalidation" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]}
        ],
        width: 1,
        height: 1
      }

      {html1, renderer2} = Renderer.render(renderer, buffer)
      renderer3 = Renderer.invalidate_cache(renderer2)
      {html2, renderer4} = Renderer.render(renderer3, buffer)

      assert html1 == html2
      assert renderer4.render_count == 2
    end
  end

  describe "caching behavior" do
    test "caches common characters for performance" do
      renderer = Renderer.new()

      # Create buffer with common characters that should be cached
      common_chars = [" ", "a", "e", "i", "o", "0", "1", "-", "|"]

      buffer = %{
        lines:
          Enum.map(common_chars, fn char ->
            %{
              cells: [
                %{
                  char: char,
                  style: %{
                    bold: false,
                    italic: false,
                    underline: false,
                    reverse: false,
                    fg_color: nil,
                    bg_color: nil
                  }
                }
              ]
            }
          end),
        width: 1,
        height: length(common_chars)
      }

      {_, new_renderer} = Renderer.render(renderer, buffer)
      stats = Renderer.stats(new_renderer)

      # Should have high cache hit ratio for common chars
      assert stats.cache_hits > 0
      assert stats.hit_ratio > 0.5
    end

    test "handles cache misses for uncommon char/style combinations" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{
            cells: [
              %{
                char: "🎨",
                style: %{
                  bold: true,
                  italic: true,
                  underline: true,
                  reverse: true,
                  fg_color: :bright_magenta,
                  bg_color: :cyan
                }
              }
            ]
          }
        ],
        width: 1,
        height: 1
      }

      {_, new_renderer} = Renderer.render(renderer, buffer)
      stats = Renderer.stats(new_renderer)

      # Should register cache misses for uncommon combinations
      assert stats.cache_misses > 0
    end
  end

  describe "virtual DOM diffing" do
    test "detects changed lines efficiently" do
      renderer = Renderer.new()

      buffer1 = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]},
          %{cells: [%{char: "B", style: %{}}]},
          %{cells: [%{char: "C", style: %{}}]}
        ],
        width: 1,
        height: 3
      }

      buffer2 = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]},
          %{cells: [%{char: "X", style: %{}}]},
          %{cells: [%{char: "C", style: %{}}]}
        ],
        width: 1,
        height: 3
      }

      {html1, renderer2} = Renderer.render(renderer, buffer1)
      {html2, _renderer3} = Renderer.render(renderer2, buffer2)

      assert html1 != html2
      assert html2 =~ "X"
      refute html2 =~ "B"
    end

    test "handles buffer with different sizes" do
      renderer = Renderer.new()

      buffer1 = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]}
        ],
        width: 1,
        height: 1
      }

      buffer2 = %{
        lines: [
          %{cells: [%{char: "A", style: %{}}]},
          %{cells: [%{char: "B", style: %{}}]}
        ],
        width: 1,
        height: 2
      }

      {html1, renderer2} = Renderer.render(renderer, buffer1)
      {html2, _} = Renderer.render(renderer2, buffer2)

      assert html1 != html2

      line_count1 = html1 |> String.split("raxol-line") |> length() |> Kernel.-(1)
      line_count2 = html2 |> String.split("raxol-line") |> length() |> Kernel.-(1)

      assert line_count1 == 1
      assert line_count2 == 2
    end
  end

  describe "style class generation" do
    test "generates correct classes for bold" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "B", style: %{bold: true, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-bold"
    end

    test "generates correct classes for italic" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "I", style: %{italic: true, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-italic"
    end

    test "generates correct classes for underline" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "U", style: %{underline: true, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-underline"
    end

    test "generates correct classes for reverse" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "R", style: %{reverse: true, fg_color: nil, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-reverse"
    end

    test "generates correct classes for foreground colors" do
      renderer = Renderer.new()

      colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

      for color <- colors do
        buffer = %{
          lines: [
            %{cells: [%{char: "C", style: %{fg_color: color, bg_color: nil}}]}
          ],
          width: 1,
          height: 1
        }

        {html, _} = Renderer.render(renderer, buffer)
        assert html =~ "raxol-fg-#{color}"
      end
    end

    test "generates correct classes for background colors" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "C", style: %{fg_color: nil, bg_color: :blue}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-bg-blue"
    end

    test "generates correct classes for bright colors" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "C", style: %{fg_color: :bright_red, bg_color: nil}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-fg-bright-red"
    end

    test "combines multiple style classes" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{
            cells: [
              %{
                char: "M",
                style: %{bold: true, underline: true, fg_color: :red, bg_color: :black}
              }
            ]
          }
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "raxol-bold"
      assert html =~ "raxol-underline"
      assert html =~ "raxol-fg-red"
      assert html =~ "raxol-bg-black"
    end
  end

  describe "edge cases" do
    test "handles nil style values gracefully" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: "N", style: %{}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert is_binary(html)
      assert html =~ "N"
    end

    test "handles very long lines" do
      renderer = Renderer.new()

      cells = Enum.map(1..1000, fn _ -> %{char: "X", style: %{}} end)

      buffer = %{
        lines: [%{cells: cells}],
        width: 1000,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert is_binary(html)

      # Count Xs in output
      x_count = html |> String.graphemes() |> Enum.count(&(&1 == "X"))
      assert x_count == 1000
    end

    test "handles box-drawing characters" do
      renderer = Renderer.new()

      box_chars = ["┌", "┐", "└", "┘", "─", "│", "█"]

      buffer = %{
        lines:
          Enum.map(box_chars, fn char ->
            %{cells: [%{char: char, style: %{}}]}
          end),
        width: 1,
        height: length(box_chars)
      }

      {html, _} = Renderer.render(renderer, buffer)

      for char <- box_chars do
        assert html =~ char
      end
    end

    test "handles nbsp for spaces correctly" do
      renderer = Renderer.new()

      buffer = %{
        lines: [
          %{cells: [%{char: " ", style: %{}}]}
        ],
        width: 1,
        height: 1
      }

      {html, _} = Renderer.render(renderer, buffer)
      assert html =~ "&nbsp;"
    end
  end
end
