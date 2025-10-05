defmodule RaxolWeb.ThemesTest do
  use ExUnit.Case, async: true

  alias RaxolWeb.Themes

  @moduletag :raxol_web

  describe "get/1" do
    test "returns synthwave84 theme" do
      theme = Themes.get(:synthwave84)
      assert theme.name == :synthwave84
      assert theme.background == "#2b213a"
      assert theme.foreground == "#f0eff1"
      assert is_map(theme.colors)
    end

    test "returns nord theme" do
      theme = Themes.get(:nord)
      assert theme.name == :nord
      assert theme.background == "#2e3440"
      assert theme.foreground == "#d8dee9"
    end

    test "returns dracula theme" do
      theme = Themes.get(:dracula)
      assert theme.name == :dracula
      assert theme.background == "#282a36"
    end

    test "returns monokai theme" do
      theme = Themes.get(:monokai)
      assert theme.name == :monokai
      assert theme.background == "#272822"
    end

    test "returns gruvbox theme" do
      theme = Themes.get(:gruvbox)
      assert theme.name == :gruvbox
      assert theme.background == "#282828"
    end

    test "returns solarized_dark theme" do
      theme = Themes.get(:solarized_dark)
      assert theme.name == :solarized_dark
      assert theme.background == "#002b36"
    end

    test "returns tokyo_night theme" do
      theme = Themes.get(:tokyo_night)
      assert theme.name == :tokyo_night
      assert theme.background == "#1a1b26"
    end

    test "returns nil for unknown theme" do
      assert Themes.get(:nonexistent) == nil
    end
  end

  describe "list/0" do
    test "returns all available theme names" do
      themes = Themes.list()
      assert length(themes) == 7
      assert :synthwave84 in themes
      assert :nord in themes
      assert :dracula in themes
      assert :monokai in themes
      assert :gruvbox in themes
      assert :solarized_dark in themes
      assert :tokyo_night in themes
    end
  end

  describe "to_css/2" do
    test "generates valid CSS for a theme" do
      theme = Themes.get(:synthwave84)
      css = Themes.to_css(theme)

      assert is_binary(css)
      assert css =~ ".raxol-terminal"
      assert css =~ "background-color: #{theme.background}"
      assert css =~ "color: #{theme.foreground}"
      assert css =~ ".raxol-cursor"
      assert css =~ ".raxol-fg-red"
      assert css =~ ".raxol-bg-green"
      assert css =~ ".raxol-bold"
      assert css =~ ".raxol-italic"
      assert css =~ ".raxol-underline"
      assert css =~ ".raxol-reverse"
    end

    test "generates CSS with custom selector" do
      theme = Themes.get(:nord)
      css = Themes.to_css(theme, ".my-terminal")

      assert css =~ ".my-terminal"
      assert css =~ ".my-terminal .raxol-cursor"
      refute css =~ ".raxol-terminal"
    end

    test "includes all standard colors" do
      theme = Themes.get(:dracula)
      css = Themes.to_css(theme)

      assert css =~ ".raxol-fg-black"
      assert css =~ ".raxol-fg-red"
      assert css =~ ".raxol-fg-green"
      assert css =~ ".raxol-fg-yellow"
      assert css =~ ".raxol-fg-blue"
      assert css =~ ".raxol-fg-magenta"
      assert css =~ ".raxol-fg-cyan"
      assert css =~ ".raxol-fg-white"
    end

    test "includes all bright colors" do
      theme = Themes.get(:monokai)
      css = Themes.to_css(theme)

      assert css =~ ".raxol-fg-bright-black"
      assert css =~ ".raxol-fg-bright-red"
      assert css =~ ".raxol-fg-bright-green"
      assert css =~ ".raxol-fg-bright-yellow"
      assert css =~ ".raxol-fg-bright-blue"
      assert css =~ ".raxol-fg-bright-magenta"
      assert css =~ ".raxol-fg-bright-cyan"
      assert css =~ ".raxol-fg-bright-white"
    end

    test "works for all themes" do
      for theme_name <- Themes.list() do
        theme = Themes.get(theme_name)
        css = Themes.to_css(theme)
        assert is_binary(css)
        assert String.length(css) > 0
      end
    end
  end

  describe "theme structure" do
    test "all themes have required fields" do
      for theme_name <- Themes.list() do
        theme = Themes.get(theme_name)

        assert theme.name == theme_name
        assert is_binary(theme.background)
        assert is_binary(theme.foreground)
        assert is_binary(theme.cursor)
        assert is_binary(theme.selection)

        # Check colors structure
        assert is_map(theme.colors)
        assert is_binary(theme.colors.black)
        assert is_binary(theme.colors.red)
        assert is_binary(theme.colors.green)
        assert is_binary(theme.colors.yellow)
        assert is_binary(theme.colors.blue)
        assert is_binary(theme.colors.magenta)
        assert is_binary(theme.colors.cyan)
        assert is_binary(theme.colors.white)
        assert is_binary(theme.colors.bright_black)
        assert is_binary(theme.colors.bright_red)
        assert is_binary(theme.colors.bright_green)
        assert is_binary(theme.colors.bright_yellow)
        assert is_binary(theme.colors.bright_blue)
        assert is_binary(theme.colors.bright_magenta)
        assert is_binary(theme.colors.bright_cyan)
        assert is_binary(theme.colors.bright_white)
      end
    end

    test "all color values are valid hex codes" do
      hex_pattern = ~r/^#[0-9a-fA-F]{6}$/

      for theme_name <- Themes.list() do
        theme = Themes.get(theme_name)

        assert theme.background =~ hex_pattern
        assert theme.foreground =~ hex_pattern
        assert theme.cursor =~ hex_pattern
        assert theme.selection =~ hex_pattern

        for {_color_name, color_value} <- theme.colors do
          assert color_value =~ hex_pattern,
                 "Invalid hex color in #{theme_name}: #{inspect(color_value)}"
        end
      end
    end
  end
end
