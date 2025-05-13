defmodule Raxol.Style.Colors.SystemTest do
  # Changed to false to prevent concurrent access to shared state
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Style.Colors.{Color, System, Theme}
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.UI.Theming.Theme

  # Define mocks
  defmock(EventManagerMock, for: Raxol.Core.Events.Manager.Behaviour)

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

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Clean up any existing theme files
    File.rm_rf!("themes")
    File.mkdir_p!("themes")

    # Initialize system with mocked event manager
    Application.put_env(:raxol, :event_manager, EventManagerMock)
    System.init()

    # Stub event manager for all tests
    stub_with(EventManagerMock, EventManager)

    # Set up test theme
    @test_theme =
      Theme.new(%{
        id: :test_theme,
        name: "Test Theme",
        colors: %{
          primary: Color.from_hex("#0077CC"),
          secondary: Color.from_hex("#666666"),
          background: Color.from_hex("#FFFFFF"),
          text: Color.from_hex("#333333")
        }
      })

    {:ok, %{event_manager: EventManagerMock}}
  end

  describe "theme management" do
    test "applies a theme", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply theme
      assert :ok == System.apply_theme(@test_theme)

      # Verify theme was saved
      assert {:ok, saved_theme} = Persistence.load_theme(@test_theme.name)
      assert saved_theme.name == @test_theme.name
      assert saved_theme.palette == @test_theme.palette
      assert saved_theme.ui_mappings == @test_theme.ui_mappings

      # Verify current theme
      assert System.get_current_theme_name() == :test_theme
    end

    test "gets current theme", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply a specific theme
      assert :ok == System.apply_theme(:dark)

      # Verify current theme
      assert System.get_current_theme_name() == :dark
    end

    test "gets UI color", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply standard theme
      assert :ok == System.apply_theme(:standard)

      # Get UI color
      color = System.get_ui_color(:primary_button)
      assert color != nil
      assert is_map(color)
      assert Map.has_key?(color, :r)
      assert Map.has_key?(color, :g)
      assert Map.has_key?(color, :b)
      assert Map.has_key?(color, :a)
    end

    test "gets all UI colors", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply standard theme
      assert :ok == System.apply_theme(:standard)

      # Get all UI colors
      colors = System.get_all_ui_colors()
      assert is_map(colors)
      assert Map.has_key?(colors, :primary_button)
      assert Map.has_key?(colors, :secondary_button)
      assert Map.has_key?(colors, :accent_button)
      assert Map.has_key?(colors, :error_text)
      assert Map.has_key?(colors, :success_text)
      assert Map.has_key?(colors, :warning_text)
      assert Map.has_key?(colors, :info_text)
    end

    test "gets color from theme", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Get color
      color = System.get_color(:primary)
      assert color.hex == "#0077CC"
      assert color.rgb == {0, 119, 204}
      assert color.alpha == 1.0
    end

    test "gets color with variant", %{event_manager: event_manager} do
      # Create theme with variant
      theme =
        Theme.new(%{
          id: :test_theme,
          name: "Test Theme",
          colors: %{
            primary: Color.from_hex("#0077CC"),
            background: Color.from_hex("#FFFFFF")
          },
          variants: %{
            high_contrast: %{
              colors: %{
                primary: Color.from_hex("#0000FF"),
                background: Color.from_hex("#000000")
              }
            }
          }
        })

      # Apply theme
      assert :ok == System.apply_theme(theme)

      # Get color with variant
      color = System.get_color(:primary, :high_contrast)
      assert color.hex == "#0000FF"
    end

    test "handles missing color gracefully" do
      # Apply test theme
      assert :ok == System.apply_theme(@test_theme)

      # Try to get non-existent color
      assert nil == System.get_color(:nonexistent)
    end
  end

  describe "theme variants" do
    test "creates dark theme", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply standard theme
      assert :ok == System.apply_theme(:standard)

      # Create dark theme
      dark_theme = System.create_dark_theme()
      assert dark_theme != nil
      assert dark_theme.dark_mode == true

      # Verify dark theme colors are different from standard
      standard_colors = System.get_all_ui_colors()
      dark_colors = System.get_all_ui_colors(dark_theme)

      # Dark theme colors should be different from standard
      assert standard_colors != dark_colors

      # Verify specific color differences
      standard_primary = standard_colors.primary_button
      dark_primary = dark_colors.primary_button
      assert standard_primary != dark_primary
    end

    test "creates high contrast theme", %{event_manager: event_manager} do
      # Expect theme change event
      expect(event_manager, :dispatch, fn event ->
        assert event.type == :theme_changed
        :ok
      end)

      # Apply standard theme
      assert :ok == System.apply_theme(:standard)

      # Create high contrast theme
      high_contrast_theme = System.create_high_contrast_theme()
      assert high_contrast_theme != nil
      assert high_contrast_theme.high_contrast == true

      # Verify high contrast theme colors are different from standard
      standard_colors = System.get_all_ui_colors()
      high_contrast_colors = System.get_all_ui_colors(high_contrast_theme)

      # High contrast theme colors should be different from standard
      assert standard_colors != high_contrast_colors

      # Verify specific color differences
      standard_primary = standard_colors.primary_button
      high_contrast_primary = high_contrast_colors.primary_button
      assert standard_primary != high_contrast_primary
    end
  end

  describe "color manipulation" do
    test "lightens color" do
      color = Color.from_hex("#0077CC")
      lighter = System.lighten_color(color, 0.2)
      assert lighter.r > color.r
      assert lighter.g > color.g
      assert lighter.b > color.b
    end

    test "darkens color" do
      color = Color.from_hex("#0077CC")
      darker = System.darken_color(color, 0.2)
      assert darker.r < color.r
      assert darker.g < color.g
      assert darker.b < color.b
    end

    test "increases contrast" do
      color = Color.from_hex("#808080")
      high_contrast = System.increase_contrast(color)
      assert high_contrast.hex in ["#000000", "#FFFFFF"]
    end
  end

  describe "accessibility" do
    test "meets contrast requirements" do
      fg = Color.from_hex("#FFFFFF")
      bg = Color.from_hex("#000000")
      assert System.meets_contrast_requirements?(fg, bg, :AA, :normal)
    end

    test "adjusts for contrast" do
      fg = Color.from_hex("#808080")
      bg = Color.from_hex("#FFFFFF")
      adjusted = System.adjust_for_contrast(fg, bg, :AA, :normal)
      assert System.meets_contrast_requirements?(adjusted, bg, :AA, :normal)
    end
  end
end
