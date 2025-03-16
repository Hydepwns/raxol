defmodule Raxol.Style.Colors.ThemeTest do
  use ExUnit.Case, async: false
  doctest Raxol.Style.Colors.Theme

  alias Raxol.Style.Colors.{Color, Palette, Theme}

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
      assert color.ansi_code == 1  # Red ANSI code
    end

    test "gets a default color when UI element not defined" do
      theme = Theme.standard_theme()
      color = Theme.get_ui_color(theme, :not_defined)
      
      # Should fall back to foreground color
      foreground = Theme.get_ui_color(theme, :app_foreground)
      assert color == foreground
    end
  end

  # Helper for temporary directory in tests
  setup do
    tmp_dir = System.tmp_dir!() |> Path.join("raxol_theme_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end
end 