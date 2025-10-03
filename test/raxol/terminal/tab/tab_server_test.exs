defmodule Raxol.Terminal.Tab.TabServerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Tab.TabServer

  setup do
    # Stop any existing TabServer
    case Process.whereis(TabServer) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    {:ok, pid} = TabServer.start_link(name: TabServer)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    :ok
  end

  describe "tab creation" do
    test "creates tab with default configuration" do
      assert {:ok, tab_id} = TabServer.create_tab()
      assert {:ok, tab_state} = TabServer.get_tab_state(tab_id)
      assert tab_state.config.name == "New Tab"
      assert tab_state.config.state == :inactive
    end

    test "creates tab with custom configuration" do
      config = %{
        name: "Custom Tab",
        icon: "[CONFIG]",
        color: "#FF0000",
        state: :active
      }

      assert {:ok, tab_id} = TabServer.create_tab(config)
      assert {:ok, tab_state} = TabServer.get_tab_state(tab_id)
      assert tab_state.config.name == "Custom Tab"
      assert tab_state.config.icon == "[CONFIG]"
      assert tab_state.config.color == "#FF0000"
      assert tab_state.config.state == :active
    end

    test "first tab becomes active" do
      assert {:ok, tab_id} = TabServer.create_tab()
      assert {:ok, active_id} = TabServer.get_active_tab()
      assert tab_id == active_id
    end
  end

  describe "tab management" do
    test "gets list of all tabs" do
      assert {:ok, tab1} = TabServer.create_tab()
      assert {:ok, tab2} = TabServer.create_tab()
      assert {:ok, tab3} = TabServer.create_tab()

      tabs = TabServer.get_tabs()
      assert length(tabs) == 3
      assert tab1 in tabs
      assert tab2 in tabs
      assert tab3 in tabs
    end

    test "sets active tab" do
      assert {:ok, _tab1} = TabServer.create_tab()
      assert {:ok, tab2} = TabServer.create_tab()

      assert :ok = TabServer.set_active_tab(tab2)
      assert {:ok, active_id} = TabServer.get_active_tab()
      assert active_id == tab2
    end

    test "handles non-existent tab" do
      assert {:error, :tab_not_found} = TabServer.set_active_tab(999)
      assert {:error, :tab_not_found} = TabServer.get_tab_state(999)
    end
  end

  describe "tab configuration" do
    test "updates tab configuration" do
      assert {:ok, tab_id} = TabServer.create_tab()

      new_config = %{
        name: "Updated Tab",
        icon: "[RELOAD]",
        color: "#00FF00"
      }

      assert :ok = TabServer.update_tab_config(tab_id, new_config)
      assert {:ok, tab_state} = TabServer.get_tab_state(tab_id)
      assert tab_state.config.name == "Updated Tab"
      assert tab_state.config.icon == "[RELOAD]"
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

      assert :ok = TabServer.update_config(config)
    end
  end

  describe "tab operations" do
    test "moves tab to new position" do
      assert {:ok, tab1} = TabServer.create_tab()
      assert {:ok, tab2} = TabServer.create_tab()
      assert {:ok, tab3} = TabServer.create_tab()

      assert :ok = TabServer.move_tab(tab1, 2)
      tabs = TabServer.get_tabs()
      assert tabs == [tab2, tab3, tab1]
    end

    test "closes tab" do
      assert {:ok, tab1} = TabServer.create_tab()
      assert {:ok, tab2} = TabServer.create_tab()

      assert :ok = TabServer.close_tab(tab1)
      assert {:error, :tab_not_found} = TabServer.get_tab_state(tab1)
      assert {:ok, tab_state} = TabServer.get_tab_state(tab2)
      assert tab_state != nil
    end

    test "closing active tab updates active tab" do
      assert {:ok, tab1} = TabServer.create_tab()
      assert {:ok, tab2} = TabServer.create_tab()

      assert :ok = TabServer.set_active_tab(tab1)
      assert :ok = TabServer.close_tab(tab1)
      assert {:ok, active_id} = TabServer.get_active_tab()
      assert active_id == tab2
    end
  end

  describe "cleanup" do
    test "cleans up all tabs" do
      assert {:ok, _tab1} = TabServer.create_tab()
      assert {:ok, _tab2} = TabServer.create_tab()

      assert :ok = TabServer.cleanup()
      assert TabServer.get_tabs() == []
      assert {:error, :no_active_tab} = TabServer.get_active_tab()
    end
  end

  describe "error handling" do
    test "handles invalid tab operations" do
      assert {:error, :tab_not_found} = TabServer.set_active_tab(999)
      assert {:error, :tab_not_found} = TabServer.get_tab_state(999)
      assert {:error, :tab_not_found} = TabServer.update_tab_config(999, %{})
      assert {:error, :tab_not_found} = TabServer.close_tab(999)
      assert {:error, :tab_not_found} = TabServer.move_tab(999, 0)
    end
  end
end
