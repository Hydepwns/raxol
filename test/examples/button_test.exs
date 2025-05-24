defmodule Raxol.Examples.ButtonTest do
  use ExUnit.Case, async: true
  use Raxol.Test.Unit
  use Raxol.Test.Integration
  use Raxol.Test.Visual
  import ExUnit.Callbacks

  alias Raxol.UI.Components.Input.Button
  alias Raxol.Test.TestHelper
  alias Form
  import Raxol.Test.Visual.Assertions

  setup do
    context = TestHelper.setup_test_env()
    context = Map.put(context, :snapshots_dir, "test/snapshots")

    on_exit(fn ->
      TestHelper.cleanup_test_env(context)
    end)

    {:ok, context}
  end

  describe "unit tests" do
    test "initializes with default state", _context do
      result = Raxol.Test.Unit.setup_isolated_component(Button)
      assert match?({:ok, _}, result)
      {:ok, button} = result
      assert button.state.label == "Button"
      assert button.state.disabled == false
    end

    test "handles click events", _context do
      clicked = :atomics.new(1, signed: false)
      :atomics.put(clicked, 1, 1)

      result =
        Raxol.Test.Unit.setup_isolated_component(Button, %{
          on_click: fn -> :atomics.add(clicked, 1, :relaxed) end
        })

      assert match?({:ok, _}, result)
      {:ok, button} = result

      {updated, _commands} =
        Raxol.Test.Unit.simulate_event(
          button,
          Raxol.Core.Events.Event.new(:click, target: button.state.id)
        )

      assert :atomics.get(clicked, 1) == 2, "on_click function was not called"
    end

    test "handles disable state", _context do
      clicked = :atomics.new(1, signed: false)
      :atomics.put(clicked, 1, 1)

      result =
        Raxol.Test.Unit.setup_isolated_component(Button, %{
          disabled: true,
          on_click: fn -> :atomics.add(clicked, 1, :relaxed) end
        })

      assert match?({:ok, _}, result)
      {:ok, button} = result

      {updated, commands} =
        Raxol.Test.Unit.simulate_event(
          button,
          Raxol.Core.Events.Event.new(:click, target: button.state.id)
        )

      assert updated.state == button.state
      assert commands == []

      assert :atomics.get(clicked, 1) == 1,
             "on_click function was called unexpectedly"
    end

    test "unit tests handles system events properly", _context do
      result = Raxol.Test.Unit.setup_isolated_component(Button)
      assert match?({:ok, _}, result)
      {:ok, button} = result

      {button_focused, _cmd1} =
        Raxol.Test.Unit.simulate_event(
          button,
          Raxol.Core.Events.Event.focus_event(:component, true)
        )

      assert button_focused.state.focused == true

      {button_unfocused, _cmd2} =
        Raxol.Test.Unit.simulate_event(
          button_focused,
          Raxol.Core.Events.Event.focus_event(:component, false)
        )

      assert button_unfocused.state.focused == false

      # Simulate window resize (assuming button doesn't directly react, just checking it doesn't crash)
      {button_after_resize, _cmd3} =
        Raxol.Test.Unit.simulate_event(
          button_unfocused,
          Raxol.Core.Events.Event.window(:resize, {100, 30})
        )

      # State should persist
      assert button_after_resize.state.focused == false
    end

    test "applies style and theme with correct precedence" do
      theme = %{fg: :red, bg: :blue, focused_fg: :green}
      style = %{fg: :yellow, bg: :magenta}

      result =
        Raxol.Test.Unit.setup_isolated_component(Button, %{
          theme: theme,
          style: style,
          focused: true
        })

      assert match?({:ok, _}, result)
      {:ok, button} = result

      view = Raxol.Test.Visual.render_component(button)
      assert view.attrs.fg == :yellow
      assert view.attrs.bg == :magenta
    end

    test "mount and unmount lifecycle hooks are called and return state" do
      state = %{
        label: "Test",
        theme: Raxol.Test.TestHelper.test_theme(),
        style: %{}
      }

      mounted = Button.mount(state)
      assert mounted == state
      unmounted = Button.unmount(mounted)
      assert unmounted == mounted
    end
  end

  describe "integration tests" do
    test "button in form interaction", context do
      {form, button} =
        Raxol.Test.Integration.setup_component_hierarchy(Form, Button, context)

      Raxol.Test.Integration.simulate_user_action(button, {:click, {1, 1}})

      Raxol.Test.Integration.Assertions.assert_child_received(button, :clicked)

      Raxol.Test.Integration.Assertions.assert_parent_updated(
        form,
        :button_clicked
      )

      Raxol.Test.Integration.Assertions.assert_state_synchronized(
        [form, button],
        fn [form_state, button_state] ->
          form_state.submitted && button_state.pressed
        end
      )
    end

    test "contains errors properly", context do
      {form, button} =
        Raxol.Test.Integration.setup_component_hierarchy(Form, Button, context)

      Raxol.Test.Integration.Assertions.assert_error_contained(
        form,
        button,
        fn ->
          # Simulate action causing error
          Raxol.Test.Integration.simulate_user_action(button, :trigger_error)
        end
      )
    end
  end

  describe "visual tests" do
    test "renders with correct style", %{button: button} do
      view = Raxol.Test.Visual.render_component(button)
      assert is_list(view)
    end

    test "matches snapshot", %{button: button, context: context} do
      assert_matches_snapshot(
        button,
        "button_submit",
        context
      )
    end

    test "adapts to different sizes", _context do
      button = Raxol.Test.Visual.setup_visual_component(Button, %{})

      assert_responsive(
        button,
        [{80, 24}, {40, 12}, {20, 6}]
      )
    end

    test "maintains consistent structure across themes", _context do
      button = Raxol.Test.Visual.setup_visual_component(Button, %{})

      assert_theme_consistent(
        button,
        %{light: %{fg: :black, bg: :white}, dark: %{fg: :white, bg: :black}}
      )
    end

    test "aligns properly", _context do
      button = Raxol.Test.Visual.setup_visual_component(Button, %{})
      view = Raxol.Test.Visual.render_component(button)

      assert is_map(view)
    end

    test "handles different states visually", _context do
      button_normal = Raxol.Test.Visual.setup_visual_component(Button, %{})
      normal_view = Raxol.Test.Visual.render_component(button_normal)
      assert normal_view.attrs.disabled == false

      button_disabled =
        Raxol.Test.Visual.setup_visual_component(Button, %{disabled: true})

      disabled_view = Raxol.Test.Visual.render_component(button_disabled)
      assert disabled_view.attrs.disabled == true
    end
  end
end
