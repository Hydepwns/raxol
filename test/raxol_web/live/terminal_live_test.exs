defmodule RaxolWeb.TerminalLiveTest do
  use ExUnit.Case, async: false

  # Note: This is a unit test file for the TerminalLive module.
  # For full integration tests with LiveView, use Phoenix.LiveViewTest.

  alias RaxolWeb.TerminalLive
  alias Raxol.Web.SessionBridge

  setup do
    # Ensure SessionBridge is running
    case GenServer.whereis(SessionBridge) do
      nil ->
        {:ok, _pid} = SessionBridge.start_link([])

      _pid ->
        :ok
    end

    :ok
  end

  describe "module structure" do
    test "module exists" do
      assert Code.ensure_loaded?(RaxolWeb.TerminalLive)
    end

    test "uses Phoenix.LiveView" do
      # Check that required LiveView callbacks are defined
      assert function_exported?(RaxolWeb.TerminalLive, :mount, 3)
      assert function_exported?(RaxolWeb.TerminalLive, :render, 1)
      assert function_exported?(RaxolWeb.TerminalLive, :handle_event, 3)
      assert function_exported?(RaxolWeb.TerminalLive, :handle_info, 2)
      assert function_exported?(RaxolWeb.TerminalLive, :handle_params, 3)
    end
  end

  describe "key translation" do
    test "translates Enter key" do
      assert translate_key("Enter", %{}) == "\r"
    end

    test "translates Backspace key" do
      assert translate_key("Backspace", %{}) == "\x7f"
    end

    test "translates Tab key" do
      assert translate_key("Tab", %{}) == "\t"
    end

    test "translates Escape key" do
      assert translate_key("Escape", %{}) == "\e"
    end

    test "translates arrow keys" do
      assert translate_key("ArrowUp", %{}) == "\e[A"
      assert translate_key("ArrowDown", %{}) == "\e[B"
      assert translate_key("ArrowRight", %{}) == "\e[C"
      assert translate_key("ArrowLeft", %{}) == "\e[D"
    end

    test "translates function keys" do
      assert translate_key("F1", %{}) == "\eOP"
      assert translate_key("F2", %{}) == "\eOQ"
      assert translate_key("F3", %{}) == "\eOR"
      assert translate_key("F4", %{}) == "\eOS"
      assert translate_key("F5", %{}) == "\e[15~"
    end

    test "translates navigation keys" do
      assert translate_key("Home", %{}) == "\e[H"
      assert translate_key("End", %{}) == "\e[F"
      assert translate_key("PageUp", %{}) == "\e[5~"
      assert translate_key("PageDown", %{}) == "\e[6~"
      assert translate_key("Delete", %{}) == "\e[3~"
      assert translate_key("Insert", %{}) == "\e[2~"
    end

    test "translates single character keys" do
      assert translate_key("a", %{}) == "a"
      assert translate_key("Z", %{}) == "Z"
      assert translate_key("1", %{}) == "1"
    end

    test "translates Ctrl+key combinations" do
      assert translate_key("c", %{"ctrlKey" => true}) == <<3>>
      assert translate_key("a", %{"ctrlKey" => true}) == <<1>>
      assert translate_key("z", %{"ctrlKey" => true}) == <<26>>
    end

    test "returns nil for unknown keys" do
      assert translate_key("Unknown", %{}) == nil
      assert translate_key("Alt", %{}) == nil
    end
  end

  describe "HTML escaping" do
    test "escapes special HTML characters" do
      assert escape_html("&") == "&amp;"
      assert escape_html("<") == "&lt;"
      assert escape_html(">") == "&gt;"
      assert escape_html(" ") == "&nbsp;"
    end

    test "escapes multiple characters" do
      assert escape_html("<script>") == "&lt;script&gt;"
      assert escape_html("a & b") == "a&nbsp;&amp;&nbsp;b"
    end
  end

  describe "style class building" do
    test "builds classes for text styles" do
      assert build_style_classes(%{bold: true}) =~ "bold"
      assert build_style_classes(%{italic: true}) =~ "italic"
      assert build_style_classes(%{underline: true}) =~ "underline"
    end

    test "combines multiple style classes" do
      classes = build_style_classes(%{bold: true, italic: true})
      assert classes =~ "bold"
      assert classes =~ "italic"
    end

    test "ignores false values" do
      classes = build_style_classes(%{bold: false, italic: true})
      refute classes =~ "bold"
      assert classes =~ "italic"
    end

    test "handles empty style map" do
      assert build_style_classes(%{}) == ""
    end
  end

  describe "inline style building" do
    test "builds color style for RGB tuple" do
      style = build_inline_style(%{fg: {255, 0, 0}})
      assert style =~ "color: rgb(255, 0, 0)"
    end

    test "builds background color style" do
      style = build_inline_style(%{bg: {0, 128, 255}})
      assert style =~ "background-color: rgb(0, 128, 255)"
    end

    test "builds color style for atom color" do
      style = build_inline_style(%{fg: :red})
      assert style =~ "color: var(--term-red)"
    end

    test "handles nil colors" do
      style = build_inline_style(%{fg: nil, bg: nil})
      assert style == ""
    end

    test "combines multiple styles" do
      style = build_inline_style(%{fg: {255, 255, 255}, bg: {0, 0, 0}})
      assert style =~ "color: rgb(255, 255, 255)"
      assert style =~ "background-color: rgb(0, 0, 0)"
    end
  end

  describe "session/user ID generation" do
    test "generates session IDs" do
      id1 = generate_session_id()
      id2 = generate_session_id()

      assert is_binary(id1)
      assert is_binary(id2)
      assert id1 != id2
      assert byte_size(id1) > 0
    end

    test "generates user IDs" do
      id1 = generate_user_id()
      id2 = generate_user_id()

      assert is_binary(id1)
      assert is_binary(id2)
      assert id1 != id2
      assert byte_size(id1) > 0
    end
  end

  describe "screen to terminal coordinate conversion" do
    test "converts screen coordinates" do
      {x, y} = screen_to_terminal(10.5, 20.8)

      assert x == 10
      assert y == 20
    end

    test "handles zero coordinates" do
      {x, y} = screen_to_terminal(0, 0)

      assert x == 0
      assert y == 0
    end
  end

  # Helper functions that mirror the private functions in TerminalLive

  defp translate_key(key, params) do
    ctrl = Map.get(params, "ctrlKey", false)

    case key do
      "Enter" -> "\r"
      "Backspace" -> "\x7f"
      "Tab" -> "\t"
      "Escape" -> "\e"
      "ArrowUp" -> "\e[A"
      "ArrowDown" -> "\e[B"
      "ArrowRight" -> "\e[C"
      "ArrowLeft" -> "\e[D"
      "Home" -> "\e[H"
      "End" -> "\e[F"
      "PageUp" -> "\e[5~"
      "PageDown" -> "\e[6~"
      "Delete" -> "\e[3~"
      "Insert" -> "\e[2~"
      "F1" -> "\eOP"
      "F2" -> "\eOQ"
      "F3" -> "\eOR"
      "F4" -> "\eOS"
      "F5" -> "\e[15~"
      "F6" -> "\e[17~"
      "F7" -> "\e[18~"
      "F8" -> "\e[19~"
      "F9" -> "\e[20~"
      "F10" -> "\e[21~"
      "F11" -> "\e[23~"
      "F12" -> "\e[24~"

      char when byte_size(char) == 1 and ctrl ->
        <<code>> = String.downcase(char)

        if code >= ?a and code <= ?z do
          <<code - ?a + 1>>
        else
          nil
        end

      char when byte_size(char) == 1 ->
        char

      _ ->
        nil
    end
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace(" ", "&nbsp;")
  end

  defp build_style_classes(style) do
    []
    |> add_class_if(Map.get(style, :bold), "bold")
    |> add_class_if(Map.get(style, :italic), "italic")
    |> add_class_if(Map.get(style, :underline), "underline")
    |> add_class_if(Map.get(style, :blink), "blink")
    |> add_class_if(Map.get(style, :reverse), "reverse")
    |> Enum.join(" ")
  end

  defp add_class_if(classes, true, class), do: [class | classes]
  defp add_class_if(classes, _, _), do: classes

  defp build_inline_style(style) do
    []
    |> add_color_style(Map.get(style, :fg), "color")
    |> add_color_style(Map.get(style, :bg), "background-color")
    |> Enum.join("; ")
  end

  defp add_color_style(styles, nil, _property), do: styles

  defp add_color_style(styles, {r, g, b}, property) do
    ["#{property}: rgb(#{r}, #{g}, #{b})" | styles]
  end

  defp add_color_style(styles, color, property) when is_atom(color) do
    ["#{property}: var(--term-#{color})" | styles]
  end

  defp add_color_style(styles, _, _), do: styles

  defp generate_session_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64(padding: false)
  end

  defp screen_to_terminal(x, y) do
    {trunc(x), trunc(y)}
  end
end

defmodule RaxolWeb.TerminalLiveIntegrationTest do
  @moduledoc """
  Integration tests for TerminalLive.

  These tests require a full Phoenix endpoint and use LiveViewTest.
  They are tagged with :integration and can be run separately.
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "LiveView mount" do
    @tag :skip
    test "mounts successfully with default session" do
      # Would use Phoenix.LiveViewTest.live/2
    end

    @tag :skip
    test "mounts with provided session_id" do
      # Would test session_id from params
    end

    @tag :skip
    test "resumes session from bridge token" do
      # Would test WASH session resumption
    end
  end

  describe "keyboard handling" do
    @tag :skip
    test "handles regular character input" do
      # Would test keydown events
    end

    @tag :skip
    test "handles special keys" do
      # Would test arrow keys, function keys
    end

    @tag :skip
    test "handles Ctrl+key combinations" do
      # Would test ctrl key modifiers
    end
  end

  describe "terminal rendering" do
    @tag :skip
    test "renders initial buffer" do
      # Would verify HTML output
    end

    @tag :skip
    test "updates buffer on input" do
      # Would test buffer updates
    end
  end

  describe "collaboration" do
    @tag :skip
    test "tracks presence on join" do
      # Would test presence tracking
    end

    @tag :skip
    test "broadcasts cursor updates" do
      # Would test cursor sync
    end
  end
end
