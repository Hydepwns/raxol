defmodule RaxolWeb.TerminalLiveTest do
  use RaxolWeb.ConnCase, async: true # Keep async: true if tests don't need DB
  import Phoenix.LiveViewTest
  alias RaxolWeb.TerminalLive
  import RaxolWeb.ConnCase # Ensure ConnCase helpers are imported

  # Add setup block for authentication
  setup %{conn: conn} do
    user = %{id: 1, role: :user} # Dummy user
    conn = log_in_user(conn, user) # Use the helper from ConnCase
    {:ok, conn: conn, user: user}
  end

  # Comment out or remove the old bypass_auth helper
  # defp bypass_auth(%{conn: conn}) do
  #   conn =
  #     Plug.Test.init_test_session(conn, %{})
  #     |> fetch_flash()
  #     |> bypass_through(RaxolWeb.Router, :auth)
  #
  #   {:ok, conn: conn}
  # end

  # Remove old setup helpers if they exist
  # setup :start_endpoint # Keep this if endpoint needs starting
  # setup :bypass_auth # Remove this if it exists

  # Helper to bypass auth pipeline
  # defp bypass_auth(context) do
  #   conn = Plug.Test.init_test_session(context.conn, %{})
  #   user = %{id: 1} # Example user
  #   conn = Plug.Conn.assign(conn, :current_user, user)
  #   %{context | conn: conn}
  # end

  describe "mount/3" do
    test "mounts successfully when disconnected", %{conn: conn} do
      # Use the authenticated conn from setup
      {:ok, view, _html} = live(conn, "/terminal/test-session")
      assert view.module == TerminalLive
      assert view.assigns.connected == false
    end

    test "mounts successfully when connected", %{conn: conn} do
      # Use the authenticated conn from setup
      {:ok, view, _html} = live(conn, "/terminal/test-session")
      assert view.module == TerminalLive
      assert view.assigns.session_id
      assert view.assigns.dimensions == %{width: 80, height: 24}
      assert view.assigns.scroll_offset == 0
      assert view.assigns.theme
      # Connect test happens implicitly or via separate setup if needed
    end
  end

  describe "handle_event/3" do
    test "handles connect event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")
      assert view.assigns.connected == false

      send(view.pid, {:connect, %{}})
      assert view.assigns.connected == true
    end

    test "handles terminal output", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      html = "<div>Test output</div>"
      cursor = %{x: 5, y: 0, visible: true}

      send(view.pid, {:terminal_output, %{"html" => html, "cursor" => cursor}})

      assert view.assigns.terminal_html == html
      assert view.assigns.cursor == cursor
    end

    test "handles resize event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      send(view.pid, {:resize, %{"width" => 40, "height" => 12}})

      assert view.assigns.dimensions == %{width: 40, height: 12}
    end

    test "handles scroll event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      send(view.pid, {:scroll, %{"offset" => 10}})

      assert view.assigns.scroll_offset == 10
    end

    test "handles theme event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      theme = %{
        background: "#111111",
        foreground: "#eeeeee",
        cursor: "#ff0000"
      }

      send(view.pid, {:theme, %{"theme" => theme}})

      assert view.assigns.theme == theme
    end

    test "handles disconnect event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")
      send(view.pid, {:connect, %{}})
      assert view.assigns.connected == true

      send(view.pid, {:disconnect, %{}})
      assert view.assigns.connected == false
    end
  end

  describe "render/1" do
    test "renders terminal container", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/terminal/test-session")

      assert html =~ ~r/<div class="terminal-container"/
      assert html =~ ~r/<div class="terminal-header"/
      assert html =~ ~r/<div class="terminal-wrapper"/
      assert html =~ ~r/<div class="terminal-footer"/
    end

    test "renders terminal controls", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/terminal/test-session")

      assert html =~ ~r/<button.*Reset Size/
      assert html =~ ~r/<button.*Dark Theme/
      assert html =~ ~r/<button.*Light Theme/
    end

    test "renders connection status", %{conn: conn} do
      {:ok, view, html} = live(conn, "/terminal/test-session")

      assert html =~ ~r/<span class="status-disconnected"/
      assert html =~ ~r/<button.*Connect/

      send(view.pid, {:connect, %{}})
      html = render(view)

      assert html =~ ~r/<span class="status-connected"/
      refute html =~ ~r/<button.*Connect/
    end

    test "renders terminal dimensions", %{conn: conn} do
      {:ok, view, html} = live(conn, "/terminal/test-session")

      assert html =~ ~r/80x24/

      send(view.pid, {:resize, %{"width" => 40, "height" => 12}})
      html = render(view)

      assert html =~ ~r/40x12/
    end
  end
end
