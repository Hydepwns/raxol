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
    Theme.init()
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
      theme = Theme.from_palette(palette)

      assert theme.name == "Solarized"
      assert theme.palette == palette
      assert is_map(theme.ui_mappings)
      assert Map.has_key?(theme.ui_mappings, :app_background)
    end

    test "creates a theme with a custom name" do
      palette = Palette.nord()
      theme = Theme.from_palette(palette, "Custom Nord")

      assert theme.name == "Custom Nord"
      assert theme.palette == palette
    end
  end

  describe "apply_theme/1 and current_theme/0" do
    test "applies a theme and makes it current" do
      nord = Theme.from_palette(Palette.nord())
      :ok = Theme.apply_theme(nord)

      current = Theme.current_theme()
      assert current.name == "Nord"
    end
  end

  describe "register_theme/1 and get_theme/1" do
    test "registers a theme and retrieves it" do
      theme = Theme.from_palette(Palette.dracula(), "My Dracula")
      :ok = Theme.register_theme(theme)

      retrieved = Theme.get_theme("My Dracula")
      assert retrieved == theme
    end

    test "returns nil when theme not found" do
      assert Theme.get_theme("NonExistent") == nil
    end
  end

  describe "switch_theme/1" do
    test "switches to a registered theme" do
      # Default theme is already registered in setup
      assert Theme.switch_theme("Standard") == :ok

      # Register a new theme
      dracula = Theme.from_palette(Palette.dracula())
      :ok = Theme.register_theme(dracula)

      # Switch to it
      assert Theme.switch_theme("Dracula") == :ok
      assert Theme.current_theme().name == "Dracula"
    end

    test "returns error when theme not found" do
      assert Theme.switch_theme("NonExistent") == {:error, :theme_not_found}
    end
  end

  describe "light_variant/1" do
    test "creates a light variant of a dark theme" do
      theme = Theme.standard_theme()
      assert theme.dark_mode == true

      light = Theme.light_variant(theme)
      assert light.name == "Standard Light"
      assert light.dark_mode == false
      assert light.palette.name == "ANSI 16 Light"
    end

    test "returns same theme if already light" do
      theme = Theme.standard_theme()
      light = Theme.light_variant(theme)

      # Calling light_variant again should return the same theme
      same = Theme.light_variant(light)
      assert same == light
    end
  end

  describe "dark_variant/1" do
    test "creates a dark variant of a light theme" do
      theme = Theme.standard_theme()
      light = Theme.light_variant(theme)
      assert light.dark_mode == false

      dark = Theme.dark_variant(light)
      assert dark.name == "Standard Light Dark"
      assert dark.dark_mode == true
    end

    test "returns same theme if already dark" do
      theme = Theme.standard_theme()
      assert theme.dark_mode == true

      # Calling dark_variant should return the same theme
      same = Theme.dark_variant(theme)
      assert same == theme
    end
  end

  describe "high_contrast_variant/1" do
    test "creates a high contrast variant" do
      theme = Theme.standard_theme()
      assert theme.high_contrast == false

      high_contrast = Theme.high_contrast_variant(theme)
      assert high_contrast.name == "Standard High Contrast"
      assert high_contrast.high_contrast == true
      assert high_contrast.dark_mode == theme.dark_mode
    end

    test "returns same theme if already high contrast" do
      theme = Theme.standard_theme()
      high_contrast = Theme.high_contrast_variant(theme)

      # Calling high_contrast_variant again should return the same theme
      same = Theme.high_contrast_variant(high_contrast)
      assert same == high_contrast
    end
  end

  describe "save_theme/2 and load_theme/1" do
    test "saves and loads a theme from a file", %{tmp_dir: tmp_dir} do
      theme = Theme.standard_theme()
      path = Path.join(tmp_dir, "test_theme.json")

      assert Theme.save_theme(theme, path) == :ok
      assert {:ok, loaded} = Theme.load_theme(path)

      # Verify the theme was properly saved and loaded
      assert loaded.name == theme.name
      assert loaded.dark_mode == theme.dark_mode
      assert loaded.high_contrast == theme.high_contrast
      assert Map.keys(loaded.ui_mappings) == Map.keys(theme.ui_mappings)
    end
  end

  describe "get_ui_color/2" do
    test "gets a color for a UI element" do
      theme = Theme.standard_theme()
      color = Theme.get_ui_color(theme, :error)

      assert %Color{} = color
      # Red ANSI code
      assert color.ansi_code == 1
    end

    test "gets a default color when UI element not defined" do
      theme = Theme.standard_theme()
      color = Theme.get_ui_color(theme, :not_defined)

      # Should fall back to foreground color
      foreground = Theme.get_ui_color(theme, :app_foreground)
      assert color == foreground
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
