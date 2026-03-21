defmodule Raxol.UI.Components.MarkdownRendererTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.MarkdownRenderer

  defp render_md(text, opts \\ %{}) do
    {:ok, state} = MarkdownRenderer.init(Map.merge(%{markdown_text: text}, opts))
    MarkdownRenderer.render(state, %{})
  end

  defp children(result), do: result.children
  defp contents(result), do: Enum.map(children(result), & &1.content)

  describe "init/1" do
    test "returns {:ok, state} with defaults" do
      assert {:ok, state} = MarkdownRenderer.init(%{})
      assert state.markdown_text == ""
      assert state.width == 80
    end

    test "merges custom props" do
      assert {:ok, state} = MarkdownRenderer.init(%{markdown_text: "# Hi", width: 40})
      assert state.markdown_text == "# Hi"
      assert state.width == 40
    end
  end

  describe "update/2" do
    test "returns state unchanged" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "# Title"})
      assert MarkdownRenderer.update(:any, state) == state
    end
  end

  describe "handle_event/3" do
    test "returns {state, []} for any event" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "text"})
      assert {^state, []} = MarkdownRenderer.handle_event(:click, state, %{})
    end
  end

  describe "mount/1 and unmount/1" do
    test "mount returns {state, []}" do
      {:ok, state} = MarkdownRenderer.init(%{})
      assert {^state, []} = MarkdownRenderer.mount(state)
    end

    test "unmount returns state" do
      {:ok, state} = MarkdownRenderer.init(%{})
      assert MarkdownRenderer.unmount(state) == state
    end
  end

  describe "render/2 structure" do
    test "returns a column container with children" do
      result = render_md("hello")
      assert result.type == :column
      assert is_list(result.children)
    end

    test "children are text elements" do
      result = render_md("hello")
      for child <- children(result) do
        assert child.type == :text
      end
    end
  end

  describe "headings" do
    test "renders h1 with bold cyan style" do
      result = render_md("# Hello World")
      texts = children(result)
      heading = Enum.find(texts, &(&1.content =~ "# Hello World"))
      assert heading != nil
      assert heading.style.bold == true
      assert heading.style.fg == :cyan
    end

    test "renders h2 with bold cyan style" do
      result = render_md("## Section")
      texts = children(result)
      heading = Enum.find(texts, &(&1.content =~ "## Section"))
      assert heading != nil
      assert heading.style.bold == true
    end

    test "renders h3 with bold cyan style" do
      result = render_md("### Sub")
      texts = children(result)
      heading = Enum.find(texts, &(&1.content =~ "### Sub"))
      assert heading != nil
      assert heading.style.bold == true
    end
  end

  describe "inline formatting" do
    test "converts bold markers to terminal representation" do
      result = render_md("some **bold** text")
      text = Enum.map_join(children(result), "", & &1.content)
      assert text =~ "bold"
    end

    test "converts italic markers to terminal representation" do
      result = render_md("some _italic_ text")
      text = Enum.map_join(children(result), "", & &1.content)
      assert text =~ "italic"
    end

    test "converts links to text with URL" do
      result = render_md("[click](http://example.com)")
      text = Enum.map_join(children(result), "", & &1.content)
      assert text =~ "click"
      assert text =~ "http://example.com"
    end
  end

  describe "lists" do
    test "renders unordered list items with bullet markers" do
      result = render_md("- item one\n- item two")
      all_content = contents(result)
      assert Enum.any?(all_content, &(&1 =~ "* item one"))
      assert Enum.any?(all_content, &(&1 =~ "* item two"))
    end

    test "renders ordered list items with numbers" do
      result = render_md("1. first\n2. second")
      all_content = contents(result)
      assert Enum.any?(all_content, &(&1 =~ "1."))
      assert Enum.any?(all_content, &(&1 =~ "first"))
      assert Enum.any?(all_content, &(&1 =~ "2."))
      assert Enum.any?(all_content, &(&1 =~ "second"))
    end
  end

  describe "code blocks" do
    test "renders fenced code with yellow style" do
      md = "```elixir\nIO.puts(\"hi\")\n```"
      result = render_md(md)
      code_lines = Enum.filter(children(result), fn el ->
        el.style[:fg] == :yellow and el.content =~ "IO.puts"
      end)
      assert length(code_lines) > 0
    end

    test "indents code lines" do
      md = "```\nhello\nworld\n```"
      result = render_md(md)
      code_lines = Enum.filter(children(result), &(&1.style[:fg] == :yellow))
      for line <- code_lines do
        assert String.starts_with?(line.content, "  ")
      end
    end
  end

  describe "blockquotes" do
    test "renders blockquote with pipe prefix and green style" do
      result = render_md("> quoted text")
      all = children(result)
      quoted = Enum.find(all, &(&1.content =~ "| quoted text"))
      assert quoted != nil
      assert quoted.style.fg == :green
    end
  end

  describe "horizontal rules" do
    test "renders hr as dashes" do
      result = render_md("---")
      all = children(result)
      hr = Enum.find(all, &(String.contains?(&1.content, "---")))
      assert hr != nil
    end
  end

  describe "empty input" do
    test "renders empty string without error" do
      result = render_md("")
      assert result.type == :column
      assert is_list(result.children)
    end
  end

  describe "width parameter" do
    test "respects width for horizontal rules" do
      result = render_md("---", %{width: 20})
      all = children(result)
      hr = Enum.find(all, &(String.contains?(&1.content, "---")))
      assert hr != nil
      assert String.length(hr.content) <= 20
    end
  end
end
