defmodule Raxol.Examples.ButtonTest do
  use ExUnit.Case
  use Raxol.Test.Unit
  use Raxol.Test.Integration
  use Raxol.Test.Visual

  alias Raxol.Examples.Button

  describe "unit tests" do
    test "initializes with default state" do
      {:ok, button} = setup_isolated_component(Button)
      assert button.state.label == "Button"
      assert button.state.disabled == false
    end

    test "handles click events" do
      {:ok, button} = setup_isolated_component(Button, %{on_click: fn -> :clicked end})
      
      {updated, commands} = simulate_event(button, {:click, {1, 1}})
      assert updated.state.pressed == true
      assert :clicked in commands
    end

    test "handles disable state" do
      {:ok, button} = setup_isolated_component(Button, %{disabled: true})
      
      {updated, commands} = simulate_event(button, {:click, {1, 1}})
      assert updated.state == button.state
      assert commands == []
    end
  end

  describe "integration tests" do
    test_scenario "button in form interaction", %{form: Form, button: Button} do
      {:ok, form, button} = setup_component_hierarchy(Form, Button)
      
      # Simulate button click
      simulate_user_action(button, {:click, {1, 1}})
      
      # Verify event propagation
      assert_child_received(button, :clicked)
      assert_parent_updated(form, :button_clicked)
      
      # Verify state synchronization
      assert_state_synchronized([form, button], fn [form_state, button_state] ->
        form_state.submitted && button_state.pressed
      end)
    end

    test "handles system events properly" do
      {:ok, button} = setup_isolated_component(Button)
      
      assert_system_events_handled(button, [
        {:resize, {80, 24}},
        :focus,
        :blur
      ])
    end

    test "contains errors properly" do
      {:ok, form, button} = setup_component_hierarchy(Form, Button)
      
      assert_error_contained(form, button, fn ->
        simulate_user_action(button, :trigger_error)
      end)
    end
  end

  describe "visual tests" do
    test "renders with correct style" do
      button = setup_visual_component(Button, %{label: "Click Me"})
      
      assert_renders_with(button, "Click Me")
      assert_styled_with(button, %{
        color: :blue,
        bold: true
      })
    end

    test "matches snapshot" do
      button = setup_visual_component(Button, %{label: "Submit"})
      assert_matches_snapshot(button, "button_submit")
    end

    test "adapts to different sizes" do
      button = setup_visual_component(Button)
      
      assert_responsive(button, [
        {80, 24},  # Full terminal
        {40, 12},  # Half terminal
        {20, 6}    # Quarter terminal
      ])
    end

    test "maintains consistent structure across themes" do
      button = setup_visual_component(Button)
      
      assert_theme_consistent(button, %{
        light: %{fg: :black, bg: :white},
        dark: %{fg: :white, bg: :black}
      })
    end

    test "aligns properly" do
      button = setup_visual_component(Button)
      assert_aligned(button, :all)
      
      output = capture_render(button)
      
      # Verify specific layout patterns
      assert {:ok, _} = matches_layout(output, :centered, width: 80)
      assert {:ok, _} = matches_box_edges(output)
      assert {:ok, _} = matches_component(output, :button, "Button")
    end

    test "handles different states visually" do
      # Normal state
      button = setup_visual_component(Button)
      output = capture_render(button)
      assert {:ok, _} = matches_color(output, :blue, "Button")
      
      # Disabled state
      disabled_button = setup_visual_component(Button, %{disabled: true})
      disabled_output = capture_render(disabled_button)
      assert {:ok, _} = matches_color(disabled_output, :gray, "Button")
      assert {:ok, _} = matches_style(disabled_output, :dim, "Button")
      
      # Pressed state
      pressed_button = setup_visual_component(Button, %{pressed: true})
      pressed_output = capture_render(pressed_button)
      assert {:ok, _} = matches_style(pressed_output, :reverse, "Button")
    end
  end
end 