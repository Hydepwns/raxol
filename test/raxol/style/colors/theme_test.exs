defmodule Raxol.Style.Colors.ThemeTest do
  use ExUnit.Case, async: true
  doctest Raxol.Style.Colors.Theme

  alias Raxol.Style.Colors.{Color, Palette, Theme}

  @test_theme %{
    name: "Test Theme",
    palette: %{
      "primary" => %{r: 0, g: 119, b: 204, a: 1.0},
      "secondary" => %{r: 102, g: 102, b: 102, a: 1.0},
      "accent" => %{r: 255, g: 153, b: 0, a: 1.0},
      "background" => %{r: 255, g: 255, b: 255, a: 1.0},
      "surface" => %{r: 245, g: 245, b: 245, a: 1.0},
      "error" => %{r: 204, g: 0, b: 0, a: 1.0},
      "success" => %{r: 0, g: 153, b: 0, a: 1.0},
      "warning" => %{r: 255, g: 153, b: 0, a: 1.0},
      "info" => %{r: 0, g: 153, b: 204, a: 1.0}
    },
    ui_mappings: %{
      app_background: "background",
      surface_background: "surface",
      primary_button: "primary",
      secondary_button: "secondary",
      accent_button: "accent",
      error_text: "error",
      success_text: "success",
      warning_text: "warning",
      info_text: "info"
    },
    dark_mode: false,
    high_contrast: false
  }

  setup do
    # Initialize the theme registry for each test
    # Theme.init() # Removed - Function does not exist
    :ok
  end

  describe "standard_theme/0" do
    test "returns the default theme" do
      theme = Theme.standard_theme()

      assert theme.name == "Standard"
      assert theme.palette.name == "ANSI 16"
      assert theme.dark_mode == true
      assert theme.high_contrast == false
      assert is_map(theme.ui_mappings)
      assert Map.has_key?(theme.ui_mappings, :app_background)
    end
  end

  describe "from_palette/2" do
    test "creates a theme from a palette" do
      palette = Palette.solarized()
      theme = Theme.from_palette(palette.colors)

      assert theme.name == "Custom"
      assert theme.palette == palette.colors
      assert is_map(theme.ui_mappings)
      assert Map.has_key?(theme.ui_mappings, :app_background)
    end

    test "creates a theme with a custom name" do
      palette = Palette.nord()
      theme = Theme.from_palette(palette.colors, "Custom Nord")

      assert theme.name == "Custom Nord"
      assert theme.palette == palette.colors
    end
  end

  describe "theme creation" do
    test "creates standard theme" do
      theme = Theme.standard_theme()

      # Verify theme structure
      assert theme.name == "Default"
      assert is_map(theme.palette)
      assert is_map(theme.ui_mappings)
      assert theme.dark_mode == false
      assert theme.high_contrast == false

      # Verify required colors
      assert theme.palette["primary"]
      assert theme.palette["secondary"]
      assert theme.palette["accent"]
      assert theme.palette["background"]
      assert theme.palette["surface"]
      assert theme.palette["error"]
      assert theme.palette["success"]
      assert theme.palette["warning"]
      assert theme.palette["info"]

      # Verify required UI mappings
      assert theme.ui_mappings.app_background
      assert theme.ui_mappings.surface_background
      assert theme.ui_mappings.primary_button
      assert theme.ui_mappings.secondary_button
      assert theme.ui_mappings.accent_button
      assert theme.ui_mappings.error_text
      assert theme.ui_mappings.success_text
      assert theme.ui_mappings.warning_text
      assert theme.ui_mappings.info_text
    end
  end

  describe "theme operations" do
    test "gets UI color" do
      # Get UI color
      color = Theme.get_ui_color(@test_theme, :primary_button)

      # Verify color
      assert color == %{r: 0, g: 119, b: 204, a: 1.0}
    end

    test "gets all UI colors" do
      # Get all UI colors
      colors = Theme.get_all_ui_colors(@test_theme)

      # Verify colors
      assert colors.app_background == %{r: 255, g: 255, b: 255, a: 1.0}
      assert colors.surface_background == %{r: 245, g: 245, b: 245, a: 1.0}
      assert colors.primary_button == %{r: 0, g: 119, b: 204, a: 1.0}
      assert colors.secondary_button == %{r: 102, g: 102, b: 102, a: 1.0}
      assert colors.accent_button == %{r: 255, g: 153, b: 0, a: 1.0}
      assert colors.error_text == %{r: 204, g: 0, b: 0, a: 1.0}
      assert colors.success_text == %{r: 0, g: 153, b: 0, a: 1.0}
      assert colors.warning_text == %{r: 255, g: 153, b: 0, a: 1.0}
      assert colors.info_text == %{r: 0, g: 153, b: 204, a: 1.0}
    end

    test "updates UI colors" do
      # Create new colors
      new_colors = %{
        primary_button: %{r: 255, g: 0, b: 0, a: 1.0},
        secondary_button: %{r: 0, g: 255, b: 0, a: 1.0}
      }

      # Update UI colors
      updated_theme = Theme.update_ui_colors(@test_theme, new_colors)

      # Verify colors were updated
      assert updated_theme.palette["primary"] == %{r: 255, g: 0, b: 0, a: 1.0}
      assert updated_theme.palette["secondary"] == %{r: 0, g: 255, b: 0, a: 1.0}

      # Verify other colors were not changed
      assert updated_theme.palette["accent"] == @test_theme.palette["accent"]

      assert updated_theme.palette["background"] ==
               @test_theme.palette["background"]
    end
  end

  describe "theme variants" do
    test "creates dark theme" do
      # Create dark theme
      dark_theme = Theme.create_dark_theme(@test_theme)

      # Verify dark theme
      assert dark_theme.name == @test_theme.name
      assert dark_theme.dark_mode == true

      # Verify colors are darkened
      assert dark_theme.palette["primary"].r < @test_theme.palette["primary"].r
      assert dark_theme.palette["primary"].g < @test_theme.palette["primary"].g
      assert dark_theme.palette["primary"].b < @test_theme.palette["primary"].b

      # Verify alpha values are unchanged
      assert dark_theme.palette["primary"].a == @test_theme.palette["primary"].a
    end

    test "creates high contrast theme" do
      # Create high contrast theme
      high_contrast_theme = Theme.create_high_contrast_theme(@test_theme)

      # Verify high contrast theme
      assert high_contrast_theme.name == @test_theme.name
      assert high_contrast_theme.high_contrast == true

      # Verify colors have increased contrast
      assert high_contrast_theme.palette["primary"].r in [0, 255]
      assert high_contrast_theme.palette["primary"].g in [0, 255]
      assert high_contrast_theme.palette["primary"].b in [0, 255]

      # Verify alpha values are unchanged
      assert high_contrast_theme.palette["primary"].a ==
               @test_theme.palette["primary"].a
    end
  end

  # Helper for temporary directory in tests
  setup do
    tmp_dir =
      System.tmp_dir!() |> Path.join("raxol_theme_test_#{:rand.uniform(1000)}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end
end
