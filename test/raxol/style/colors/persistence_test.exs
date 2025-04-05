defmodule Raxol.Style.Colors.PersistenceTest do
  use ExUnit.Case
  
  alias Raxol.Style.Colors.{Theme, Palette, Persistence}
  
  @test_theme %Theme{
    name: "Test Theme",
    palette: %Palette{
      name: "Test Palette",
      colors: %{
        primary: Raxol.Style.Colors.Color.from_hex("#FF0000"),
        secondary: Raxol.Style.Colors.Color.from_hex("#00FF00"),
        background: Raxol.Style.Colors.Color.from_hex("#000000")
      },
      primary: :primary,
      secondary: :secondary,
      accent: :primary,
      background: :background,
      foreground: :primary
    },
    ui_mappings: %{
      button: :primary,
      text: :secondary
    },
    dark_mode: true,
    high_contrast: false
  }
  
  @test_preferences %{
    "theme" => "test_theme",
    "high_contrast" => true,
    "font_size" => 14
  }
  
  setup do
    # Create temporary directory for test files
    tmp_dir = Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1000000)}")
    File.mkdir_p!(tmp_dir)
    
    # Override config directory for tests
    Application.put_env(:raxol, :config_dir, tmp_dir)
    
    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)
    
    {:ok, tmp_dir: tmp_dir}
  end
  
  describe "theme persistence" do
    test "save_theme saves theme to file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "test_theme.json")
      
      assert {:ok, saved_path} = Persistence.save_theme(@test_theme, path)
      assert saved_path == path
      assert File.exists?(path)
      
      # Verify file contents
      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      
      assert data["name"] == "Test Theme"
      assert data["palette"]["name"] == "Test Palette"
      assert data["palette"]["colors"]["primary"] == "#FF0000"
      assert data["dark_mode"] == true
    end
    
    test "load_theme loads theme from file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "test_theme.json")
      {:ok, _} = Persistence.save_theme(@test_theme, path)
      
      assert {:ok, loaded_theme} = Persistence.load_theme(path)
      assert loaded_theme.name == "Test Theme"
      assert loaded_theme.palette.name == "Test Palette"
      assert loaded_theme.dark_mode == true
      assert loaded_theme.high_contrast == false
    end
    
    test "load_theme returns error for non-existent file" do
      assert {:error, :theme_not_found} = Persistence.load_theme("/nonexistent/path/theme.json")
    end
  end
  
  describe "user preferences" do
    test "save_user_preferences saves preferences to file", %{tmp_dir: tmp_dir} do
      user_id = "test_user"
      path = Path.join(tmp_dir, "users", user_id, "preferences.json")
      
      assert :ok = Persistence.save_user_preferences(user_id, @test_preferences)
      assert File.exists?(path)
      
      # Verify file contents
      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      
      assert data["theme"] == "test_theme"
      assert data["high_contrast"] == true
      assert data["font_size"] == 14
    end
    
    test "load_user_preferences loads preferences from file", %{tmp_dir: tmp_dir} do
      user_id = "test_user"
      path = Path.join(tmp_dir, "users", user_id, "preferences.json")
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, Jason.encode!(@test_preferences))
      
      assert {:ok, loaded_prefs} = Persistence.load_user_preferences(user_id)
      assert loaded_prefs["theme"] == "test_theme"
      assert loaded_prefs["high_contrast"] == true
      assert loaded_prefs["font_size"] == 14
    end
    
    test "load_user_preferences returns empty map for non-existent file" do
      assert {:ok, %{}} = Persistence.load_user_preferences("nonexistent_user")
    end
  end
  
  describe "path helpers" do
    test "default_theme_path returns correct path" do
      path = Persistence.default_theme_path()
      assert String.ends_with?(path, "/themes/current.json")
    end
    
    test "user_preferences_path returns correct path" do
      user_id = "test_user"
      path = Persistence.user_preferences_path(user_id)
      assert String.ends_with?(path, "/users/test_user/preferences.json")
    end
  end
end 