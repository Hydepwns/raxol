defmodule Raxol.Terminal.Tab.WindowIntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.{Tab.Manager, Tab.WindowIntegration}

  setup do
    tab_manager = Manager.new()
    window_manager = Raxol.Terminal.Window.Manager.new_for_test()
    {:ok, %{tab_manager: tab_manager, window_manager: window_manager}}
  end

  describe "create_window_for_tab/4" do
    test "creates a window for an existing tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      {:ok, tab_id, tab_manager} = Manager.create_tab(tab_manager)
      window_config = %{title: "Test Window", width: 80, height: 24}

      {:ok, window_id, updated_tab_manager, updated_window_manager} =
        WindowIntegration.create_window_for_tab(
          tab_manager,
          window_manager,
          tab_id,
          window_config
        )

      assert is_binary(window_id)
      {:ok, tab_config} = Manager.get_tab_config(updated_tab_manager, tab_id)
      assert tab_config.window_id == window_id
    end

    test "returns error for non-existent tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      assert {:error, :tab_not_found} ==
               WindowIntegration.create_window_for_tab(
                 tab_manager,
                 window_manager,
                 "non_existent"
               )
    end
  end

  describe "destroy_window_for_tab/3" do
    test "destroys window for an existing tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      {:ok, tab_id, tab_manager} = Manager.create_tab(tab_manager)

      {:ok, _, tab_manager, window_manager} =
        WindowIntegration.create_window_for_tab(
          tab_manager,
          window_manager,
          tab_id
        )

      {:ok, updated_tab_manager, updated_window_manager} =
        WindowIntegration.destroy_window_for_tab(
          tab_manager,
          window_manager,
          tab_id
        )

      {:ok, tab_config} = Manager.get_tab_config(updated_tab_manager, tab_id)
      assert tab_config.window_id == nil
    end

    test "returns error for non-existent tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      assert {:error, :tab_not_found} ==
               WindowIntegration.destroy_window_for_tab(
                 tab_manager,
                 window_manager,
                 "non_existent"
               )
    end
  end

  describe "switch_to_tab/3" do
    test "switches to an existing tab and its window", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      {:ok, tab_id, tab_manager} = Manager.create_tab(tab_manager)

      {:ok, _, tab_manager, window_manager} =
        WindowIntegration.create_window_for_tab(
          tab_manager,
          window_manager,
          tab_id
        )

      {:ok, updated_tab_manager, updated_window_manager} =
        WindowIntegration.switch_to_tab(tab_manager, window_manager, tab_id)

      assert updated_tab_manager.active_tab == tab_id
    end

    test "returns error for non-existent tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      assert {:error, :tab_not_found} ==
               WindowIntegration.switch_to_tab(
                 tab_manager,
                 window_manager,
                 "non_existent"
               )
    end
  end

  describe "get_window_for_tab/2" do
    test "gets window ID for an existing tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      {:ok, tab_id, tab_manager} = Manager.create_tab(tab_manager)

      {:ok, window_id, tab_manager, _} =
        WindowIntegration.create_window_for_tab(
          tab_manager,
          window_manager,
          tab_id
        )

      {:ok, retrieved_window_id} =
        WindowIntegration.get_window_for_tab(tab_manager, tab_id)

      assert retrieved_window_id == window_id
    end

    test "returns error for non-existent tab", %{tab_manager: tab_manager} do
      assert {:error, :tab_not_found} ==
               WindowIntegration.get_window_for_tab(tab_manager, "non_existent")
    end
  end

  describe "update_window_for_tab/4" do
    test "updates window configuration for an existing tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      {:ok, tab_id, tab_manager} = Manager.create_tab(tab_manager)

      {:ok, _, tab_manager, window_manager} =
        WindowIntegration.create_window_for_tab(
          tab_manager,
          window_manager,
          tab_id
        )

      window_config = %{title: "Updated Title", width: 100, height: 30}

      {:ok, updated_tab_manager, updated_window_manager} =
        WindowIntegration.update_window_for_tab(
          tab_manager,
          window_manager,
          tab_id,
          window_config
        )

      {:ok, tab_config} = Manager.get_tab_config(updated_tab_manager, tab_id)
      assert tab_config.window_id != nil
    end

    test "returns error for non-existent tab", %{
      tab_manager: tab_manager,
      window_manager: window_manager
    } do
      assert {:error, :tab_not_found} ==
               WindowIntegration.update_window_for_tab(
                 tab_manager,
                 window_manager,
                 "non_existent",
                 %{}
               )
    end
  end
end
