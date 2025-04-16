defmodule Raxol.Style.Colors.PersistenceTest do
  use ExUnit.Case, async: true

  alias Raxol.Style.Colors.Persistence
  alias Raxol.Style.Colors.Theme

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
    # Clean up any existing theme files
    File.rm_rf!("themes")
    File.rm("preferences.json")

    :ok
  end

  describe "theme persistence" do
    test "saves and loads theme" do
      # Save theme
      assert :ok == Persistence.save_theme(@test_theme)

      # Load theme
      assert {:ok, loaded_theme} = Persistence.load_theme(@test_theme.name)

      # Verify theme matches
      assert loaded_theme.name == @test_theme.name
      assert loaded_theme.palette == @test_theme.palette
      assert loaded_theme.ui_mappings == @test_theme.ui_mappings
      assert loaded_theme.dark_mode == @test_theme.dark_mode
      assert loaded_theme.high_contrast == @test_theme.high_contrast
    end

    test "loads non-existent theme" do
      # Try to load non-existent theme
      assert {:error, :enoent} = Persistence.load_theme("Non Existent Theme")
    end

    test "lists themes" do
      # Save multiple themes
      assert :ok == Persistence.save_theme(@test_theme)

      assert :ok ==
               Persistence.save_theme(%{@test_theme | name: "Another Theme"})

      # List themes
      themes = Persistence.list_themes()

      # Verify themes
      assert length(themes) == 2
      assert "Test Theme" in themes
      assert "Another Theme" in themes
    end

    test "deletes theme" do
      # Save theme
      assert :ok == Persistence.save_theme(@test_theme)

      # Delete theme
      assert :ok == Persistence.delete_theme(@test_theme.name)

      # Verify theme is deleted
      assert {:error, :enoent} = Persistence.load_theme(@test_theme.name)
      assert [] == Persistence.list_themes()
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
               Persistence.save_user_preferences(%{"theme" => @test_theme.name})

      # Load current theme
      assert {:ok, current_theme} = Persistence.load_current_theme()

      # Verify theme matches
      assert current_theme.name == @test_theme.name
      assert current_theme.palette == @test_theme.palette
      assert current_theme.ui_mappings == @test_theme.ui_mappings
    end

    test "loads default theme when no theme is set" do
      # Load current theme
      assert {:ok, current_theme} = Persistence.load_current_theme()

      # Verify default theme
      assert current_theme.name == "Default"
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
      assert current_theme.name == "Default"
    end
  end
end
