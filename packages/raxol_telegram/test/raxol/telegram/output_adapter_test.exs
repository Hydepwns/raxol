defmodule Raxol.Telegram.OutputAdapterTest do
  use ExUnit.Case, async: true

  alias Raxol.Telegram.OutputAdapter

  describe "buffer_to_text/1" do
    test "converts buffer cells to plain text" do
      buffer = %{
        cells: [
          [%{char: "H"}, %{char: "i"}, %{char: " "}],
          [%{char: "!"}, %{char: " "}, %{char: " "}]
        ],
        width: 3,
        height: 2
      }

      assert OutputAdapter.buffer_to_text(buffer) == "Hi\n!"
    end

    test "trims trailing empty lines" do
      buffer = %{
        cells: [
          [%{char: "A"}],
          [%{char: " "}],
          [%{char: " "}]
        ],
        width: 1,
        height: 3
      }

      assert OutputAdapter.buffer_to_text(buffer) == "A"
    end

    test "returns empty string for nil buffer" do
      assert OutputAdapter.buffer_to_text(nil) == ""
    end

    test "handles cells without char key" do
      buffer = %{
        cells: [
          [%{char: "A"}, %{}, %{char: "B"}]
        ],
        width: 3,
        height: 1
      }

      assert OutputAdapter.buffer_to_text(buffer) == "A B"
    end
  end

  describe "buffer_to_html/1" do
    test "wraps text in pre tags" do
      buffer = %{cells: [[%{char: "H"}, %{char: "i"}]], width: 2, height: 1}
      assert OutputAdapter.buffer_to_html(buffer) == "<pre>Hi</pre>"
    end

    test "escapes HTML entities" do
      buffer = %{cells: [[%{char: "<"}, %{char: ">"}, %{char: "&"}]], width: 3, height: 1}
      assert OutputAdapter.buffer_to_html(buffer) == "<pre>&lt;&gt;&amp;</pre>"
    end
  end

  describe "default_keyboard/0" do
    test "returns arrow keys and action buttons" do
      keyboard = OutputAdapter.default_keyboard()
      assert length(keyboard) == 2

      [arrows, actions] = keyboard
      assert length(arrows) == 4
      assert length(actions) == 4

      arrow_data = Enum.map(arrows, & &1.callback_data)
      assert "key:left" in arrow_data
      assert "key:up" in arrow_data
      assert "key:down" in arrow_data
      assert "key:right" in arrow_data

      action_data = Enum.map(actions, & &1.callback_data)
      assert "key:tab" in action_data
      assert "key:q" in action_data
    end
  end

  describe "build_keyboard/1" do
    test "returns default keyboard for nil view tree" do
      assert OutputAdapter.build_keyboard(nil) == OutputAdapter.default_keyboard()
    end

    test "extracts buttons from view tree" do
      view_tree = %{
        type: :column,
        children: [
          %{type: :button, id: "submit", content: "Submit"},
          %{type: :text, id: "label", content: "Hello"}
        ]
      }

      keyboard = OutputAdapter.build_keyboard(view_tree)
      # First row should be extracted buttons, rest is default
      assert length(keyboard) == 3
      [button_row | _] = keyboard
      assert hd(button_row).text == "Submit"
      assert hd(button_row).callback_data == "btn:submit"
    end

    test "falls back to default when no buttons found" do
      view_tree = %{type: :text, id: "label", content: "Hello"}
      assert OutputAdapter.build_keyboard(view_tree) == OutputAdapter.default_keyboard()
    end
  end

  describe "escape_html/1" do
    test "escapes ampersand, angle brackets" do
      assert OutputAdapter.escape_html("a & b < c > d") == "a &amp; b &lt; c &gt; d"
    end

    test "leaves normal text unchanged" do
      assert OutputAdapter.escape_html("hello world") == "hello world"
    end
  end

  describe "format_message/2" do
    test "returns html and keyboard tuple" do
      buffer = %{cells: [[%{char: "X"}]], width: 1, height: 1}
      {html, keyboard} = OutputAdapter.format_message(buffer)
      assert html == "<pre>X</pre>"
      assert is_list(keyboard)
    end
  end

  describe "default_size/0" do
    test "returns width and height tuple" do
      {w, h} = OutputAdapter.default_size()
      assert is_integer(w) and w > 0
      assert is_integer(h) and h > 0
    end
  end
end
