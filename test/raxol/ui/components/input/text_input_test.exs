defmodule Raxol.UI.Components.Input.TextInputTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.TextInput

  describe "create/1" do
    test "creates a text input with default props" do
      input = TextInput.create(%{})

      assert input.props.placeholder == ""
      assert input.props.is_password == false
      assert input.props.max_length == nil

      assert input.state.value == ""
      assert input.state.focused == false
      assert input.state.cursor_pos == 0
      assert input.state.scroll_offset == 0
    end

    test "creates a text input with custom props" do
      input =
        TextInput.create(%{
          placeholder: "Enter text",
          is_password: true,
          max_length: 10,
          value: "Initial"
        })

      assert input.props.placeholder == "Enter text"
      assert input.props.is_password == true
      assert input.props.max_length == 10

      assert input.state.value == "Initial"
      assert input.state.cursor_pos == 0
    end
  end

  describe "update/2" do
    test "updates props" do
      input = TextInput.create(%{placeholder: "Old placeholder"})
      updated = TextInput.update(input, %{placeholder: "New placeholder"})

      assert updated.props.placeholder == "New placeholder"
    end

    test "updates value from props" do
      input = TextInput.create(%{value: "Initial"})
      updated = TextInput.update(input, %{value: "Updated"})

      assert updated.state.value == "Updated"
    end

    test "maintains cursor position when value doesn't change" do
      input = TextInput.create(%{value: "Hello"})
      input = %{input | state: %{input.state | cursor_pos: 3}}

      updated = TextInput.update(input, %{placeholder: "Type here"})

      assert updated.state.cursor_pos == 3
    end
  end

  describe "handle_event/3" do
    test "handles character input" do
      input = TextInput.create(%{value: "Hello"})
      {:ok, updated} = TextInput.handle_event(input, {:key_press, "X", []}, %{})

      assert updated.state.value == "HelloX"
      assert updated.state.cursor_pos == 6
    end

    test "handles backspace" do
      input = TextInput.create(%{value: "Hello"})
      input = %{input | state: %{input.state | cursor_pos: 5}}

      {:ok, updated} =
        TextInput.handle_event(input, {:key_press, :backspace, []}, %{})

      assert updated.state.value == "Hell"
      assert updated.state.cursor_pos == 4
    end

    test "handles delete" do
      input = TextInput.create(%{value: "Hello"})
      input = %{input | state: %{input.state | cursor_pos: 2}}

      {:ok, updated} =
        TextInput.handle_event(input, {:key_press, :delete, []}, %{})

      assert updated.state.value == "Helo"
      assert updated.state.cursor_pos == 2
    end

    test "handles cursor movement" do
      input = TextInput.create(%{value: "Hello"})
      input = %{input | state: %{input.state | cursor_pos: 2}}

      # Test left arrow
      {:ok, left} = TextInput.handle_event(input, {:key_press, :left, []}, %{})
      assert left.state.cursor_pos == 1

      # Test right arrow
      {:ok, right} =
        TextInput.handle_event(input, {:key_press, :right, []}, %{})

      assert right.state.cursor_pos == 3

      # Test home
      {:ok, home} = TextInput.handle_event(input, {:key_press, :home, []}, %{})
      assert home.state.cursor_pos == 0

      # Test end
      {:ok, end_pos} =
        TextInput.handle_event(input, {:key_press, :end, []}, %{})

      assert end_pos.state.cursor_pos == 5
    end

    test "handles enter key" do
      # Set up a test callback to check if it's called
      test_pid = self()
      callback = fn value -> send(test_pid, {:submitted, value}) end

      input = TextInput.create(%{value: "Submit me", on_submit: callback})
      {:ok, _} = TextInput.handle_event(input, {:key_press, :enter, []}, %{})

      assert_receive {:submitted, "Submit me"}
    end

    test "handles escape key (blur)" do
      input = TextInput.create(%{})
      input = %{input | state: %{input.state | focused: true}}

      {:ok, updated} =
        TextInput.handle_event(input, {:key_press, :escape, []}, %{})

      assert updated.state.focused == false
    end

    test "handles mouse click (focus)" do
      input = TextInput.create(%{})

      {:ok, updated} =
        TextInput.handle_event(input, {:mouse_event, :click, 5, 0, :left}, %{})

      assert updated.state.focused == true
    end

    test "respects max_length constraint" do
      input = TextInput.create(%{value: "12345", max_length: 5})

      {:ok, updated} = TextInput.handle_event(input, {:key_press, "6", []}, %{})

      # Value should not change as max length is reached
      assert updated.state.value == "12345"
    end

    test "handles validation function" do
      # Only allow numeric input
      validate = fn value -> String.match?(value, ~r/^\d*$/) end
      input = TextInput.create(%{value: "123", validate: validate})

      # Try to add a valid character (digit)
      {:ok, valid} = TextInput.handle_event(input, {:key_press, "4", []}, %{})
      assert valid.state.value == "1234"

      # Try to add an invalid character (letter)
      {:ok, invalid} = TextInput.handle_event(input, {:key_press, "A", []}, %{})
      # Value should not change
      assert invalid.state.value == "123"
    end
  end

  describe "render/2" do
    test "renders input box with text" do
      input = TextInput.create(%{value: "Hello", width: 10})
      elements = TextInput.render(input, %{})

      # Should have the box and text elements
      assert length(elements) == 2

      # Find the box and text elements
      box = Enum.find(elements, fn e -> e.type == :box end)
      text = Enum.find(elements, fn e -> e.type == :text end)

      assert box != nil
      assert text != nil
      assert text.text == "Hello"
      assert box.width == 10
    end

    test "renders placeholder when value is empty" do
      input = TextInput.create(%{placeholder: "Type here"})
      elements = TextInput.render(input, %{})

      text = Enum.find(elements, fn e -> e.type == :text end)
      assert text.text == "Type here"
      # Placeholder should use placeholder color
      assert text.attrs.fg == :gray
    end

    test "renders password input as masked" do
      input = TextInput.create(%{value: "secret", is_password: true})
      elements = TextInput.render(input, %{})

      text = Enum.find(elements, fn e -> e.type == :text end)
      # Should show asterisks instead of actual text
      assert text.text == "******"
    end

    test "renders cursor when focused" do
      input = TextInput.create(%{value: "Hello"})
      input = %{input | state: %{input.state | focused: true, cursor_pos: 3}}

      elements = TextInput.render(input, %{})

      # Should include cursor element
      assert length(elements) == 3

      cursor = Enum.find(elements, fn e -> e.type == :cursor end)
      assert cursor != nil
      # Position 3 + 1 for border
      assert cursor.x == 4
    end
  end
end
