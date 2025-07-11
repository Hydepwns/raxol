defmodule Raxol.Terminal.Tab.UnifiedTabTest do
  use ExUnit.Case
  alias Raxol.Terminal.Tab.UnifiedTab

  setup do
    {:ok, _pid} = UnifiedTab.start_link()
    :ok
  end

  describe "tab creation" do
    test "creates tab with default configuration" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.config.name == "New Tab"
      assert tab_state.config.state == :inactive
    end

    test "creates tab with custom configuration" do
      config = %{
        name: "Custom Tab",
        icon: "🔧",
        color: "#FF0000",
        state: :active
      }

      assert {:ok, tab_id} = UnifiedTab.create_tab(config)
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.config.name == "Custom Tab"
      assert tab_state.config.icon == "🔧"
      assert tab_state.config.color == "#FF0000"
      assert tab_state.config.state == :active
    end

    test "first tab becomes active" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()
      assert {:ok, active_id} = UnifiedTab.get_active_tab()
      assert tab_id == active_id
    end
  end

  describe "tab management" do
    test "gets list of all tabs" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()
      assert {:ok, tab3} = UnifiedTab.create_tab()

      tabs = UnifiedTab.get_tabs()
      assert length(tabs) == 3
      assert tab1 in tabs
      assert tab2 in tabs
      assert tab3 in tabs
    end

    test "sets active tab" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      assert :ok = UnifiedTab.set_active_tab(tab2)
      assert {:ok, active_id} = UnifiedTab.get_active_tab()
      assert active_id == tab2
    end

    test "handles non-existent tab" do
      assert {:error, :tab_not_found} = UnifiedTab.set_active_tab(999)
      assert {:error, :tab_not_found} = UnifiedTab.get_tab_state(999)
    end
  end

  describe "tab configuration" do
    test "updates tab configuration" do
      assert {:ok, tab_id} = UnifiedTab.create_tab()

      new_config = %{
        name: "Updated Tab",
        icon: "🔄",
        color: "#00FF00"
      }

      assert :ok = UnifiedTab.update_tab_config(tab_id, new_config)
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab_id)
      assert tab_state.config.name == "Updated Tab"
      assert tab_state.config.icon == "🔄"
      assert tab_state.config.color == "#00FF00"
    end

    test "updates tab manager configuration" do
      config = %{
        max_tabs: 50,
        tab_width: 100,
        tab_height: 30,
        tab_spacing: 4,
        tab_style: :detailed
      }

      assert :ok = UnifiedTab.update_config(config)
    end
  end

  describe "tab operations" do
    test "moves tab to new position" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()
      assert {:ok, tab3} = UnifiedTab.create_tab()

      assert :ok = UnifiedTab.move_tab(tab1, 2)
      tabs = UnifiedTab.get_tabs()
      assert tabs == [tab2, tab3, tab1]
    end

    test "closes tab" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      assert :ok = UnifiedTab.close_tab(tab1)
      assert {:error, :tab_not_found} = UnifiedTab.get_tab_state(tab1)
      assert {:ok, tab_state} = UnifiedTab.get_tab_state(tab2)
      assert tab_state != nil
    end

    test "closing active tab updates active tab" do
      assert {:ok, tab1} = UnifiedTab.create_tab()
      assert {:ok, tab2} = UnifiedTab.create_tab()

      assert :ok = UnifiedTab.set_active_tab(tab1)
      assert :ok = UnifiedTab.close_tab(tab1)
      assert {:ok, active_id} = UnifiedTab.get_active_tab()
      assert active_id == tab2
    end
  end

  describe "cleanup" do
    test "cleans up all tabs" do
      assert {:ok, _tab1} = UnifiedTab.create_tab()
      assert {:ok, _tab2} = UnifiedTab.create_tab()

      assert :ok = UnifiedTab.cleanup()
      assert UnifiedTab.get_tabs() == []
      assert {:error, :no_active_tab} = UnifiedTab.get_active_tab()
    end
  end

  describe "error handling" do
    test "handles invalid tab operations" do
      assert {:error, :tab_not_found} = UnifiedTab.set_active_tab(999)
      assert {:error, :tab_not_found} = UnifiedTab.get_tab_state(999)
      assert {:error, :tab_not_found} = UnifiedTab.update_tab_config(999, %{})
      assert {:error, :tab_not_found} = UnifiedTab.close_tab(999)
      assert {:error, :tab_not_found} = UnifiedTab.move_tab(999, 0)
    end
  end
end
