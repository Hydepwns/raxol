defmodule Raxol.UI.Components.Input.CheckboxTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.Checkbox
  # alias Raxol.Core.Events.Event # Commented out until needed

  describe "init/1" do
    test "initializes with default values" do
      # init returns {:ok, state}
      assert {:ok, state} = Checkbox.init(id: :cb1)

      assert state.id == :cb1
      assert state.checked == false
      assert is_map(state)
      assert Map.has_key?(state, :disabled)
      assert state.disabled == false
      assert state.label == ""
      assert state.style == %{}
      assert state.theme == %{}
      assert is_map(state)
      assert Map.has_key?(state, :focused)
      assert state.focused == false
      assert state.on_toggle == nil
      assert state.tooltip == nil
      assert state.required == false
      assert state.aria_label == nil
    end

    test "initializes with provided props" do
      on_toggle_func = fn _ -> :toggled end
      # Define props as a Keyword list
      props = [
        id: :my_cb,
        label: "Check me",
        checked: true,
        disabled: true,
        style: %{color: :green},
        theme: %{fg: :blue},
        on_toggle: on_toggle_func,
        tooltip: "tip",
        required: true,
        aria_label: "Check this"
      ]

      # init returns {:ok, state}
      assert {:ok, state} = Checkbox.init(props)

      assert state.id == :my_cb
      assert state.checked == true
      assert is_map(state)
      assert Map.has_key?(state, :disabled)
      assert state.disabled == true
      assert state.label == "Check me"
      assert state.style == %{color: :green}
      assert state.theme == %{fg: :blue}
      assert is_map(state)
      assert Map.has_key?(state, :focused)
      assert state.focused == false
      assert state.on_toggle == on_toggle_func
      assert state.tooltip == "tip"
      assert state.required == true
      assert state.aria_label == "Check this"
    end
  end

  # Uncomment render tests
  describe "render/1" do
    # Helper to provide a mock context (theme is needed by render)
    defp default_context do
      %{theme: Raxol.UI.Theming.Theme.default_theme()}
    end

    test "renders unchecked checkbox" do
      {:ok, state} = Checkbox.init(label: "Option")
      # Render requires state and context
      hbox_element = Checkbox.render(state, default_context())

      # Check the hbox structure using struct field access
      assert hbox_element.tag == :hbox
      assert length(hbox_element.children) == 2

      # Check the checkmark text element using struct field access
      check_element = Enum.at(hbox_element.children, 0)
      assert check_element.tag == :text
      # Access text from attributes
      text_attr =
        Enum.find(check_element.attributes, fn {key, _} -> key == :text end)

      assert text_attr == {:text, "[ ]"}

      # Check the label text element using struct field access
      label_element = Enum.at(hbox_element.children, 1)
      assert label_element.tag == :text
      # Access text from attributes
      text_attr =
        Enum.find(label_element.attributes, fn {key, _} -> key == :text end)

      assert text_attr == {:text, " Option"}
    end

    test "renders checked checkbox" do
      {:ok, state} = Checkbox.init(label: "Option", checked: true)
      hbox_element = Checkbox.render(state, default_context())

      # Check the hbox structure using struct field access
      assert hbox_element.tag == :hbox
      assert length(hbox_element.children) == 2

      # Check the checkmark text element using struct field access
      check_element = Enum.at(hbox_element.children, 0)
      assert check_element.tag == :text
      # Access text from attributes
      text_attr =
        Enum.find(check_element.attributes, fn {key, _} -> key == :text end)

      assert text_attr == {:text, "[x]"}

      # Check the label text element using struct field access
      label_element = Enum.at(hbox_element.children, 1)
      assert label_element.tag == :text
      # Access text from attributes
      text_attr =
        Enum.find(label_element.attributes, fn {key, _} -> key == :text end)

      assert text_attr == {:text, " Option"}
    end

    test "renders disabled checkbox with disabled style" do
      # Note: Now that render uses the theme, we expect the theme's
      # disabled style (e.g., disabled_fg) to be applied.
      {:ok, state} =
        Checkbox.init(
          label: "Option",
          disabled: true
          # No explicit style needed here unless overriding theme
        )

      hbox_element = Checkbox.render(state, default_context())

      # Check basic structure using struct field access
      assert hbox_element.tag == :hbox
      assert length(hbox_element.children) == 2

      # Check that the style applied to the hbox reflects the disabled state
      # Access style from attributes
      style_attr =
        Enum.find(hbox_element.attributes, fn {key, _} -> key == :style end)

      assert style_attr == {:style, %{fg: :gray, bg: :default}}
    end
  end

  # Tests for update/2 and handle_event/3
  describe "update/2" do
    test "updates the checked state" do
      {:ok, initial_state} = Checkbox.init(id: :cb_update)
      assert initial_state.checked == false

      {:ok, updated_state, _cmds} =
        Checkbox.update(%{checked: true}, initial_state)

      assert updated_state.checked == true

      {:ok, final_state, _cmds} =
        Checkbox.update(%{checked: false}, updated_state)

      assert final_state.checked == false
    end

    test "updates the label" do
      {:ok, initial_state} = Checkbox.init(id: :cb_update, label: "Initial")
      assert initial_state.label == "Initial"

      {:ok, updated_state, _cmds} =
        Checkbox.update(%{label: "Updated"}, initial_state)

      assert updated_state.label == "Updated"
    end

    test "updates the disabled state" do
      {:ok, initial_state} = Checkbox.init(id: :cb_update, disabled: false)
      assert is_map(initial_state)
      assert Map.has_key?(initial_state, :disabled)
      assert initial_state.disabled == false

      {:ok, updated_state, _cmds} =
        Checkbox.update(%{disabled: true}, initial_state)

      assert is_map(updated_state)
      assert Map.has_key?(updated_state, :disabled)
      assert updated_state.disabled == true
    end

    test "updates the on_toggle callback" do
      cb_func_1 = fn _ -> :one end
      cb_func_2 = fn _ -> :two end
      {:ok, initial_state} = Checkbox.init(id: :cb_update, on_toggle: cb_func_1)
      assert initial_state.on_toggle == cb_func_1

      {:ok, updated_state, _cmds} =
        Checkbox.update(%{on_toggle: cb_func_2}, initial_state)

      assert updated_state.on_toggle == cb_func_2
    end

    test "merges style and theme on update" do
      {:ok, initial_state} =
        Checkbox.init(id: :cb_update, style: %{fg: :red}, theme: %{bg: :blue})

      {:ok, updated_state, _cmds} =
        Checkbox.update(
          %{style: %{bold: true}, theme: %{fg: :green}},
          initial_state
        )

      assert updated_state.style == %{fg: :red, bold: true}
      assert updated_state.theme == %{bg: :blue, fg: :green}
    end
  end

  describe "handle_event/3" do
    alias Raxol.Core.Events.Event
    # alias Raxol.Core.Events.InputEvent # REMOVE THIS LINE

    # Helper to create initial state
    defp init_state(props \\ []) do
      {:ok, state} = Checkbox.init([id: :cb_event] ++ props)
      state = Map.put_new(state, :style, %{})
      Map.put_new(state, :type, :checkbox)
    end

    # Helper to create a click event
    defp click_event() do
      %Event{
        # Use :mouse type
        type: :mouse,
        data: %{
          button: :left,
          action: :press,
          row: 0,
          col: 0,
          # Add x/y for termbox compatibility if needed, or adjust based on component needs
          x: 0,
          y: 0,
          ctrl: false,
          alt: false,
          shift: false
        }
      }
    end

    # Helper to create a space keypress event
    defp space_keypress_event() do
      %Event{
        # Use :key type
        type: :key,
        data: %{
          # Use key atom
          key: :space,
          # Include char
          char: " ",
          ctrl: false,
          alt: false,
          shift: false
        }
      }
    end

    # Helper to create some other keypress event
    defp other_keypress_event() do
      %Event{
        # Use :key type
        type: :key,
        data: %{
          # Use :char for general characters
          key: :char,
          # Include char
          char: "a",
          ctrl: false,
          alt: false,
          shift: false
        }
      }
    end

    test "toggles state from unchecked to checked on click" do
      state = init_state(checked: false)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(click_event(), %{}, state)

      assert new_state.checked == true
    end

    test "toggles state from checked to unchecked on click" do
      state = init_state(checked: true)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(click_event(), %{}, state)

      assert new_state.checked == false
    end

    test "toggles state from unchecked to checked on space keypress" do
      state = init_state(checked: false)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(space_keypress_event(), %{}, state)

      assert new_state.checked == true
    end

    test "toggles state from checked to unchecked on space keypress" do
      state = init_state(checked: true)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(space_keypress_event(), %{}, state)

      assert new_state.checked == false
    end

    test "does not toggle state on other keypress" do
      state = init_state(checked: false)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(other_keypress_event(), %{}, state)

      assert new_state.checked == false

      state_checked = init_state(checked: true)

      {:noreply, new_state_checked, _cmds} =
        Checkbox.handle_event(other_keypress_event(), %{}, state_checked)

      assert new_state_checked.checked == true
    end

    test "does not toggle when disabled (click)" do
      state = init_state(checked: false, disabled: true)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(click_event(), %{}, state)

      assert new_state.checked == false
    end

    test "does not toggle when disabled (space keypress)" do
      state = init_state(checked: false, disabled: true)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(space_keypress_event(), %{}, state)

      assert new_state.checked == false
    end

    test "calls on_toggle callback with new state when toggled" do
      # Use Process dictionary to track if callback was called
      on_toggle_func = fn checked_state ->
        Process.put(:toggled_to, checked_state)
      end

      state = init_state(checked: false, on_toggle: on_toggle_func)

      # Reset tracker
      Process.put(:toggled_to, nil)

      {:noreply, new_state, _cmds} =
        Checkbox.handle_event(click_event(), %{}, state)

      assert new_state.checked == true
      assert Process.get(:toggled_to) == true

      # Reset tracker
      Process.put(:toggled_to, nil)

      {:noreply, final_state, _cmds} =
        Checkbox.handle_event(space_keypress_event(), %{}, new_state)

      assert final_state.checked == false
      assert Process.get(:toggled_to) == false
    end

    test "does not call on_toggle callback when not toggled" do
      # Use Process dictionary to track if callback was called
      on_toggle_func = fn _ -> Process.put(:toggle_called, true) end

      state =
        init_state(checked: false, disabled: true, on_toggle: on_toggle_func)

      # Reset tracker
      Process.put(:toggle_called, false)

      {:noreply, _new_state, _cmds} =
        Checkbox.handle_event(click_event(), %{}, state)

      assert Process.get(:toggle_called) == false

      # Reset tracker
      Process.put(:toggle_called, false)

      {:noreply, _final_state, _cmds} =
        Checkbox.handle_event(other_keypress_event(), %{}, state)

      assert Process.get(:toggle_called) == false
    end
  end
end
