defmodule Raxol.UI.Components.Input.TextInputTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.TextInput
  alias Raxol.Core.Events.Event
  # import Raxol.Test.TestHelper # Removed - default_context not used

  # Helper to initialize component state with optional props
  # Mimics how the component manager might hold state
  defp create_component_state(props \\ %{}) do
    {:ok, initial_state} = TextInput.init(props)
    # Return only the state map
    initial_state
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
    # Remove tests for update/2 as it doesn't seem to exist
    # test "updates value from props" do ... end
    # test "updates props" do ... end
    # test "maintains cursor position when value doesn't change" do ... end
  end

  describe "handle_event/3" do
    # ... (setup callback helper) ...

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
      # Actual cursor rendering might be handled higher up
    end
  end
end
