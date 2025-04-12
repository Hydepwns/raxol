defmodule Raxol.ApplicationTest do
  use ExUnit.Case
  alias Raxol.Application
  alias Raxol.Style.Colors.{Persistence, Accessibility}

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
      # Initialize color system
      Application.init_color_system()

      # Check that default theme was created
      theme_path = Path.join(tmp_dir, "themes", "default.json")
      assert File.exists?(theme_path)

      # Load and verify theme
      {:ok, theme} = Persistence.load_theme(theme_path)
      assert theme.name == "Default"
      assert theme.background == "#FFFFFF"
      assert Map.has_key?(theme.ui_colors, :primary)
      assert Map.has_key?(theme.ui_colors, :secondary)
      assert Map.has_key?(theme.ui_colors, :accent)
      assert Map.has_key?(theme.ui_colors, :text)

      # Verify dark mode
      assert theme.modes.dark.background == "#000000"
      assert Map.has_key?(theme.modes.dark.ui_colors, :primary)
      assert Map.has_key?(theme.modes.dark.ui_colors, :secondary)
      assert Map.has_key?(theme.modes.dark.ui_colors, :accent)
      assert Map.has_key?(theme.modes.dark.ui_colors, :text)

      # Verify high contrast mode
      assert theme.modes.high_contrast.background == "#000000"
      assert Map.has_key?(theme.modes.high_contrast.ui_colors, :primary)
      assert Map.has_key?(theme.modes.high_contrast.ui_colors, :secondary)
      assert Map.has_key?(theme.modes.high_contrast.ui_colors, :accent)
      assert Map.has_key?(theme.modes.high_contrast.ui_colors, :text)
    end

    test "init_color_system loads existing theme from preferences", %{
      tmp_dir: tmp_dir
    } do
      # Create test theme
      theme = %{
        name: "Test Theme",
        background: "#F0F0F0",
        ui_colors: %{
          primary: "#0077CC",
          secondary: "#00AA00",
          accent: "#FF0000",
          text: "#000000"
        }
      }

      # Save theme
      theme_path = Path.join(tmp_dir, "themes", "test_theme.json")
      File.mkdir_p!(Path.dirname(theme_path))
      File.write!(theme_path, Jason.encode!(theme))

      # Create user preferences
      preferences = %{
        theme_path: theme_path
      }

      prefs_path = Path.join(tmp_dir, "preferences", "default.json")
      File.mkdir_p!(Path.dirname(prefs_path))
      File.write!(prefs_path, Jason.encode!(preferences))

      # Initialize color system
      Application.init_color_system()

      # Verify theme was loaded
      {:ok, loaded_theme} = Persistence.load_theme(theme_path)
      assert loaded_theme.name == "Test Theme"
      assert loaded_theme.background == "#F0F0F0"
      assert loaded_theme.ui_colors.primary == "#0077CC"
      assert loaded_theme.ui_colors.secondary == "#00AA00"
      assert loaded_theme.ui_colors.accent == "#FF0000"
      assert loaded_theme.ui_colors.text == "#000000"
    end
  end

  describe "theme validation and adjustment" do
    test "validate_and_adjust_theme returns original theme if colors are accessible" do
      theme = %{
        name: "Accessible Theme",
        background: "#FFFFFF",
        ui_colors: %{
          primary: "#000000",
          secondary: "#0066CC",
          accent: "#990000",
          text: "#333333"
        }
      }

      result = Application.validate_and_adjust_theme(theme)
      assert result == theme
    end

    test "validate_and_adjust_theme adjusts colors if not accessible" do
      theme = %{
        name: "Inaccessible Theme",
        background: "#FFFFFF",
        ui_colors: %{
          primary: "#777777",
          secondary: "#999999",
          accent: "#BBBBBB",
          text: "#CCCCCC"
        }
      }

      result = Application.validate_and_adjust_theme(theme)
      assert result.name == theme.name
      assert result.background == theme.background

      # Verify colors were adjusted
      assert result.ui_colors.primary != theme.ui_colors.primary
      assert result.ui_colors.secondary != theme.ui_colors.secondary
      assert result.ui_colors.accent != theme.ui_colors.accent
      assert result.ui_colors.text != theme.ui_colors.text

      # Verify adjusted colors are accessible
      assert {:ok, _} =
               Accessibility.check_contrast(
                 result.ui_colors.primary,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 result.ui_colors.secondary,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 result.ui_colors.accent,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 result.ui_colors.text,
                 theme.background
               )
    end
  end

  describe "default theme creation" do
    test "create_default_theme generates accessible theme" do
      theme = Application.create_default_theme()

      # Verify theme structure
      assert theme.name == "Default"
      assert theme.background == "#FFFFFF"
      assert Map.has_key?(theme.ui_colors, :primary)
      assert Map.has_key?(theme.ui_colors, :secondary)
      assert Map.has_key?(theme.ui_colors, :accent)
      assert Map.has_key?(theme.ui_colors, :text)

      # Verify colors are accessible
      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.ui_colors.primary,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.ui_colors.secondary,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.ui_colors.accent,
                 theme.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.ui_colors.text,
                 theme.background
               )

      # Verify dark mode
      assert theme.modes.dark.background == "#000000"

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.dark.ui_colors.primary,
                 theme.modes.dark.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.dark.ui_colors.secondary,
                 theme.modes.dark.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.dark.ui_colors.accent,
                 theme.modes.dark.background
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.dark.ui_colors.text,
                 theme.modes.dark.background
               )

      # Verify high contrast mode
      assert theme.modes.high_contrast.background == "#000000"

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.high_contrast.ui_colors.primary,
                 theme.modes.high_contrast.background,
                 :aaa
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.high_contrast.ui_colors.secondary,
                 theme.modes.high_contrast.background,
                 :aaa
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.high_contrast.ui_colors.accent,
                 theme.modes.high_contrast.background,
                 :aaa
               )

      assert {:ok, _} =
               Accessibility.check_contrast(
                 theme.modes.high_contrast.ui_colors.text,
                 theme.modes.high_contrast.background,
                 :aaa
               )
    end
  end
end
