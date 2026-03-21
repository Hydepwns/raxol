defmodule Raxol.UI.Components.CodeBlockTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.CodeBlock

  describe "init/1" do
    test "returns {:ok, state} with props passed through" do
      props = %{content: "IO.puts(:hello)", language: "elixir"}
      assert {:ok, state} = CodeBlock.init(props)
      assert state == props
    end

    test "returns {:ok, state} with empty props" do
      assert {:ok, state} = CodeBlock.init(%{})
      assert state == %{}
    end

    test "preserves all provided props" do
      props = %{
        content: "def foo, do: :bar",
        language: "elixir",
        class: "my-class"
      }

      assert {:ok, ^props} = CodeBlock.init(props)
    end
  end

  describe "update/2" do
    test "returns state unchanged for any message" do
      {:ok, state} = CodeBlock.init(%{content: "code", language: "elixir"})

      assert CodeBlock.update(:any_message, state) == state
      assert CodeBlock.update(%{content: "new"}, state) == state
      assert CodeBlock.update(nil, state) == state
    end
  end

  describe "handle_event/3" do
    test "returns {state, []} for any event" do
      {:ok, state} = CodeBlock.init(%{content: "code", language: "elixir"})

      assert {^state, []} = CodeBlock.handle_event(:click, state, %{})
      assert {^state, []} = CodeBlock.handle_event(:key, state, %{theme: %{}})
      assert {^state, []} = CodeBlock.handle_event(nil, state, %{})
    end
  end

  describe "mount/1" do
    test "returns {state, []} without modifying state" do
      {:ok, state} = CodeBlock.init(%{content: "x = 1", language: "elixir"})
      assert {^state, []} = CodeBlock.mount(state)
    end
  end

  describe "unmount/1" do
    test "returns state unchanged" do
      {:ok, state} = CodeBlock.init(%{content: "x = 1", language: "elixir"})
      assert CodeBlock.unmount(state) == state
    end
  end

  describe "render/2" do
    test "renders elixir code content without raising" do
      {:ok, state} = CodeBlock.init(%{content: "IO.puts(:hello)", language: "elixir"})
      result = CodeBlock.render(state, %{})
      assert result.content
      assert is_binary(result.content)
    end

    test "rendered content preserves the source text" do
      {:ok, state} = CodeBlock.init(%{content: "IO.puts(:hello)", language: "elixir"})
      result = CodeBlock.render(state, %{})
      assert result.content =~ "IO"
      assert result.content =~ "puts"
      assert result.content =~ "hello"
    end

    test "renders unknown language without raising" do
      {:ok, state} = CodeBlock.init(%{content: "print('hi')", language: "python"})
      result = CodeBlock.render(state, %{})
      assert result.content =~ "print"
    end

    test "renders with empty content" do
      {:ok, state} = CodeBlock.init(%{})
      result = CodeBlock.render(state, %{})
      assert result.content == ""
    end

    test "renders plain text language" do
      {:ok, state} = CodeBlock.init(%{content: "hello world", language: "text"})
      result = CodeBlock.render(state, %{})
      assert result.content =~ "hello world"
    end

    test "strips HTML tags from Makeup output" do
      {:ok, state} = CodeBlock.init(%{content: "defmodule Foo do\nend", language: "elixir"})
      result = CodeBlock.render(state, %{})
      refute result.content =~ "<span"
      refute result.content =~ "</span>"
    end
  end
end
