defmodule Raxol.UI.Components.MarkdownRendererTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.MarkdownRenderer

  describe "init/1" do
    test "returns {:ok, state} with props passed through" do
      props = %{markdown_text: "# Hello"}
      assert {:ok, state} = MarkdownRenderer.init(props)
      assert state == props
    end

    test "returns {:ok, state} with empty props" do
      assert {:ok, state} = MarkdownRenderer.init(%{})
      assert state == %{}
    end

    test "preserves all provided props" do
      props = %{markdown_text: "**bold** and _italic_", class: "docs"}
      assert {:ok, ^props} = MarkdownRenderer.init(props)
    end
  end

  describe "update/2" do
    test "returns state unchanged for any message" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "# Title"})

      assert MarkdownRenderer.update(:any_message, state) == state
      assert MarkdownRenderer.update(%{markdown_text: "new"}, state) == state
      assert MarkdownRenderer.update(nil, state) == state
    end
  end

  describe "handle_event/3" do
    test "returns {state, []} for any event" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "some text"})

      assert {^state, []} = MarkdownRenderer.handle_event(:click, state, %{})
      assert {^state, []} = MarkdownRenderer.handle_event(:key, state, %{theme: %{}})
      assert {^state, []} = MarkdownRenderer.handle_event(nil, state, %{})
    end
  end

  describe "mount/1" do
    test "returns {state, []} without modifying state" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "hello"})
      assert {^state, []} = MarkdownRenderer.mount(state)
    end
  end

  describe "unmount/1" do
    test "returns state unchanged" do
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "hello"})
      assert MarkdownRenderer.unmount(state) == state
    end
  end

  describe "render/2" do
    test "renders markdown with Earmark-unavailable fallback" do
      # Earmark is only available in :dev env, not :test.
      # When Earmark is not loaded, render appends an error message.
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: "# Hello World"})
      result = MarkdownRenderer.render(state, %{})

      assert result.type == :text
      assert result.content =~ "# Hello World"
      assert result.content =~ "[MarkdownRenderer Error: Earmark library not found.]"
    end

    test "renders empty markdown text with fallback message" do
      {:ok, state} = MarkdownRenderer.init(%{})
      result = MarkdownRenderer.render(state, %{})

      assert result.type == :text
      # Empty string + error message
      assert result.content =~ "[MarkdownRenderer Error: Earmark library not found.]"
    end

    test "preserves original markdown text in fallback output" do
      markdown = "Some **bold** text with a [link](http://example.com)"
      {:ok, state} = MarkdownRenderer.init(%{markdown_text: markdown})
      result = MarkdownRenderer.render(state, %{})

      assert result.type == :text
      assert result.content =~ markdown
    end
  end
end
