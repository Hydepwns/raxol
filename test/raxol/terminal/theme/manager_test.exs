defmodule Raxol.Terminal.Theme.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Theme.Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new theme manager with default theme", %{manager: manager} do
      assert manager.current_theme.name == "default"
      assert manager.current_theme.description == "Default terminal theme"
      assert manager.current_theme.author == "Raxol"
      assert manager.current_theme.version == "1.0.0"
      assert map_size(manager.themes) == 1
      assert map_size(manager.custom_styles) == 0
      assert manager.metrics.theme_switches == 0
      assert manager.metrics.style_applications == 0
      assert manager.metrics.customizations == 0
      assert manager.metrics.load_operations == 0
    end
  end

  describe "load_theme/2" do
    test "loads an existing theme", %{manager: manager} do
      assert {:ok, updated_manager} = Manager.load_theme(manager, "default")
      assert updated_manager.current_theme.name == "default"
      assert updated_manager.metrics.theme_switches == 1
    end

    test "returns error for non-existent theme", %{manager: manager} do
      assert {:error, :theme_not_found} = Manager.load_theme(manager, "non_existent")
    end
  end

  describe "add_custom_style/3" do
    test "adds a valid custom style", %{manager: manager} do
      style = %{
        foreground: %{r: 255, g: 0, b: 0, a: 1.0},
        background: %{r: 0, g: 0, b: 0, a: 1.0},
        bold: true,
        italic: false,
        underline: false
      }

      assert {:ok, updated_manager} = Manager.add_custom_style(manager, "custom_style", style)
      assert map_size(updated_manager.custom_styles) == 1
      assert updated_manager.metrics.customizations == 1
    end

    test "returns error for invalid style", %{manager: manager} do
      invalid_style = %{
        foreground: %{r: 255, g: 0, b: 0, a: 1.0},
        background: %{r: 0, g: 0, b: 0, a: 1.0}
      }

      assert {:error, :invalid_style} = Manager.add_custom_style(manager, "invalid_style", invalid_style)
    end
  end

  describe "get_style/2" do
    test "gets a style from current theme", %{manager: manager} do
      assert {:ok, style, updated_manager} = Manager.get_style(manager, "normal")
      assert style.foreground.r == 255
      assert style.foreground.g == 255
      assert style.foreground.b == 255
      assert style.background.r == 0
      assert style.background.g == 0
      assert style.background.b == 0
      assert updated_manager.metrics.style_applications == 1
    end

    test "gets a custom style", %{manager: manager} do
      style = %{
        foreground: %{r: 255, g: 0, b: 0, a: 1.0},
        background: %{r: 0, g: 0, b: 0, a: 1.0},
        bold: true,
        italic: false,
        underline: false
      }

      {:ok, manager} = Manager.add_custom_style(manager, "custom_style", style)
      assert {:ok, ^style, updated_manager} = Manager.get_style(manager, "custom_style")
      assert updated_manager.metrics.style_applications == 1
    end

    test "returns error for non-existent style", %{manager: manager} do
      assert {:error, :style_not_found} = Manager.get_style(manager, "non_existent")
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.theme_switches == 0
      assert metrics.style_applications == 0
      assert metrics.customizations == 0
      assert metrics.load_operations == 0
    end
  end

  describe "save_theme_state/1 and restore_theme_state/2" do
    test "saves and restores theme state", %{manager: manager} do
      # Add a custom style
      style = %{
        foreground: %{r: 255, g: 0, b: 0, a: 1.0},
        background: %{r: 0, g: 0, b: 0, a: 1.0},
        bold: true,
        italic: false,
        underline: false
      }

      {:ok, manager} = Manager.add_custom_style(manager, "custom_style", style)

      # Save state
      {:ok, state} = Manager.save_theme_state(manager)
      assert state.current_theme == "default"
      assert map_size(state.custom_styles) == 1

      # Restore state
      {:ok, restored_manager} = Manager.restore_theme_state(manager, state)
      assert restored_manager.current_theme.name == "default"
      assert map_size(restored_manager.custom_styles) == 1
      assert restored_manager.metrics.load_operations == 1
    end
  end
end
