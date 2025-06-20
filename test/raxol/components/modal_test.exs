defmodule Raxol.UI.Components.ModalTest do
  # use ExUnit.Case, async: true
  # Run synchronously
  use ExUnit.Case

  alias Raxol.UI.Components.Modal
  # For checking rendered elements
  # import Raxol.View.Elements

  # --- Alert/Confirm Tests (Basic) ---
  test "init initializes alert modal" do
    props = Modal.alert(:my_alert, "Alert!", "Something happened")
    state = Modal.init(Map.new(props))
    assert state.id == :my_alert
    assert state.title == "Alert!"
    assert state.content == "Something happened"
    assert is_map(state)
    assert Map.has_key?(state, :type)
    assert state.type == :alert
    assert state.buttons == [{"OK", :ok}]
  end

  test "init initializes confirm modal" do
    props =
      Modal.confirm(:my_confirm, "Confirm?", "Are you sure?", :yes_msg, :no_msg)

    state = Modal.init(Map.new(props))
    assert state.id == :my_confirm
    assert state.title == "Confirm?"
    assert state.content == "Are you sure?"
    assert is_map(state)
    assert Map.has_key?(state, :type)
    assert state.type == :confirm
    assert state.buttons == [{"Yes", :yes_msg}, {"No", :no_msg}]
  end

  test "update handles basic show/hide" do
    # Use Modal.init/1 with a props map to ensure all required fields are present
    props = Modal.alert(:my_alert, "Alert!", "X", visible: false)
    state = Modal.init(Map.new(props))

    refute state.visible

    # Show it and check state/commands
    {show_state, show_cmds} = Modal.update(:show, state)
    # Wait for modal to become visible
    assert_receive {:modal_state_changed, :my_alert, :visible, true}, 100
    assert show_state.visible
    # Focus alert itself
    assert show_cmds == [{:set_focus, :my_alert}]

    # Hide it and check state/commands
    {hide_state, hide_cmds} = Modal.update(:hide, show_state)
    # Wait for modal to become hidden
    assert_receive {:modal_state_changed, :my_alert, :visible, false}, 100
    refute hide_state.visible
    assert hide_cmds == []
  end

  test "update handles simple button click" do
    props = Modal.alert(:my_alert, "Alert!", "X")
    state = Modal.init(Map.new(props))
    assert state.visible

    {state, cmds} = Modal.update({:button_click, :ok}, state)
    refute state.visible
    assert cmds == [:ok]
  end

  # --- Prompt Modal Tests ---

  test "init initializes prompt modal" do
    props =
      Modal.prompt(
        :my_prompt,
        "Enter Value",
        "Your Name:",
        :prompt_submit,
        :prompt_cancel,
        default_value: "Test"
      )

    state = Modal.init(Map.new(props))

    assert state.id == :my_prompt
    assert state.title == "Enter Value"
    assert is_map(state)
    assert Map.has_key?(state, :type)
    assert state.type == :prompt
    assert state.visible == true
    # Content moved to field label
    assert state.content == nil
    assert state.form_state.focus_index == 0
    assert state.form_state.fields |> length() == 1
    prompt_field = state.form_state.fields |> hd()
    assert is_map(prompt_field)
    assert Map.has_key?(prompt_field, :type)
    assert prompt_field.type == :text_input
    assert prompt_field.label == "Your Name:"
    assert prompt_field.value == "Test"
    assert prompt_field.validate == nil

    assert state.buttons == [
             {"Submit", {:submit, :prompt_submit}},
             {"Cancel", :prompt_cancel}
           ]
  end

  test "prompt update handles :field_update" do
    props = Modal.prompt(:my_prompt, "Enter Value", "Your Name:")
    state = Modal.init(Map.new(props))

    {new_state, commands} =
      Modal.update({:field_update, :prompt_input, "New Value"}, state)

    assert commands == []
    assert new_state.form_state.fields |> hd() |> Map.get(:value) == "New Value"
  end

  test "prompt handle_event submits on Enter" do
    props =
      Modal.prompt(:my_prompt, "Enter Value", "Your Name:", :prompt_submit)

    state = Modal.init(Map.new(props))
    # Simulate user typing
    {state, _} =
      Modal.update({:field_update, :prompt_input, "Entered Name"}, state)

    # Required by handle_event_component
    props_map = %{}
    enter_event = %{type: :key, data: %{key: "Enter"}}
    {new_state, commands} = Modal.handle_event(enter_event, props_map, state)

    assert new_state.visible == false
    # Value from the single field
    expected_payload = %{prompt_input: "Entered Name"}
    assert commands == [{:prompt_submit, expected_payload}]
  end

  test "prompt handle_event cancels on Escape" do
    props =
      Modal.prompt(:my_prompt, "Enter Value", "Name", :submit, :prompt_cancel)

    state = Modal.init(Map.new(props))
    props_map = %{}
    escape_event = %{type: :key, data: %{key: "Escape"}}
    {new_state, commands} = Modal.handle_event(escape_event, props_map, state)
    # Wait for modal to become hidden
    assert_receive {:modal_state_changed, :my_prompt, :visible, false}, 100
    assert new_state.visible == false
    assert commands == [:prompt_cancel]
  end

  # --- Form Modal Tests ---

  defp default_form_fields do
    [
      %{id: :name, type: :text_input, label: "Name", value: "Initial"},
      %{id: :agree, type: :checkbox, label: "Agree?", value: false},
      %{
        id: :option,
        type: :dropdown,
        label: ~c"Choose",
        value: "b",
        options: [{"A", "a"}, {"B", "b"}]
      }
    ]
  end

  defp default_form_props(fields \\ default_form_fields()) do
    Modal.form(:my_form, "Test Form", fields, :form_submitted, :form_canceled)
  end

  test "form init initializes form modal state correctly" do
    props = default_form_props()
    state = Modal.init(Map.new(props))

    assert state.id == :my_form
    assert state.title == "Test Form"
    assert is_map(state)
    assert Map.has_key?(state, :type)
    assert state.type == :form
    assert state.visible == true
    # Check normalized fields include error: nil and validate: nil by default
    assert state.form_state.fields ==
             default_form_fields()
             |> Enum.map(
               &Map.merge(&1, %{props: %{}, validate: nil, error: nil})
             )

    assert state.form_state.focus_index == 0

    assert state.buttons == [
             {"Submit", {:submit, :form_submitted}},
             {"Cancel", :form_canceled}
           ]
  end

  test "form render generates form fields" do
    props = default_form_props()
    state = Modal.init(Map.new(props))
    view = Modal.render(state, %{})

    # Correctly navigate the view structure
    # view = %{type: :box, attrs: %{id: "my_form-box", ...}, children: inner_column_map}
    # This should be the %{type: :column, ...} map
    inner_column_map = view.children
    # Defensive check for :type field
    assert is_map(inner_column_map)
    assert Map.has_key?(inner_column_map, :type)
    assert inner_column_map.type == :column
    # This is the list [title, spacer, content, spacer, buttons]
    list_of_elements = inner_column_map.children

    # Assuming content is 3rd element
    content_element = Enum.at(list_of_elements, 2)
    # Defensive check for :type field
    assert is_map(content_element)
    assert Map.has_key?(content_element, :type)
    assert content_element.type == :column
    # The children of the content column IS the list of field columns
    field_columns = content_element.children

    # One column per field
    assert length(field_columns) == 3

    # Check first field column contains label+input row
    field1_column = Enum.at(field_columns, 0)
    assert is_map(field1_column)
    assert Map.has_key?(field1_column, :type)
    assert field1_column.type == :column
    # The %{type: :row, ...} map
    field1_row_map = Enum.at(field1_column.children, 0)
    assert is_map(field1_row_map)
    assert Map.has_key?(field1_row_map, :type)
    assert field1_row_map.type == :row
    # The list [label_map, input_map]
    field1_row_children = field1_row_map.children
    # Assuming input is second
    input_map = Enum.at(field1_row_children, 1)
    assert is_map(input_map)
    assert Map.has_key?(input_map, :type)
    assert input_map.type == :text_input

    # Check second field column
    field2_column = Enum.at(field_columns, 1)
    assert is_map(field2_column)
    assert Map.has_key?(field2_column, :type)
    assert field2_column.type == :column
    field2_row_map = Enum.at(field2_column.children, 0)
    assert is_map(field2_row_map)
    assert Map.has_key?(field2_row_map, :type)
    assert field2_row_map.type == :row
    field2_row_children = field2_row_map.children
    input2_map = Enum.at(field2_row_children, 1)
    assert is_map(input2_map)
    assert Map.has_key?(input2_map, :type)
    assert input2_map.type == :checkbox

    # Check third field column
    field3_column = Enum.at(field_columns, 2)
    assert is_map(field3_column)
    assert Map.has_key?(field3_column, :type)
    assert field3_column.type == :column
    field3_row_map = Enum.at(field3_column.children, 0)
    assert is_map(field3_row_map)
    assert Map.has_key?(field3_row_map, :type)
    assert field3_row_map.type == :row
    field3_row_children = field3_row_map.children
    input3_map = Enum.at(field3_row_children, 1)
    assert is_map(input3_map)
    assert Map.has_key?(input3_map, :type)
    # This is the map we generated: %{type: Dropdown, attrs: ...}
    assert input3_map.type == Raxol.UI.Components.Selection.Dropdown
  end

  test "form update handles :field_update for text_input" do
    props = default_form_props()
    state = Modal.init(Map.new(props))

    {new_state, commands} =
      Modal.update({:field_update, :name, "New Name"}, state)

    assert commands == []

    assert new_state.form_state.fields |> Enum.at(0) |> Map.get(:value) ==
             "New Name"

    # Check others unchanged
    assert new_state.form_state.fields |> Enum.at(1) |> Map.get(:value) == false
    assert new_state.form_state.fields |> Enum.at(2) |> Map.get(:value) == "b"
  end

  test "form update handles :field_update for checkbox" do
    props = default_form_props()
    state = Modal.init(Map.new(props))
    {new_state, commands} = Modal.update({:field_update, :agree, true}, state)

    assert commands == []
    assert new_state.form_state.fields |> Enum.at(1) |> Map.get(:value) == true
  end

  test "form update handles :field_update for dropdown" do
    props = default_form_props()
    state = Modal.init(Map.new(props))
    {new_state, commands} = Modal.update({:field_update, :option, "a"}, state)

    assert commands == []
    assert new_state.form_state.fields |> Enum.at(2) |> Map.get(:value) == "a"
  end

  test "form update handles focus changes" do
    props = default_form_props()
    initial_state = Modal.init(Map.new(props))
    assert initial_state.form_state.focus_index == 0

    # Focus next (0 -> 1)
    {state_1, commands_1} = Modal.update(:focus_next_field, initial_state)
    assert state_1.form_state.focus_index == 1
    assert commands_1 == [{:set_focus, "my_form.agree"}]

    # Focus next (1 -> 2)
    {state_2, commands_2} = Modal.update(:focus_next_field, state_1)
    assert state_2.form_state.focus_index == 2
    assert commands_2 == [{:set_focus, "my_form.option"}]

    # Focus next (2 -> 0, wrap around)
    {state_0, commands_0} = Modal.update(:focus_next_field, state_2)
    assert state_0.form_state.focus_index == 0
    assert commands_0 == [{:set_focus, "my_form.name"}]

    # Focus previous (0 -> 2, wrap around)
    {state_prev, commands_prev} = Modal.update(:focus_prev_field, state_0)
    assert state_prev.form_state.focus_index == 2
    assert commands_prev == [{:set_focus, "my_form.option"}]
  end

  test "form handle_event triggers focus changes on Tab/Shift+Tab" do
    props = default_form_props()
    initial_state = Modal.init(Map.new(props))
    # Props might be needed if handle_event uses them
    props_map = %{}

    # Tab (0 -> 1)
    tab_event = %{type: :key, data: %{key: "Tab", shift: false}}

    {state_1, commands_1} =
      Modal.handle_event(tab_event, props_map, initial_state)

    assert state_1.form_state.focus_index == 1
    assert commands_1 == [{:set_focus, "my_form.agree"}]

    # Tab (1 -> 2)
    {state_2, commands_2} = Modal.handle_event(tab_event, props_map, state_1)
    assert state_2.form_state.focus_index == 2
    assert commands_2 == [{:set_focus, "my_form.option"}]

    # Tab (2 -> 0, wrap)
    {state_0, commands_0} = Modal.handle_event(tab_event, props_map, state_2)
    assert state_0.form_state.focus_index == 0
    assert commands_0 == [{:set_focus, "my_form.name"}]

    # Shift+Tab (0 -> 2, wrap)
    shift_tab_event = %{type: :key, data: %{key: "Tab", shift: true}}

    {state_prev, commands_prev} =
      Modal.handle_event(shift_tab_event, props_map, state_0)

    assert state_prev.form_state.focus_index == 2
    assert commands_prev == [{:set_focus, "my_form.option"}]
  end

  test "form handle_event submits form on Enter when valid" do
    # Single valid field
    fields = [
      %{id: :name, type: :text_input, label: "Name", value: "Final Name"}
    ]

    props =
      Modal.form(:my_form, "Test Form", fields, :form_submitted, :form_canceled)

    state = Modal.init(Map.new(props))
    props_map = %{}
    enter_event = %{type: :key, data: %{key: "Enter"}}
    {new_state, commands} = Modal.handle_event(enter_event, props_map, state)

    # Modal should hide on submit
    assert new_state.visible == false
    # Extracted value
    expected_payload = %{name: "Final Name"}
    assert commands == [{:form_submitted, expected_payload}]
  end

  test "form handle_event cancels form on Escape" do
    props = default_form_props()
    state = Modal.init(Map.new(props))
    props_map = %{}
    escape_event = %{type: :key, data: %{key: "Escape"}}
    {new_state, commands} = Modal.handle_event(escape_event, props_map, state)
    # Wait for modal to become hidden
    assert_receive {:modal_state_changed, :my_form, :visible, false}, 100
    # Modal should hide on cancel
    assert new_state.visible == false
    # Cancel message triggered
    assert commands == [:form_canceled]
  end

  # --- Validation Tests ---

  test "form validation prevents submission and shows errors on Enter" do
    fields = [
      # Required
      %{
        id: :name,
        type: :text_input,
        label: "Name",
        value: "",
        validate: ~r/.+/
      },
      %{
        id: :email,
        type: :text_input,
        label: "Email",
        value: "bad-email",
        validate: &String.contains?(&1, "@")
      }
    ]

    props =
      Modal.form(:val_form, "Validation Test", fields, :submit_ok, :cancel_ok)

    state = Modal.init(Map.new(props))
    props_map = %{}
    enter_event = %{type: :key, data: %{key: "Enter"}}

    {new_state, commands} = Modal.handle_event(enter_event, props_map, state)

    # Should NOT hide
    assert new_state.visible == true
    # No submit command
    assert commands == []
    # Check errors are set
    assert new_state.form_state.fields |> Enum.at(0) |> Map.get(:error) ==
             "Invalid input"

    assert new_state.form_state.fields |> Enum.at(1) |> Map.get(:error) ==
             "Invalid input"

    # Render view and check for error messages
    view = Modal.render(new_state, %{})

    # Correctly navigate the view structure
    # view = %{type: :box, children: inner_column_map}
    # inner_column_map = %{type: :column, children: list_of_elements}
    inner_column_map = view.children
    list_of_elements = inner_column_map.children

    # content_column = list_of_elements |> Enum.find(&(&1.type == :column))
    # Assuming content is 3rd element
    content_element = Enum.at(list_of_elements, 2)

    # field_columns_container = content_element.children |> Enum.find(&(&1.type == :column))
    # The children of the content column IS the list of field columns
    field_columns = content_element.children

    # Only 2 fields in this test
    assert length(field_columns) == 2

    # Check first field's column for error row
    # field1_column = field_columns |> Enum.find(&(&1.type == :column)) # Need better way to find field
    field1_column = Enum.at(field_columns, 0)

    # field1_elements = field1_column.children |> Enum.find(&(&1.type == :row)) # Find the row first?
    # Assuming structure: column -> [row, error_row]
    field1_elements = field1_column.children
    # Row + Error Row
    assert field1_elements |> Enum.count() == 2
    # Error is second element
    error1_row = Enum.at(field1_elements, 1)
    # Error row structure: %{type: :row, children: %{type: :label, ...}}
    # The label map IS the child of the row
    error1_label_map = error1_row.children
    assert is_map(error1_label_map)
    assert Map.has_key?(error1_label_map, :type)
    assert error1_label_map.type == :label
    # assert error1_label_map.attrs.content == "Invalid input"
    assert Keyword.get(error1_label_map.attrs, :content) == "Invalid input"
    # assert error1_label_map.attrs.style.color == :red
    assert Keyword.get(error1_label_map.attrs, :style)
           |> (fn style -> if is_map(style), do: style.color, else: nil end).() ==
             :red

    # Check second field's column for error row
    field2_column = Enum.at(field_columns, 1)
    field2_elements = field2_column.children
    # Row + Error Row
    assert field2_elements |> Enum.count() == 2
    error2_row = Enum.at(field2_elements, 1)
    # The label map IS the child of the row
    error2_label_map = error2_row.children
    assert is_map(error2_label_map)
    assert Map.has_key?(error2_label_map, :type)
    assert error2_label_map.type == :label
    # assert error2_label_map.attrs.content == "Invalid input"
    assert Keyword.get(error2_label_map.attrs, :content) == "Invalid input"
  end

  test "form validation allows submission when fixed" do
    fields = [
      %{
        id: :name,
        type: :text_input,
        label: "Name",
        value: "",
        validate: ~r/.+/
      }
    ]

    props =
      Modal.form(:val_form, "Validation Test", fields, :submit_ok, :cancel_ok)

    state = Modal.init(Map.new(props))
    props_map = %{}
    enter_event = %{type: :key, data: %{key: "Enter"}}

    # First attempt: submit invalid form
    {state, _commands} = Modal.handle_event(enter_event, props_map, state)
    assert state.visible == true
    assert state.form_state.fields |> hd() |> Map.get(:error) == "Invalid input"

    # Fix the field
    {state, _commands} =
      Modal.update({:field_update, :name, "Valid Name"}, state)

    # Error should be cleared by update
    assert state.form_state.fields |> hd() |> Map.get(:error) == nil

    # Second attempt: submit valid form
    {new_state, commands} = Modal.handle_event(enter_event, props_map, state)

    # Should hide now
    assert new_state.visible == false
    assert commands == [{:submit_ok, %{name: "Valid Name"}}]
    # Check error is still nil after successful submit
    assert new_state.form_state.fields |> hd() |> Map.get(:error) == nil
  end

  # --- Edge Case Tests ---
  test "form with no fields initializes and submits correctly" do
    props =
      Modal.form(:no_fields_form, "No Fields", [], :submit_empty, :cancel_empty)

    state = Modal.init(Map.new(props))

    assert state.form_state.fields == []
    assert state.form_state.focus_index == 0

    # Submit
    props_map = %{}
    enter_event = %{type: :key, data: %{key: "Enter"}}
    {new_state, commands} = Modal.handle_event(enter_event, props_map, state)

    assert new_state.visible == false
    assert commands == [{:submit_empty, %{}}]
  end

  test "modal without id handles focus correctly" do
    props =
      Modal.form(
        nil,
        "No ID Form",
        [%{id: :field1, type: :text_input}],
        :submit,
        :cancel
      )

    state = Modal.init(Map.new(props))

    # Show sends focus command without prefix
    {_state, commands} = Modal.update(:show, state)
    assert commands == [{:set_focus, :field1}]

    # Focus change sends focus command without prefix
    # wrap around
    {_state, commands} = Modal.update(:focus_next_field, state)
    assert commands == [{:set_focus, :field1}]
  end
end
