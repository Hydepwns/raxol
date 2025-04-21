defmodule Raxol.Style.Colors.HotReloadTest do
  # Run tests serially to avoid GenServer name conflict
  use ExUnit.Case

  alias Raxol.Style.Colors.{HotReload, Theme}

  @test_theme %{
    name: "Test Theme",
    palette: %{
      name: "Test Palette",
      colors: %{
        primary: "#FF0000",
        secondary: "#00FF00",
        background: "#000000",
        foreground: "#FFFFFF"
      }
    },
    ui_mappings: %{
      app_background: :background,
      app_foreground: :foreground
    },
    dark_mode: true,
    high_contrast: false
  }

  # setup_all runs once for the file
  setup_all do
    # Create temporary directory for theme files
    tmp_dir =
      Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1_000_000)}")

    File.mkdir_p!(tmp_dir)

    # Start the hot-reload server once for all tests in this file
    # Since it uses a global name, we manage it centrally.
    # {:ok, pid} = HotReload.start_link() # Use original start_link here
    # Ensure the globally started server is watching the test path
    HotReload.watch_path(tmp_dir)

    # Store pid and tmp_dir for cleanup and use in tests
    # context = %{hot_reload_pid: pid, tmp_dir: tmp_dir} # <-- REMOVE PID STORAGE
    # <-- Keep tmp_dir storage
    context = %{tmp_dir: tmp_dir}

    # Cleanup runs once after all tests
    on_exit(fn ->
      # Stop the server manually if needed (though supervisor should handle)
      # GenServer.stop(pid)
      File.rm_rf!(tmp_dir)
    end)

    context
  end

  # setup runs before each test
  # Receive tmp_dir from setup_all context
  setup %{tmp_dir: tmp_dir} do
    # Subscribe this test process to the single HotReload server
    HotReload.subscribe()

    # No need for on_exit cleanup specific to each test here
    # The server persists, tmp_dir cleanup is in setup_all

    # Pass tmp_dir along to the test case
    %{tmp_dir: tmp_dir}
  end

  describe "theme hot-reloading" do
    test "detects and reloads theme changes", %{tmp_dir: tmp_dir} do
      # Create initial theme file
      theme_path = Path.join(tmp_dir, "test_theme.json")
      File.write!(theme_path, Jason.encode!(@test_theme))

      # Wait for theme to be loaded
      assert_receive {:theme_reloaded, theme}, 5000
      assert theme.name == "Test Theme"

      # Modify theme file
      updated_theme = %{@test_theme | name: "Updated Theme"}
      File.write!(theme_path, Jason.encode!(updated_theme))

      # Wait for theme to be reloaded
      assert_receive {:theme_reloaded, theme}, 5000
      assert theme.name == "Updated Theme"
    end

    test "handles multiple theme files", %{tmp_dir: tmp_dir} do
      # Create multiple theme files
      theme1_path = Path.join(tmp_dir, "theme1.json")
      theme2_path = Path.join(tmp_dir, "theme2.json")

      File.write!(theme1_path, Jason.encode!(%{@test_theme | name: "Theme 1"}))
      File.write!(theme2_path, Jason.encode!(%{@test_theme | name: "Theme 2"}))

      # Wait for both themes to be loaded
      assert_receive {:theme_reloaded, theme1}, 5000
      assert_receive {:theme_reloaded, theme2}, 5000

      assert theme1.name == "Theme 1"
      assert theme2.name == "Theme 2"

      # Modify one theme
      File.write!(
        theme1_path,
        Jason.encode!(%{@test_theme | name: "Updated Theme 1"})
      )

      # Wait for theme to be reloaded
      assert_receive {:theme_reloaded, theme}, 5000
      assert theme.name == "Updated Theme 1"
    end

    test "handles invalid theme files", %{tmp_dir: tmp_dir} do
      # Create invalid theme file
      theme_path = Path.join(tmp_dir, "invalid_theme.json")
      File.write!(theme_path, "invalid json")

      # Should not receive any theme reloaded messages
      refute_receive {:theme_reloaded, _theme}, 1000
    end

    test "handles file deletion", %{tmp_dir: tmp_dir} do
      # Create theme file
      theme_path = Path.join(tmp_dir, "test_theme.json")
      File.write!(theme_path, Jason.encode!(@test_theme))

      # Wait for theme to be loaded
      assert_receive {:theme_reloaded, theme}, 5000
      assert theme.name == "Test Theme"

      # Delete theme file
      File.rm!(theme_path)

      # Should not receive any theme reloaded messages
      refute_receive {:theme_reloaded, _theme}, 1000
    end
  end

  describe "subscriber management" do
    test "handles multiple subscribers", %{tmp_dir: tmp_dir} do
      # Create another subscriber
      HotReload.subscribe()

      # Create theme file
      theme_path = Path.join(tmp_dir, "test_theme.json")
      File.write!(theme_path, Jason.encode!(@test_theme))

      # Both subscribers should receive the theme
      assert_receive {:theme_reloaded, theme}, 5000
      assert_receive {:theme_reloaded, theme}, 5000
      assert theme.name == "Test Theme"
    end

    test "handles subscriber unsubscribe", %{tmp_dir: tmp_dir} do
      # Unsubscribe
      HotReload.unsubscribe()

      # Create theme file
      theme_path = Path.join(tmp_dir, "test_theme.json")
      File.write!(theme_path, Jason.encode!(@test_theme))

      # Should not receive any theme reloaded messages
      refute_receive {:theme_reloaded, _theme}, 1000
    end
  end
end
