defmodule Raxol.UI.Components.Display.TextTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Text

  @context %{theme: %{}}

  describe "init/1" do
    test "sets defaults" do
      {:ok, state} = Text.init([])
      assert state.content == ""
      assert state.wrap == :none
      assert state.align == :left
      assert state.width == nil
      assert state.truncate == false
      assert state.style == %{}
      assert state.theme == %{}
    end

    test "accepts provided props" do
      {:ok, state} =
        Text.init(
          content: "hello",
          wrap: :word,
          align: :center,
          width: 20,
          truncate: true,
          id: "my-text",
          style: %{bold: true},
          theme: %{fg: :red}
        )

      assert state.content == "hello"
      assert state.wrap == :word
      assert state.align == :center
      assert state.width == 20
      assert state.truncate == true
      assert state.id == "my-text"
      assert state.style == %{bold: true}
      assert state.theme == %{fg: :red}
    end
  end

  describe "render/2 - single line, no wrapping" do
    test "returns text element with content" do
      {:ok, state} = Text.init(content: "hello world", id: "t")
      result = Text.render(state, @context)
      assert result.type == :text
      assert result.content == "hello world"
    end

    test "applies style from state" do
      {:ok, state} = Text.init(content: "hi", id: "t", style: %{bold: true})
      result = Text.render(state, @context)
      assert result.style.bold == true
    end
  end

  describe "render/2 - truncation" do
    test "truncates long text with ellipsis" do
      {:ok, state} = Text.init(content: "hello world", width: 8, truncate: true, id: "t")
      result = Text.render(state, @context)
      assert result.type == :text
      assert result.content == "hello..."
      assert String.length(result.content) == 8
    end

    test "does not truncate text that fits" do
      {:ok, state} = Text.init(content: "hi", width: 10, truncate: true, id: "t")
      result = Text.render(state, @context)
      assert result.content == "hi"
    end

    test "does not truncate when no width set" do
      {:ok, state} = Text.init(content: "a long string", truncate: true, id: "t")
      result = Text.render(state, @context)
      assert result.content == "a long string"
    end

    test "handles very small widths" do
      {:ok, state} = Text.init(content: "hello", width: 3, truncate: true, id: "t")
      result = Text.render(state, @context)
      assert String.length(result.content) == 3
    end
  end

  describe "render/2 - word wrapping" do
    test "produces column with wrapped lines" do
      {:ok, state} = Text.init(content: "one two three four", width: 10, wrap: :word, id: "t")
      result = Text.render(state, @context)
      assert result.type == :column
      contents = Enum.map(result.children, & &1.content)
      assert length(contents) > 1
      assert Enum.all?(contents, fn c -> String.length(c) <= 10 end)
    end

    test "single word that fits returns text element" do
      {:ok, state} = Text.init(content: "hello", width: 10, wrap: :word, id: "t")
      result = Text.render(state, @context)
      assert result.type == :text
      assert result.content == "hello"
    end
  end

  describe "render/2 - char wrapping" do
    test "produces column with char-wrapped lines" do
      {:ok, state} = Text.init(content: "abcdefghij", width: 4, wrap: :char, id: "t")
      result = Text.render(state, @context)
      assert result.type == :column
      contents = Enum.map(result.children, & &1.content)
      assert contents == ["abcd", "efgh", "ij"]
    end
  end

  describe "render/2 - alignment" do
    test "left alignment is default (no padding)" do
      {:ok, state} = Text.init(content: "hi", width: 10, id: "t")
      result = Text.render(state, @context)
      assert result.content == "hi"
    end

    test "right alignment pads left" do
      {:ok, state} = Text.init(content: "hi", width: 10, align: :right, id: "t")
      result = Text.render(state, @context)
      assert result.content == "        hi"
    end

    test "center alignment pads both sides" do
      {:ok, state} = Text.init(content: "hi", width: 10, align: :center, id: "t")
      result = Text.render(state, @context)
      assert String.length(result.content) == 10
      assert String.trim(result.content) == "hi"
    end

    test "alignment without width is no-op" do
      {:ok, state} = Text.init(content: "hi", align: :center, id: "t")
      result = Text.render(state, @context)
      assert result.content == "hi"
    end
  end

  describe "render/2 - wrapping + alignment" do
    test "each wrapped line is aligned independently" do
      {:ok, state} =
        Text.init(content: "ab cd ef", width: 5, wrap: :word, align: :right, id: "t")

      result = Text.render(state, @context)
      assert result.type == :column

      Enum.each(result.children, fn child ->
        assert String.length(child.content) == 5
      end)
    end
  end

  describe "update/2" do
    test "merges style and theme" do
      {:ok, state} = Text.init(style: %{bold: true}, theme: %{fg: :red}, id: "t")
      {updated, []} = Text.update(%{style: %{italic: true}, theme: %{bg: :blue}}, state)
      assert updated.style == %{bold: true, italic: true}
      assert updated.theme == %{fg: :red, bg: :blue}
    end

    test "updates content" do
      {:ok, state} = Text.init(content: "old", id: "t")
      {updated, []} = Text.update(%{content: "new"}, state)
      assert updated.content == "new"
    end
  end

  describe "handle_event/3" do
    test "passes through all events unchanged" do
      {:ok, state} = Text.init(content: "hello", id: "t")
      {result_state, commands} = Text.handle_event(:any_event, state, @context)
      assert result_state == state
      assert commands == []
    end
  end
end
