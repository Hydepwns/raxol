defmodule Raxol.ApplicationTest do
  use ExUnit.Case
  alias Raxol.Application
  alias Raxol.Style.Colors.{Accessibility, Persistence, Theme, Color}

  describe "color system initialization" do
    setup do
      # Create temporary directory for test files
      tmp_dir =
        Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1_000_000)}")

      File.mkdir_p!(tmp_dir)

      # Override config directory for tests
      Application.put_env(:raxol, :config_dir, tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      %{tmp_dir: tmp_dir}
    end

    test "init_color_system creates default theme when no preferences exist", %{
      tmp_dir: tmp_dir
    } do
      Application.init_color_system()

      # Check using theme name
      expected_theme_path =
        Path.join(Path.join(tmp_dir, "themes"), "Default.json")

      assert File.exists?(expected_theme_path),
             "Default theme file should exist at #{expected_theme_path}"

      # Load by name
      {:ok, theme} = Persistence.load_theme("Default")
      assert theme.name == "Default"
      assert Theme.get_ui_color(theme, :app_background).hex == "#FFFFFF"
      assert Map.has_key?(theme.ui_mappings, :primary_button)
    end

    test "init_color_system loads existing theme from preferences", %{} do
      test_palette = %{
        "background" => Color.from_hex("#F0F0F0"),
        "primary" => Color.from_hex("#0077CC"),
        "secondary" => Color.from_hex("#00AA00"),
        "accent" => Color.from_hex("#FF0000"),
        "text" => Color.from_hex("#000000"),
        "surface" => Color.from_hex("#EEEEEE"),
        "error" => Color.from_hex("#D32F2F"),
        "success" => Color.from_hex("#388E3C"),
        "warning" => Color.from_hex("#FFA000"),
        "info" => Color.from_hex("#1976D2")
      }

      theme = %Theme{
        name: "Test Theme",
        palette: test_palette,
        ui_mappings: Theme.standard_theme().ui_mappings
      }

      # Save theme using Persistence (will save as "Test Theme.json")
      :ok = Persistence.save_theme(theme)

      # Preferences should point to the NAME, not a specific path
      # Use name
      preferences = %{theme_name: theme.name}
      # Use standard Application.get_env
      prefs_path =
        Path.join(
          Application.get_env(:raxol, :config_dir, "."),
          "preferences.json"
        )

      # Ensure parent dir exists (config_dir might just be '.')
      File.mkdir_p!(Path.dirname(prefs_path))
      File.write!(prefs_path, Jason.encode!(preferences))

      Application.init_color_system()

      # Verify by loading by NAME
      {:ok, loaded_theme} = Persistence.load_theme("Test Theme")
      assert loaded_theme.name == "Test Theme"
      assert Theme.get_ui_color(loaded_theme, :app_background).hex == "#F0F0F0"
      assert Theme.get_ui_color(loaded_theme, :primary_button).hex == "#0077CC"
    end
  end

  describe "theme validation and adjustment" do
    test "validate_and_adjust_theme returns original theme if colors are accessible" do
      accessible_palette = %{
        "background" => Color.from_hex("#FFFFFF"),
        "primary" => Color.from_hex("#000000"),
        "secondary" => Color.from_hex("#0066CC"),
        "accent" => Color.from_hex("#990000"),
        "text" => Color.from_hex("#333333"),
        "surface" => Color.from_hex("#000000"),
        "error" => Color.from_hex("#000000"),
        "success" => Color.from_hex("#000000"),
        "warning" => Color.from_hex("#000000"),
        "info" => Color.from_hex("#000000")
      }

      theme = %Theme{
        name: "Accessible Theme",
        palette: accessible_palette,
        ui_mappings: Theme.standard_theme().ui_mappings
      }

      result = Application.validate_and_adjust_theme(theme)
      assert result == theme
    end

    test "validate_and_adjust_theme adjusts colors if not accessible" do
      inaccessible_palette = %{
        "background" => Color.from_hex("#FFFFFF"),
        "primary" => Color.from_hex("#777777"),
        "secondary" => Color.from_hex("#999999"),
        "accent" => Color.from_hex("#BBBBBB"),
        "text" => Color.from_hex("#CCCCCC"),
        "surface" => Color.from_hex("#DDDDDD"),
        "error" => Color.from_hex("#EEEEEE"),
        "success" => Color.from_hex("#EFEFEF"),
        "warning" => Color.from_hex("#FAFAFA"),
        "info" => Color.from_hex("#FBFBFB")
      }

      theme = %Theme{
        name: "Inaccessible Theme",
        palette: inaccessible_palette,
        ui_mappings: Theme.standard_theme().ui_mappings
      }

      result = Application.validate_and_adjust_theme(theme)
      assert result.name == theme.name

      # Direct struct comparison/access
      result_bg = Theme.get_ui_color(result, :app_background)
      theme_bg = Theme.get_ui_color(theme, :app_background)
      # Background should not change
      assert result_bg == theme_bg

      result_primary = Theme.get_ui_color(result, :primary_button)
      theme_primary = Theme.get_ui_color(theme, :primary_button)
      refute result_primary == theme_primary
      # ... verify others ...

      adjusted_background = Theme.get_ui_color(result, :app_background)
      primary = Theme.get_ui_color(result, :primary_button)
      secondary = Theme.get_ui_color(result, :secondary_button)
      accent = Theme.get_ui_color(result, :accent_button)
      text = Theme.get_ui_color(result, :text)

      # Direct struct passing to check_contrast
      assert {:ok, _} =
               Accessibility.check_contrast(primary, adjusted_background)

      assert {:ok, _} =
               Accessibility.check_contrast(secondary, adjusted_background)

      assert {:ok, _} =
               Accessibility.check_contrast(accent, adjusted_background)

      assert {:ok, _} = Accessibility.check_contrast(text, adjusted_background)
      # ... add checks for others ...
    end
  end

  describe "default theme creation" do
    test "create_default_theme generates accessible theme" do
      theme = Application.create_default_theme()
      # IO.inspect(theme, label: "Default Theme Created") # DEBUG REMOVED

      assert theme.name == "Default"
      # Direct struct access
      app_bg_color = Theme.get_ui_color(theme, :app_background)
      # Check if it's nil first
      refute is_nil(app_bg_color)
      assert app_bg_color.hex == "#FFFFFF"
      assert app_bg_color.a == 1.0

      assert Map.has_key?(theme.ui_mappings, :primary_button)
      # ... other mapping checks ...

      # Direct struct passing
      background_color = Theme.get_ui_color(theme, :app_background)
      primary_color = Theme.get_ui_color(theme, :primary_button)
      secondary_color = Theme.get_ui_color(theme, :secondary_button)
      accent_color = Theme.get_ui_color(theme, :accent_button)
      text_color = Theme.get_ui_color(theme, :text)

      assert {:ok, _} =
               Accessibility.check_contrast(primary_color, background_color)

      assert {:ok, _} =
               Accessibility.check_contrast(secondary_color, background_color)

      assert {:ok, _} =
               Accessibility.check_contrast(accent_color, background_color)

      assert {:ok, _} =
               Accessibility.check_contrast(text_color, background_color)

      # ... add checks for others ...
    end
  end
end
