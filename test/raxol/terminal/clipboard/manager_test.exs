defmodule Raxol.Terminal.Clipboard.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Clipboard.Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new clipboard manager with default options", %{
      manager: manager
    } do
      assert manager.formats == [:text, :html]
      assert manager.filters == []
      assert manager.metrics.operations == 0
      assert manager.metrics.syncs == 0
      assert manager.metrics.cache_hits == 0
      assert manager.metrics.cache_misses == 0
    end

    test ~c"creates a new clipboard manager with custom options" do
      manager =
        Manager.new(
          history_size: 50,
          formats: [:text, :rtf],
          filters: [:strip_whitespace],
          sync_enabled: false
        )

      assert manager.formats == [:text, :rtf]
      assert manager.filters == [:strip_whitespace]
      assert manager.sync == nil
    end
  end

  describe "copy/3" do
    test "copies content with default options", %{manager: manager} do
      content = "test content"
      assert {:ok, updated_manager} = Manager.copy(manager, content)
      assert updated_manager.metrics.operations == 1
    end

    test "copies content with custom format", %{manager: manager} do
      content = "<p>test content</p>"

      assert {:ok, updated_manager} =
               Manager.copy(manager, content, format: :html)

      assert updated_manager.metrics.operations == 1
    end

    test "returns error for unsupported format", %{manager: manager} do
      content = "test content"

      assert {:error, :unsupported_format} =
               Manager.copy(manager, content, format: :rtf)
    end

    test "applies filters to content", %{manager: manager} do
      manager = %{manager | filters: [:strip_whitespace]}
      content = "  test content  "
      assert {:ok, updated_manager} = Manager.copy(manager, content)
      assert updated_manager.metrics.operations == 1
    end
  end

  describe "paste/2" do
    test "pastes most recent content", %{manager: manager} do
      content = "test content"
      {:ok, manager} = Manager.copy(manager, content)
      assert {:ok, pasted, updated_manager} = Manager.paste(manager)
      assert pasted == content
      assert updated_manager.metrics.operations == 2
    end

    test "pastes content from history index", %{manager: manager} do
      content1 = "first content"
      content2 = "second content"
      {:ok, manager} = Manager.copy(manager, content1)
      {:ok, manager} = Manager.copy(manager, content2)
      assert {:ok, pasted, updated_manager} = Manager.paste(manager, index: 1)
      assert pasted == content1
    end

    test "returns error for invalid history index", %{manager: manager} do
      assert {:error, :invalid_index} = Manager.paste(manager, index: 1)
    end

    test "returns error for unsupported format", %{manager: manager} do
      content = "test content"
      {:ok, manager} = Manager.copy(manager, content)

      assert {:error, :unsupported_format} =
               Manager.paste(manager, format: :rtf)
    end
  end

  describe "cut/3" do
    test "cuts content with default options", %{manager: manager} do
      content = "test content"
      assert {:ok, updated_manager} = Manager.cut(manager, content)
      assert updated_manager.metrics.operations == 1
    end

    test "cuts content with custom format", %{manager: manager} do
      content = "<p>test content</p>"

      assert {:ok, updated_manager} =
               Manager.cut(manager, content, format: :html)

      assert updated_manager.metrics.operations == 1
    end
  end

  describe "get_history/2" do
    test "returns empty history for new manager", %{manager: manager} do
      assert {:ok, history, _} = Manager.get_history(manager)
      assert history == []
    end

    test "returns history with multiple items", %{manager: manager} do
      content1 = "first content"
      content2 = "second content"
      {:ok, manager} = Manager.copy(manager, content1)
      {:ok, manager} = Manager.copy(manager, content2)
      assert {:ok, history, _} = Manager.get_history(manager)
      assert length(history) == 2
    end

    test "filters history by format", %{manager: manager} do
      content1 = "text content"
      content2 = "<p>html content</p>"
      {:ok, manager} = Manager.copy(manager, content1)
      {:ok, manager} = Manager.copy(manager, content2, format: :html)
      assert {:ok, history, _} = Manager.get_history(manager, format: :html)
      assert length(history) == 1
    end

    test "limits history size", %{manager: manager} do
      content1 = "first content"
      content2 = "second content"
      {:ok, manager} = Manager.copy(manager, content1)
      {:ok, manager} = Manager.copy(manager, content2)
      assert {:ok, history, _} = Manager.get_history(manager, limit: 1)
      assert length(history) == 1
    end
  end

  describe "clear_history/1" do
    test "clears history", %{manager: manager} do
      content = "test content"
      {:ok, manager} = Manager.copy(manager, content)
      assert {:ok, updated_manager} = Manager.clear_history(manager)
      assert {:ok, history, _} = Manager.get_history(updated_manager)
      assert history == []
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.operations == 0
      assert metrics.syncs == 0
      assert metrics.cache_hits == 0
      assert metrics.cache_misses == 0
    end
  end
end
