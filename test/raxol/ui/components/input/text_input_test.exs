defmodule Raxol.UI.Components.Input.TextInputTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.TextInput
  alias Raxol.Core.Events.Event
  # import Raxol.Test.TestHelper # Removed - default_context not used

  # Helper to initialize component state with optional props
  # Mimics how the component manager might hold state
  defp create_component_state(props \\ %{}) do
    {:ok, initial_state} = TextInput.init(props)
    # Ensure :style and :type are present
    state = Map.put_new(initial_state, :style, %{})
    Map.put_new(state, :type, :text_input)
  end

  # Helper to setup callback testing
  defp setup_callback_test do
    parent_pid = self()
    callback = fn value -> send(parent_pid, {:callback, value}) end
    {parent_pid, callback}
  end

  describe "init/1" do
    test "creates a text input with default state" do
      state = create_component_state()
      assert state.value == ""
      assert state.cursor_pos == 0
      assert state.focused == false
      assert state.placeholder == ""
      assert state.max_length == nil
      assert state.validator == nil
    end

    test "creates a text input and stores initial props in state" do
      props = %{
        value: "Initial",
        max_length: 10,
        placeholder: "Enter text",
        validator: fn _ -> true end
      }

      state = create_component_state(props)
      assert state.value == "Initial"
      assert state.max_length == 10
      assert state.placeholder == "Enter text"
      assert is_function(state.validator, 1)
      assert state.cursor_pos == 0
      assert state.focused == false
    end
  end

  describe "update/2" do
    test "updates value from props" do
      state = create_component_state(%{value: "Hello"})

      updated_state =
        TextInput.update({:update_props, %{value: "World"}}, state)

      assert updated_state.value == "World"
      assert updated_state.cursor_pos == 5
    end

    test "updates props" do
      state = create_component_state(%{placeholder: "Old"})

      updated_state =
        TextInput.update({:update_props, %{placeholder: "New"}}, state)

      assert updated_state.placeholder == "New"
    end

    test "maintains cursor position when value doesn't change" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | cursor_pos: 3}

      updated_state =
        TextInput.update({:update_props, %{placeholder: "New"}}, state)

      assert updated_state.cursor_pos == 3
    end

    test "clamps cursor position when value becomes shorter" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | cursor_pos: 5}
      updated_state = TextInput.update({:update_props, %{value: "Hi"}}, state)
      assert updated_state.cursor_pos == 2
    end

    test "handles unknown messages gracefully" do
      state = create_component_state(%{value: "Hello"})
      updated_state = TextInput.update(:unknown_message, state)
      assert updated_state == state
    end
  end

  describe "handle_event/3" do
    test "calls on_change callback when value changes" do
      {_parent_pid, callback} = setup_callback_test()
      state = create_component_state(%{value: "Hello", on_change: callback})
      state = %{state | cursor_pos: 5}

      {_updated_state, _commands} =
        TextInput.handle_event(state, Event.key("X"), %{})

      assert_receive {:callback, "HelloX"}
    end

    test "handles unknown events gracefully" do
      state = create_component_state()

      {updated_state, commands} =
        TextInput.handle_event(state, %{type: :unknown_event}, %{})

      assert updated_state == state
      assert commands == []
    end

    test "handles focus event" do
      state = create_component_state()

      {updated_state, _commands} =
        TextInput.handle_event(state, %{type: :focus}, %{})

      assert updated_state.focused == true
    end

    test "handles blur event" do
      state = create_component_state()
      state = %{state | focused: true}

      {updated_state, _commands} =
        TextInput.handle_event(state, %{type: :blur}, %{})

      assert updated_state.focused == false
    end

    test "handles character input" do
      state = create_component_state(%{value: "Hello"})
      # Set cursor to end of string before inserting
      state = %{state | cursor_pos: 5}

      {updated_state, _commands} =
        TextInput.handle_event(state, Event.key("X"), %{})

      assert updated_state.value == "HelloX"
      assert updated_state.cursor_pos == 6
    end

    test "handles backspace" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | cursor_pos: 5}

      {updated_state, _commands} =
        TextInput.handle_event(state, Event.key(:backspace), %{})

      assert updated_state.value == "Hell"
      assert updated_state.cursor_pos == 4
    end

    test "handles delete" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | cursor_pos: 2}

      {updated_state, _commands} =
        TextInput.handle_event(state, Event.key(:delete), %{})

      assert updated_state.value == "Helo"
      # Cursor stays
      assert updated_state.cursor_pos == 2
    end

    test "handles cursor movement" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | cursor_pos: 2}
      {state_left, _} = TextInput.handle_event(state, Event.key(:left), %{})
      assert state_left.cursor_pos == 1

      {state_right, _} =
        TextInput.handle_event(state_left, Event.key(:right), %{})

      assert state_right.cursor_pos == 2

      {state_home, _} =
        TextInput.handle_event(state_right, Event.key(:home), %{})

      assert state_home.cursor_pos == 0
      {state_end, _} = TextInput.handle_event(state_home, Event.key(:end), %{})
      # End of "Hello"
      assert state_end.cursor_pos == 5
    end

    test "handles enter key" do
      parent_pid = self()
      callback = fn value -> send(parent_pid, {:submitted, value}) end
      state = create_component_state(%{value: "Submit me", on_submit: callback})

      {_updated_state, _commands} =
        TextInput.handle_event(state, Event.key(:enter), %{})

      assert_receive {:submitted, "Submit me"}
    end

    test "handles escape key (blur)" do
      state = create_component_state()
      state = %{state | focused: true}

      {updated_state, _commands} =
        TextInput.handle_event(state, Event.key(:escape), %{})

      assert updated_state.focused == false
    end

    test "handles mouse click (focus)" do
      state = create_component_state()
      mouse_event = Event.mouse(:left, {0, 0})

      {updated_state, _commands} =
        TextInput.handle_event(state, mouse_event, %{})

      assert updated_state.focused == true
    end

    test "respects max_length constraint" do
      state = create_component_state(%{value: "12345", max_length: 5})
      state = %{state | cursor_pos: 5}

      {updated_state, _commands} =
        TextInput.handle_event(state, Event.key("6"), %{})

      # Should not change
      assert updated_state.value == "12345"
      assert updated_state.cursor_pos == 5
    end

    test "handles validation function" do
      validate = fn value -> String.match?(value, ~r/^\d*$/) end
      state = create_component_state(%{value: "123", validator: validate})
      state = %{state | cursor_pos: 3}
      {valid_state, _} = TextInput.handle_event(state, Event.key("4"), %{})
      assert valid_state.value == "1234"
      # Pass the updated state to the next event
      valid_state = %{valid_state | cursor_pos: 4}

      {invalid_state, _} =
        TextInput.handle_event(valid_state, Event.key("a"), %{})

      # Should not change
      assert invalid_state.value == "1234"
    end
  end

  describe "render/2" do
    test "renders input box with text" do
      state = create_component_state(%{value: "Hello"})
      elements = TextInput.render(state, %{})
      assert elements.text == "Hello"
      assert elements.type == :text_input
    end

    test "renders placeholder when value is empty" do
      state = create_component_state(%{placeholder: "Type here"})
      elements = TextInput.render(state, %{})
      assert elements.text == "Type here"
    end

    test "renders password input as masked" do
      state = create_component_state(%{value: "secret", mask_char: "*"})
      elements = TextInput.render(state, %{})
      assert elements.text == "******"
    end

    test "renders cursor when focused" do
      state = create_component_state(%{value: "Hello"})
      state = %{state | focused: true, cursor_pos: 3}
      elements = TextInput.render(state, %{})
      assert elements.focused == true
      assert elements.cursor_pos == 3
    end
  end

  describe "theming, style, and lifecycle" do
    test "applies style and theme props to input" do
      theme = %{input: %{border: "2px solid #00ff00", color: "#123456"}}
      style = %{input: %{border_radius: "8px", color: "#654321"}}

      state =
        create_component_state(%{value: "Styled", theme: theme, style: style})

      rendered = TextInput.render(state, %{})
      # Style should be merged, style prop overrides theme
      assert Map.get(rendered.style, :border) == "2px solid #00ff00"
      assert Map.get(rendered.style, :border_radius) == "8px"
      assert Map.get(rendered.style, :color) == "#654321"
    end

    test "mount/1 and unmount/1 return state unchanged" do
      state = create_component_state(%{value: "foo"})
      assert TextInput.mount(state) == state
      assert TextInput.unmount(state) == state
    end
  end
end
