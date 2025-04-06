defmodule Raxol.Style.Colors.SystemTest do
  use ExUnit.Case, async: true

  alias Raxol.Style.Colors.{System, Theme, Persistence}

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
    # Start the UserPreferences server
    start_supervised!(Raxol.Core.UserPreferences)

    # Clean up any existing theme files
    File.rm_rf!("themes")

    :ok
  end

  describe "theme management" do
    test "applies a theme" do
      assert :ok == System.apply_theme(@test_theme)

      # Verify theme was saved
      assert {:ok, saved_theme} = Persistence.load_theme(@test_theme.name)
      assert saved_theme.name == @test_theme.name
      assert saved_theme.palette == @test_theme.palette
      assert saved_theme.ui_mappings == @test_theme.ui_mappings
    end

    test "gets current theme" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Get current theme
      current_theme = System.current_theme()

      # Verify theme matches
      assert current_theme.name == @test_theme.name
      assert current_theme.palette == @test_theme.palette
      assert current_theme.ui_mappings == @test_theme.ui_mappings
    end

    test "gets UI color" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Get UI color
      color = System.get_ui_color(:primary_button)

      # Verify color
      assert color == %{r: 0, g: 119, b: 204, a: 1.0}
    end

    test "gets all UI colors" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Get all UI colors
      colors = System.get_all_ui_colors()

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
  end

  describe "theme variants" do
    test "creates dark theme" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Create dark theme
      dark_theme = System.create_dark_theme()

      # Verify dark theme
      assert dark_theme.name == @test_theme.name
      assert dark_theme.dark_mode == true

      # Verify colors are darkened
      assert dark_theme.palette["primary"].r < @test_theme.palette["primary"].r
      assert dark_theme.palette["primary"].g < @test_theme.palette["primary"].g
      assert dark_theme.palette["primary"].b < @test_theme.palette["primary"].b
    end

    test "creates high contrast theme" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Create high contrast theme
      high_contrast_theme = System.create_high_contrast_theme()

      # Verify high contrast theme
      assert high_contrast_theme.name == @test_theme.name
      assert high_contrast_theme.high_contrast == true

      # Verify colors have increased contrast
      assert high_contrast_theme.palette["primary"].r in [0, 255]
      assert high_contrast_theme.palette["primary"].g in [0, 255]
      assert high_contrast_theme.palette["primary"].b in [0, 255]
    end
  end
end
