defmodule Raxol.UI.StyleProcessorTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.StyleProcessor

  describe "flatten_merged_style/4" do
    test "returns child style when no parent" do
      child = %{style: %{bold: true}, type: :text}
      result = StyleProcessor.flatten_merged_style(%{}, child, nil)
      assert result[:bold] == true
    end

    test "inherits text properties from parent" do
      parent = %{style: %{fg: :red, bold: true}}
      child = %{style: %{}, type: :text}

      result = StyleProcessor.flatten_merged_style(parent, child, nil)
      assert result[:fg] == :red
      assert result[:bold] == true
    end

    test "child style overrides parent" do
      parent = %{style: %{fg: :red, bold: true}}
      child = %{style: %{fg: :blue}, type: :text}

      result = StyleProcessor.flatten_merged_style(parent, child, nil)
      assert result[:fg] == :blue
      assert result[:bold] == true
    end

    test "does not inherit layout properties" do
      parent = %{style: %{fg: :red, padding: 5, border: :single, width: 100}}
      child = %{style: %{}, type: :text}

      result = StyleProcessor.flatten_merged_style(parent, child, nil)
      assert result[:fg] == :red
      refute Map.has_key?(result, :padding)
      refute Map.has_key?(result, :border)
      refute Map.has_key?(result, :width)
    end

    test "handles parent as flat style map" do
      parent = %{fg: :green, italic: true}
      child = %{style: %{}, type: :text}

      result = StyleProcessor.flatten_merged_style(parent, child, nil)
      assert result[:fg] == :green
      assert result[:italic] == true
    end

    test "handles nil parent gracefully" do
      child = %{style: %{fg: :blue}, type: :text}
      result = StyleProcessor.flatten_merged_style(nil, child, nil)
      assert result[:fg] == :blue
    end

    test "inherits all text styling properties" do
      parent = %{
        style: %{
          fg: :red,
          bg: :white,
          foreground: :red,
          background: :white,
          bold: true,
          italic: true,
          underline: true,
          strikethrough: true,
          reverse: true,
          dim: true
        }
      }

      child = %{style: %{}, type: :text}
      result = StyleProcessor.flatten_merged_style(parent, child, nil)

      assert result[:fg] == :red
      assert result[:bg] == :white
      assert result[:bold] == true
      assert result[:italic] == true
      assert result[:underline] == true
      assert result[:dim] == true
    end
  end

  describe "merge_styles_for_inheritance/3" do
    test "merges parent and child style maps" do
      parent = %{style: %{fg: :red, bold: true}}
      child = %{style: %{bg: :blue}}

      result = StyleProcessor.merge_styles_for_inheritance(parent, child)
      assert result.style[:fg] == :red
      assert result.style[:bg] == :blue
      assert result.style[:bold] == true
    end

    test "child overrides parent in merge" do
      parent = %{style: %{fg: :red}}
      child = %{style: %{fg: :blue}}

      result = StyleProcessor.merge_styles_for_inheritance(parent, child)
      assert result.style[:fg] == :blue
    end

    test "handles empty styles" do
      parent = %{style: %{}}
      child = %{style: %{}}

      result = StyleProcessor.merge_styles_for_inheritance(parent, child)
      assert result.style == %{}
    end

    test "promotes color keys to top level" do
      parent = %{style: %{foreground: :red}}
      child = %{style: %{}}

      result = StyleProcessor.merge_styles_for_inheritance(parent, child)
      assert result[:foreground] == :red
    end
  end

  describe "inherit_colors/4" do
    test "inherits fg from parent element" do
      child_style = %{}
      parent_element = %{foreground: :red, background: :blue}
      parent_style = %{}

      result = StyleProcessor.inherit_colors(child_style, parent_element, parent_style)
      assert result.fg == :red
      assert result.bg == :blue
    end

    test "child colors take precedence" do
      child_style = %{foreground: :green}
      parent_element = %{foreground: :red}
      parent_style = %{}

      result = StyleProcessor.inherit_colors(child_style, parent_element, parent_style)
      assert result.fg == :green
    end

    test "falls back through chain: child -> parent_element -> parent_style" do
      child_style = %{}
      parent_element = %{}
      parent_style = %{foreground: :yellow, background: :black}

      result = StyleProcessor.inherit_colors(child_style, parent_element, parent_style)
      assert result.fg == :yellow
      assert result.bg == :black
    end

    test "returns short fg/bg aliases" do
      child_style = %{fg: :cyan}
      parent_element = %{bg: :magenta}
      parent_style = %{}

      result = StyleProcessor.inherit_colors(child_style, parent_element, parent_style)
      assert result.fg_short == :cyan
      assert result.bg_short == :magenta
    end
  end

  describe "ensure_list/1" do
    test "wraps non-list in list" do
      assert StyleProcessor.ensure_list(:foo) == [:foo]
      assert StyleProcessor.ensure_list("bar") == ["bar"]
      assert StyleProcessor.ensure_list(42) == [42]
    end

    test "returns list as-is" do
      assert StyleProcessor.ensure_list([1, 2, 3]) == [1, 2, 3]
      assert StyleProcessor.ensure_list([]) == []
    end
  end

  describe "clear_cache/0" do
    test "does not crash when cache is unavailable" do
      # ETSCacheManager may not be running in test
      assert StyleProcessor.clear_cache() in [:ok, nil]
    end
  end
end
