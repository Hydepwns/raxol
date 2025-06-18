defmodule Raxol.UI.ThemeHandlingTest do
  use ExUnit.Case
  alias Raxol.UI.Renderer
  alias Raxol.UI.RendererTestHelper, as: Helper
  import Raxol.Test.Visual.Assertions
  alias Raxol.UI.Theming.Theme

  test 'handles missing themes' do
    element = Helper.create_test_box(0, 0, 5, 5, %{theme: "nonexistent"})
    cells = Renderer.render_to_cells(element)

    # Should use default theme
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black)
  end

  test 'handles missing theme colors' do
    theme = Helper.create_test_theme("test", "Test Theme", "Test theme", %{})
    element = Helper.create_test_box(0, 0, 5, 5, %{theme: theme})
    cells = Renderer.render_to_cells(element)

    # Should use default colors
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black)
  end

  test 'handles style overrides' do
    theme =
      Helper.create_test_theme("test", "Test Theme", "Test theme", %{
        foreground: :red,
        background: :blue
      })

    element =
      Helper.create_test_box(0, 0, 5, 5, %{
        theme: theme,
        style: %{foreground: :green, background: :yellow}
      })

    cells = Renderer.render_to_cells(element)

    # Style should override theme
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :green, :yellow)
  end

  test 'handles border style overrides' do
    theme =
      Helper.create_test_theme("test", "Test Theme", "Test theme", %{
        border_style: %{type: :double}
      })

    element =
      Helper.create_test_box(0, 0, 5, 5, %{
        theme: theme,
        border_style: %{type: :single}
      })

    cells = Renderer.render_to_cells(element)

    # Border style should be overridden
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [:single])
  end

  test 'handles default border styles' do
    element = Helper.create_test_box(0, 0, 5, 5)
    cells = Renderer.render_to_cells(element)

    # Should use default border style
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [:single])
  end

  test 'handles no borders' do
    element = Helper.create_test_box(0, 0, 5, 5, %{border: false})
    cells = Renderer.render_to_cells(element)

    # Should not have border style
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [])
  end

  test 'handles theme inheritance' do
    parent_theme =
      Helper.create_test_theme("parent", "Parent Theme", "Parent theme", %{
        foreground: :red,
        background: :blue
      })

    child_theme =
      Helper.create_test_theme("child", "Child Theme", "Child theme", %{
        foreground: :green
      })

    element =
      Helper.create_test_box(0, 0, 5, 5, %{
        theme: child_theme,
        parent_theme: parent_theme
      })

    cells = Renderer.render_to_cells(element)

    # Should inherit background from parent
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :green, :blue)
  end

  test 'handles theme variants' do
    theme =
      Helper.create_test_theme("test", "Test Theme", "Test theme", %{
        variants: %{
          "error" => %{foreground: :red},
          "success" => %{foreground: :green}
        }
      })

    element =
      Helper.create_test_box(0, 0, 5, 5, %{
        theme: theme,
        variant: "error"
      })

    cells = Renderer.render_to_cells(element)

    # Should use error variant
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :red, :black)
  end

  test 'theme initialization' do
    theme =
      Helper.create_test_theme(
        "test",
        %{
          primary: "#FF0000",
          secondary: "#00FF00"
        },
        %{
          button: %{background: "#000000"}
        },
        %{
          default: %{family: "monospace"}
        }
      )

    assert theme.name == "test"
    assert theme.colors.primary == "#FF0000"
    assert theme.styles.button.background == "#000000"
    assert theme.fonts.default.family == "monospace"
  end

  test 'theme merging' do
    base_theme =
      Helper.create_test_theme(
        "test",
        %{
          primary: "#FF0000",
          secondary: "#00FF00"
        },
        %{
          button: %{background: "#000000"}
        },
        %{
          default: %{family: "monospace"}
        }
      )

    override_theme =
      Helper.create_test_theme(
        "test",
        %{
          primary: "#0000FF"
        },
        %{
          button: %{text: "#FFFFFF"}
        },
        %{
          default: %{size: 14}
        }
      )

    merged = Theme.merge(base_theme, override_theme)

    assert merged.colors.primary == "#0000FF"
    assert merged.colors.secondary == "#00FF00"
    assert merged.styles.button.background == "#000000"
    assert merged.styles.button.text == "#FFFFFF"
    assert merged.fonts.default.family == "monospace"
    assert merged.fonts.default.size == 14
  end

  test 'theme inheritance' do
    parent_theme =
      Helper.create_test_theme(
        "parent",
        %{
          primary: "#FF0000",
          secondary: "#00FF00"
        },
        %{
          button: %{background: "#000000"}
        },
        %{
          default: %{family: "monospace"}
        }
      )

    child_theme =
      Helper.create_test_theme(
        "child",
        %{
          primary: "#0000FF"
        },
        %{
          button: %{text: "#FFFFFF"}
        },
        %{
          default: %{size: 14}
        }
      )

    inherited = Theme.inherit(parent_theme, child_theme)

    assert inherited.colors.primary == "#0000FF"
    assert inherited.colors.secondary == "#00FF00"
    assert inherited.styles.button.background == "#000000"
    assert inherited.styles.button.text == "#FFFFFF"
    assert inherited.fonts.default.family == "monospace"
    assert inherited.fonts.default.size == 14
  end

  test 'theme access' do
    theme =
      Helper.create_test_theme(
        "test",
        %{
          primary: "#FF0000",
          secondary: "#00FF00"
        },
        %{
          button: %{background: "#000000"}
        },
        %{
          default: %{family: "monospace"}
        }
      )

    assert Theme.get(theme, [:colors, :primary]) == "#FF0000"
    assert Theme.get(theme, [:styles, :button, :background]) == "#000000"
    assert Theme.get(theme, [:fonts, :default, :family]) == "monospace"
  end
end
