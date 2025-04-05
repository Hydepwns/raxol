defmodule Raxol.Style.Colors.HotReloadTest do
  use ExUnit.Case
  
  alias Raxol.Style.Colors.{Theme, Palette, Persistence, HotReload}
  
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
  
  setup do
    # Create temporary directory for test files
    tmp_dir = Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1000000)}")
    File.mkdir_p!(tmp_dir)
    
    # Create test theme file
    theme_path = Path.join(tmp_dir, "test_theme.json")
    {:ok, _} = Persistence.save_theme(@test_theme, theme_path)
    
    # Override config directory for tests
    Application.put_env(:raxol, :config_dir, tmp_dir)
    
    # Start hot reload server
    {:ok, pid} = HotReload.start_link(theme_path: theme_path, poll_interval: 100)
    
    on_exit(fn ->
      HotReload.stop()
      File.rm_rf!(tmp_dir)
    end)
    
    {:ok, %{tmp_dir: tmp_dir, theme_path: theme_path, pid: pid}}
  end
  
  describe "theme hot reloading" do
    test "detects theme file changes", %{theme_path: theme_path} do
      # Subscribe to theme changes
      HotReload.subscribe()
      
      # Modify the theme file
      new_theme = %{@test_theme | name: "Updated Theme"}
      {:ok, _} = Persistence.save_theme(new_theme, theme_path)
      
      # Wait for change detection
      assert_receive {:theme_changed, loaded_theme}, 1000
      assert loaded_theme.name == "Updated Theme"
    end
    
    test "notifies multiple subscribers", %{theme_path: theme_path} do
      # Subscribe two processes
      HotReload.subscribe()
      HotReload.subscribe()
      
      # Modify the theme file
      new_theme = %{@test_theme | name: "Multi-Theme"}
      {:ok, _} = Persistence.save_theme(new_theme, theme_path)
      
      # Both processes should receive the notification
      assert_receive {:theme_changed, loaded_theme}, 1000
      assert loaded_theme.name == "Multi-Theme"
      assert_receive {:theme_changed, loaded_theme}, 1000
      assert loaded_theme.name == "Multi-Theme"
    end
    
    test "handles subscriber unsubscribe", %{theme_path: theme_path} do
      # Subscribe and then unsubscribe
      HotReload.subscribe()
      HotReload.unsubscribe()
      
      # Modify the theme file
      new_theme = %{@test_theme | name: "Unsubscribed Theme"}
      {:ok, _} = Persistence.save_theme(new_theme, theme_path)
      
      # Should not receive notification
      refute_receive {:theme_changed, _}, 1000
    end
    
    test "forces theme reload", %{theme_path: theme_path} do
      # Subscribe to theme changes
      HotReload.subscribe()
      
      # Force a reload
      HotReload.reload()
      
      # Should receive notification with current theme
      assert_receive {:theme_changed, loaded_theme}, 1000
      assert loaded_theme.name == "Test Theme"
    end
    
    test "handles missing theme file gracefully", %{theme_path: theme_path} do
      # Subscribe to theme changes
      HotReload.subscribe()
      
      # Delete the theme file
      File.rm!(theme_path)
      
      # Should not crash
      Process.sleep(100)
      assert Process.alive?(HotReload)
    end
    
    test "handles invalid theme file gracefully", %{theme_path: theme_path} do
      # Subscribe to theme changes
      HotReload.subscribe()
      
      # Write invalid JSON to the theme file
      File.write!(theme_path, "invalid json")
      
      # Should not crash
      Process.sleep(100)
      assert Process.alive?(HotReload)
    end
  end
end 