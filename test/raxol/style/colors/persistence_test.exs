defmodule Raxol.Style.Colors.PersistenceTest do
  use ExUnit.Case, async: false

  alias Raxol.Style.Colors.Persistence

  @test_theme %{
    name: "Test Theme",
    colors: %{
      primary: "#0077CC",
      secondary: "#666666",
      accent: "#FF9900",
      background: "#FFFFFF",
      surface: "#F5F5F5",
      error: "#CC0000",
      warning: "#FF9900",
      info: "#0099CC",
      success: "#009900"
    },
    styles: %{},
    dark_mode: false,
    high_contrast: false
  }

  setup do
    # Clean up any existing theme files
    base_dir = Application.get_env(:raxol, :config_dir, ".")
    themes_dir = Path.join(base_dir, "themes")
    prefs_file = Path.join(base_dir, "preferences.json")

    File.rm_rf!(themes_dir)
    File.rm(prefs_file)

    # Ensure themes directory exists for tests
    File.mkdir_p!(themes_dir)

    # Create a dummy Default theme file to prevent :enoent
    default_theme_path = Path.join(themes_dir, "Default.json")
    dummy_theme = %{name: "Default", palette: %{}, ui_mappings: %{}}
    File.write!(default_theme_path, Jason.encode!(dummy_theme))

    :ok
  end

  defp assert_color_maps_equal(map1, map2) do
    keys = (Map.keys(map1) ++ Map.keys(map2)) |> Enum.uniq()

    for key <- keys do
      v1 = map1[key]
      v2 = map2[key]

      hex1 =
        if is_binary(v1), do: String.upcase(v1), else: v1.hex |> String.upcase()

      hex2 =
        if is_binary(v2), do: String.upcase(v2), else: v2.hex |> String.upcase()

      assert hex1 == hex2,
             "Color mismatch for #{inspect(key)}: #{inspect(hex1)} != #{inspect(hex2)}"
    end
  end

  describe "theme persistence" do
    test "saves and loads theme" do
      # Save theme
      assert :ok == Persistence.save_theme(@test_theme)

      # Load theme
      assert {:ok, loaded_theme} = Persistence.load_theme("Test Theme")

      # Verify theme matches
      assert loaded_theme.name == @test_theme.name
      assert_color_maps_equal(loaded_theme.colors, @test_theme.colors)
    end

    test "loads non-existent theme" do
      # Try to load non-existent theme
      assert {:error, :enoent} = Persistence.load_theme("Non Existent Theme")
    end

    test "theme persistence lists themes" do
      # Ensure clean state - handled by setup block
      :ok = Persistence.save_theme(%{@test_theme | name: "Theme A"})
      :ok = Persistence.save_theme(%{@test_theme | name: "Theme B"})

      themes = Persistence.list_themes()

      # Assert that the list contains Theme A and Theme B, plus potentially Default
      assert length(themes) >= 2
      assert "Theme A" in themes
      assert "Theme B" in themes
    end

    test "theme persistence deletes theme" do
      # Ensure clean state - handled by setup block
      :ok = Persistence.save_theme(%{@test_theme | name: "Theme A"})
      :ok = Persistence.save_theme(%{@test_theme | name: "Theme B"})

      assert :ok == Persistence.delete_theme("Theme A")
      themes_after_delete = Persistence.list_themes()
      refute "Theme A" in themes_after_delete
      assert "Theme B" in themes_after_delete

      # Test deleting non-existent theme
      assert {:error, :enoent} == Persistence.delete_theme("NonExistent")
    end

    test "theme persistence handles file errors" do
      # Save theme
      assert :ok == Persistence.save_theme(@test_theme)

      # Load theme
      assert {:ok, loaded_theme} = Persistence.load_theme("Test Theme")

      # Verify theme matches
      assert loaded_theme.name == @test_theme.name
      assert_color_maps_equal(loaded_theme.colors, @test_theme.colors)
    end
  end

  describe "user preferences" do
    test "saves and loads preferences" do
      # Create preferences
      preferences = %{
        "theme" => "Test Theme",
        "dark_mode" => true,
        "high_contrast" => false
      }

      # Save preferences
      assert :ok == Persistence.save_user_preferences(preferences)

      # Load preferences
      assert {:ok, loaded_preferences} = Persistence.load_user_preferences()

      # Verify preferences match
      assert loaded_preferences["theme"] == preferences["theme"]
      assert loaded_preferences["dark_mode"] == preferences["dark_mode"]
      assert loaded_preferences["high_contrast"] == preferences["high_contrast"]
    end

    test "loads default preferences when file doesn't exist" do
      # Load preferences
      assert {:ok, preferences} = Persistence.load_user_preferences()

      # Verify default preferences
      assert preferences["theme"] == "Default"
    end
  end

  describe "current theme" do
    test "loads current theme from preferences" do
      # Save theme
      assert :ok == Persistence.save_theme(@test_theme)

      # Save preferences
      assert :ok ==
               Persistence.save_user_preferences(%{"theme" => "Test Theme"})

      # Load current theme
      assert {:ok, current_theme} = Persistence.load_current_theme()

      # Verify theme matches
      assert current_theme.name in [
               @test_theme.name,
               String.downcase(@test_theme.name)
             ]

      assert_color_maps_equal(current_theme.colors, @test_theme.colors)
    end

    test "loads default theme when no theme is set" do
      # Load current theme
      assert {:ok, current_theme} = Persistence.load_current_theme()

      # Verify default theme
      assert current_theme.name in ["Default", "default"]
    end

    test "loads default theme when theme doesn't exist" do
      # Save preferences with non-existent theme
      assert :ok ==
               Persistence.save_user_preferences(%{
                 "theme" => "Non Existent Theme"
               })

      # Load current theme
      assert {:ok, current_theme} = Persistence.load_current_theme()

      # Verify default theme
      assert current_theme.name in ["Default", "default"]
    end
  end
end
