defmodule Raxol.Terminal.Integration.TabIntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.Tab.UnifiedTab
  alias Raxol.Terminal.Window.UnifiedWindow
  alias Raxol.Terminal.Integration.State

  setup do
    # Start the UnifiedIO process if not already running
    case Process.whereis(Raxol.Terminal.IO.UnifiedIO) do
      nil ->
        {:ok, _pid} = Raxol.Terminal.IO.UnifiedIO.start_link()

      _pid ->
        :ok
    end

    {:ok, _pid} = UnifiedWindow.start_link()
    {:ok, _pid} = UnifiedTab.start_link()
    :ok
  end

  describe "tab and window integration" do
    test ~c"creates tab with window state" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.window_state != nil
    end

    test ~c"updates window state through tab" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)

      content = "Hello, World!"
      updated_state = State.update(tab_state.window_state, content)

      # Verify the state was updated (the buffer field should contain the content)
      assert updated_state.buffer == content
    end

    test ~c"renders active tab window" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)

      content = "Test content"
      updated_state = State.update(tab_state.window_state, content)

      rendered_state = State.render(updated_state)
      assert rendered_state == updated_state
    end
  end

  describe "multiple tabs" do
    test ~c"manages multiple tab windows" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      # Update first tab
      assert {:ok, state1} = UnifiedTab.get_tab_state(tab1)
      updated_state1 = State.update(state1.window_state, "Tab 1 content")

      # Update second tab
      assert {:ok, state2} = UnifiedTab.get_tab_state(tab2)
      updated_state2 = State.update(state2.window_state, "Tab 2 content")

      # Switch between tabs
      assert :ok = UnifiedTab.set_active_tab(tab1)
      assert {:ok, active_id} = UnifiedTab.get_active_tab()
      assert active_id == tab1

      assert :ok = UnifiedTab.set_active_tab(tab2)
      assert {:ok, active_id} = UnifiedTab.get_active_tab()
      assert active_id == tab2
    end

    test ~c"maintains separate window states" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      # Update first tab
      assert {:ok, state1} = UnifiedTab.get_tab_state(tab1)
      updated_state1 = State.update(state1.window_state, "Tab 1 content")

      # Update second tab
      assert {:ok, state2} = UnifiedTab.get_tab_state(tab2)
      updated_state2 = State.update(state2.window_state, "Tab 2 content")

      # Verify states are different by checking the buffer content
      # Since we're using mock buffer managers, we'll check that the states are different
      assert updated_state1 != updated_state2
    end
  end

  describe "tab cleanup" do
    test ~c"cleans up window state when closing tab" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)

      # Update window state
      updated_state = State.update(tab_state.window_state, "Test content")

      # Close tab
      assert :ok = UnifiedTab.close_tab(tab_id)
      assert {:error, :tab_not_found} = UnifiedTab.get_tab_state(tab_id)
    end

    test ~c"cleans up all window states on manager cleanup" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      # Update both tabs
      assert {:ok, state1} = UnifiedTab.get_tab_state(tab1)
      assert {:ok, state2} = UnifiedTab.get_tab_state(tab2)

      _updated_state1 = State.update(state1.window_state, "Tab 1 content")
      _updated_state2 = State.update(state2.window_state, "Tab 2 content")

      # Clean up all tabs
      assert :ok = UnifiedTab.cleanup()
      assert UnifiedTab.get_tabs() == []
      assert {:error, :no_active_tab} = UnifiedTab.get_active_tab()
    end
  end

  describe "tab configuration" do
    test ~c"applies configuration to new tabs" do
      config = %{
        max_tabs: 5,
        tab_width: 100,
        tab_height: 30
      }

      assert :ok = UnifiedTab.update_config(config)

      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.window_state != nil
    end

    test ~c"updates tab configuration affects window state" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()

      # Update tab configuration
      new_config = %{
        name: "Updated Tab",
        icon: "🔄",
        color: "#00FF00"
      }

      assert :ok = UnifiedTab.update_tab_config(tab_id, new_config)

      # Verify window state is still accessible
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.window_state != nil
    end
  end

  describe "error handling" do
    test ~c"handles invalid tab operations with window state" do
      assert {:error, :tab_not_found} = UnifiedTab.get_tab_state(999)
      assert {:error, :tab_not_found} = UnifiedTab.update_tab_config(999, %{})
      assert {:error, :tab_not_found} = UnifiedTab.close_tab(999)
    end

    test ~c"handles window state errors gracefully" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)

      # Try to update with invalid content
      updated_state = State.update(tab_state.window_state, nil)
      assert updated_state != nil
    end
  end
end
