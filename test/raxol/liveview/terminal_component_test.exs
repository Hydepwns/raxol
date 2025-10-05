defmodule Raxol.LiveView.TerminalComponentTest do
  use ExUnit.Case, async: true

  alias Raxol.LiveView.TerminalComponent
  alias Raxol.LiveView.Renderer

  @moduletag :raxol_liveview

  @simple_buffer %{
    lines: [
      %{cells: [%{char: "H", style: %{}}, %{char: "i", style: %{}}]}
    ],
    width: 2,
    height: 1
  }

  # Helper to create a minimal socket structure
  defp make_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}, renderer: Renderer.new()}, assigns)
    }
  end

  describe "mount/1" do
    test "initializes with renderer and nil theme_css" do
      {:ok, socket} = TerminalComponent.mount(make_socket())

      assert socket.assigns.renderer != nil
      assert socket.assigns.theme_css == nil
    end
  end

  describe "update/2" do
    test "handles buffer assignment" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", buffer: @simple_buffer}, socket)

      assert updated_socket.assigns.buffer == @simple_buffer
      assert updated_socket.assigns.id == "test"
    end

    test "uses default theme when not specified" do
      socket = make_socket()

      {:ok, updated_socket} = TerminalComponent.update(%{id: "test"}, socket)

      assert updated_socket.assigns.theme == :synthwave84
    end

    test "accepts custom theme atom" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", theme: :nord}, socket)

      assert updated_socket.assigns.theme == :nord
      assert updated_socket.assigns.theme_css != nil
    end

    test "uses default dimensions when not specified" do
      socket = make_socket()

      {:ok, updated_socket} = TerminalComponent.update(%{id: "test"}, socket)

      assert updated_socket.assigns.width == 80
      assert updated_socket.assigns.height == 24
    end

    test "accepts custom dimensions" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", width: 100, height: 30}, socket)

      assert updated_socket.assigns.width == 100
      assert updated_socket.assigns.height == 30
    end

    test "creates blank buffer when none provided" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", width: 10, height: 5}, socket)

      assert updated_socket.assigns.buffer.width == 10
      assert updated_socket.assigns.buffer.height == 5
      assert length(updated_socket.assigns.buffer.lines) == 5
    end

    test "handles crt_mode flag" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", crt_mode: true}, socket)

      assert updated_socket.assigns.crt_mode == true
    end

    test "handles high_contrast flag" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", high_contrast: true}, socket)

      assert updated_socket.assigns.high_contrast == true
    end

    test "sets aria_label" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(
          %{id: "test", aria_label: "Custom terminal"},
          socket
        )

      assert updated_socket.assigns.aria_label == "Custom terminal"
    end

    test "uses default aria_label when not provided" do
      socket = make_socket()

      {:ok, updated_socket} = TerminalComponent.update(%{id: "test"}, socket)

      assert updated_socket.assigns.aria_label == "Interactive terminal"
    end

    test "generates terminal HTML from buffer" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", buffer: @simple_buffer}, socket)

      assert is_binary(updated_socket.assigns.terminal_html)
      assert updated_socket.assigns.terminal_html =~ "raxol-terminal"
    end

    test "regenerates theme CSS when theme changes" do
      socket = make_socket(%{current_theme: :synthwave84, theme_css: "old-css"})

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", theme: :nord}, socket)

      assert updated_socket.assigns.current_theme == :nord
      assert updated_socket.assigns.theme_css != "old-css"
      assert updated_socket.assigns.theme_css != nil
    end

    test "keeps theme CSS when theme unchanged" do
      theme_css = "existing-css"
      socket = make_socket(%{current_theme: :nord, theme_css: theme_css})

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", theme: :nord}, socket)

      assert updated_socket.assigns.theme_css == theme_css
    end

    test "handles all built-in themes" do
      themes = [
        :synthwave84,
        :nord,
        :dracula,
        :monokai,
        :gruvbox,
        :solarized_dark,
        :tokyo_night
      ]

      socket = make_socket()

      for theme <- themes do
        {:ok, updated_socket} =
          TerminalComponent.update(%{id: "test-#{theme}", theme: theme}, socket)

        assert updated_socket.assigns.theme == theme
        assert updated_socket.assigns.theme_css != nil
      end
    end

    test "stores event handler names" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(
          %{
            id: "test",
            on_keypress: "handle_key",
            on_cell_click: "handle_click"
          },
          socket
        )

      assert updated_socket.assigns.on_keypress == "handle_key"
      assert updated_socket.assigns.on_cell_click == "handle_click"
    end
  end

  # Note: Full render/1 tests require LiveView test helpers and are better
  # tested via integration tests. The update/2 tests above cover the business logic.

  describe "blank buffer creation" do
    test "creates buffer with correct dimensions" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", width: 5, height: 3}, socket)

      buffer = updated_socket.assigns.buffer

      assert buffer.width == 5
      assert buffer.height == 3
      assert length(buffer.lines) == 3
      assert length(hd(buffer.lines).cells) == 5
    end

    test "blank buffer cells have empty spaces" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", width: 2, height: 1}, socket)

      buffer = updated_socket.assigns.buffer
      first_cell = hd(hd(buffer.lines).cells)

      assert first_cell.char == " "
      assert first_cell.style.bold == false
      assert first_cell.style.italic == false
      assert first_cell.style.underline == false
      assert first_cell.style.reverse == false
      assert first_cell.style.fg_color == nil
      assert first_cell.style.bg_color == nil
    end
  end

  describe "edge cases" do
    test "handles very small buffer (1x1)" do
      socket = make_socket()

      buffer = %{
        lines: [%{cells: [%{char: "X", style: %{}}]}],
        width: 1,
        height: 1
      }

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", buffer: buffer}, socket)

      assert updated_socket.assigns.buffer == buffer
      assert is_binary(updated_socket.assigns.terminal_html)
    end

    test "handles large buffer (200x50)" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(%{id: "test", width: 200, height: 50}, socket)

      assert updated_socket.assigns.width == 200
      assert updated_socket.assigns.height == 50
      assert length(updated_socket.assigns.buffer.lines) == 50
    end

    test "handles unknown theme gracefully" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(
          %{id: "test", theme: :nonexistent_theme},
          socket
        )

      # Should fall back to synthwave84
      assert updated_socket.assigns.theme == :nonexistent_theme
      assert updated_socket.assigns.theme_css != nil
    end

    test "handles nil event handlers" do
      socket = make_socket()

      {:ok, updated_socket} =
        TerminalComponent.update(
          %{id: "test", on_keypress: nil, on_cell_click: nil},
          socket
        )

      assert updated_socket.assigns.on_keypress == nil
      assert updated_socket.assigns.on_cell_click == nil
    end
  end
end
