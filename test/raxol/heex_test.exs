defmodule Raxol.HEExTest do
  use ExUnit.Case, async: true

  alias Raxol.HEEx

  describe "compile_heex_for_terminal/2" do
    test "interpolates assigns into template" do
      result = HEEx.compile_heex_for_terminal(
        "<span data-terminal-component=\"text\">Hello, <%= @name %>!</span>",
        %{name: "World"}
      )

      assert result.type == :text
      assert result.content == "Hello, World!"
    end

    test "handles multiple assigns" do
      result = HEEx.compile_heex_for_terminal(
        "<span data-terminal-component=\"text\"><%= @greeting %>, <%= @name %>!</span>",
        %{greeting: "Hi", name: "Alice"}
      )

      assert result.type == :text
      assert result.content == "Hi, Alice!"
    end
  end

  describe "parse_html_to_widget_tree/1" do
    test "parses text component" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<span data-terminal-component="text" id="greeting">Hello!</span>)
      )

      assert result.type == :text
      assert result.content == "Hello!"
      assert result.id == "greeting"
    end

    test "parses box component with children" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<div data-terminal-component="box" id="container"><span data-terminal-component="text">Inside</span></div>)
      )

      assert result.type == :box
      assert result.id == "container"
      assert length(result.children) == 1
      [child] = result.children
      assert child.type == :text
      assert child.content == "Inside"
    end

    test "parses row component as flex with direction row" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<div data-terminal-component="row" data-gap="2" data-justify="center"><span data-terminal-component="text">A</span><span data-terminal-component="text">B</span></div>)
      )

      assert result.type == :flex
      assert result.direction == :row
      assert result.gap == 2
      assert result.justify == :center
      assert length(result.children) == 2
    end

    test "parses column component as flex with direction column" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<div data-terminal-component="column" data-gap="1"><span data-terminal-component="text">Line 1</span></div>)
      )

      assert result.type == :flex
      assert result.direction == :column
      assert result.gap == 1
    end

    test "parses button component" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<button data-terminal-component="button" id="btn1" phx-click="submit">Submit</button>)
      )

      assert result.type == :button
      assert result.text == "Submit"
      assert result.id == "btn1"
      assert result.on_click == "submit"
    end

    test "parses input component" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<input data-terminal-component="input" value="hello" placeholder="Type..." id="inp1"/>)
      )

      assert result.type == :text_input
      assert result.value == "hello"
      assert result.placeholder == "Type..."
      assert result.id == "inp1"
    end

    test "parses divider component" do
      result = HEEx.parse_html_to_widget_tree(
        ~s(<div data-terminal-component="divider" data-color="blue">----------</div>)
      )

      assert result.type == :text
      assert result.content == "----------"
      assert result.style == %{fg: :blue}
    end

    test "parses nested structure" do
      html = """
      <div data-terminal-component="box">
        <div data-terminal-component="row" data-gap="1">
          <button data-terminal-component="button">OK</button>
          <button data-terminal-component="button">Cancel</button>
        </div>
      </div>
      """

      result = HEEx.parse_html_to_widget_tree(html)
      assert result.type == :box
      assert length(result.children) == 1

      [row] = result.children
      assert row.type == :flex
      assert row.direction == :row
      assert length(row.children) == 2

      [ok_btn, cancel_btn] = row.children
      assert ok_btn.type == :button
      assert ok_btn.text == "OK"
      assert cancel_btn.type == :button
      assert cancel_btn.text == "Cancel"
    end

    test "handles plain text without components" do
      result = HEEx.parse_html_to_widget_tree("Just plain text")
      assert result.type == :text
      assert result.content == "Just plain text"
    end

    test "strips unknown HTML tags and extracts content" do
      result = HEEx.parse_html_to_widget_tree(
        "<p>Some paragraph</p>"
      )

      assert result.type == :text
      assert result.content == "Some paragraph"
    end
  end
end
