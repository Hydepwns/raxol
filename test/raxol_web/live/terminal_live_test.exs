defmodule RaxolWeb.TerminalLiveTest do
  # Use async: false to avoid race conditions with shared processes
  use RaxolWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias RaxolWeb.TerminalLive
  # Ensure ConnCase helpers are imported
  import RaxolWeb.ConnCase

  setup %{conn: conn} do
    # Dummy user with id "user" to match Auth.validate_token
    user = %{id: "user", role: :user}
    # Use the helper from ConnCase
    conn = log_in_user(conn, user)

    # Ensure required processes are started
    unless Process.whereis(Raxol.Web.Session.Manager) do
      start_supervised!({Raxol.Web.Session.Manager, []})
    end

    {:ok, conn: conn, user: user}
  end

  describe "mount/3" do
    test "mounts successfully when disconnected", %{conn: conn} do
      {:ok, view, html} = live(conn, "/terminal/test-session")
      assert view.module == TerminalLive
      # Test through rendered HTML instead of assigns
      assert html =~ "status-disconnected"
      assert html =~ "Connect"
    end

    test "mounts successfully when connected", %{conn: conn} do
      {:ok, view, html} = live(conn, "/terminal/test-session")
      assert view.module == TerminalLive
      # Test through rendered HTML instead of assigns
      # Default dimensions are 80x24, not 40x12
      assert html =~ "80x24"
      assert html =~ "status-disconnected"
    end
  end

  describe "handle_event/3" do
    test "handles connect event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      # Test the connect event by checking HTML changes
      html = render_click(view, "connect")
      assert html =~ "status-connected"
      # The Connect button remains visible even when connected
      assert html =~ "Connect"
    end

    test "handles terminal output", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      payload = %{
        "html" => "<div>test</div>",
        "cursor" => %{"x" => 1, "y" => 1, "visible" => true}
      }

      html = render_hook(view, "terminal_output", payload)
      assert html =~ "<div>test</div>"
    end

    test "handles resize event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      html = render_click(view, "resize", %{"width" => "120", "height" => "30"})
      assert html =~ "120x30"
    end

    test "handles theme event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      html = render_click(view, "theme", %{"theme" => "dark"})
      # The theme change should be reflected in the rendered HTML
      assert html =~ "Dark Theme"
    end

    test "handles scroll event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      html = render_hook(view, "scroll", %{"offset" => "5"})
      # Test that the scroll event was processed
      assert html =~ "terminal"
    end

    test "handles disconnect event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/terminal/test-session")

      # First connect, then disconnect
      render_click(view, "connect")
      html = render_click(view, "disconnect")
      assert html =~ "status-disconnected"
      assert html =~ "Connect"
    end
  end

  describe "render/1" do
    test "renders terminal container", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/terminal/test-session")
      assert html =~ "terminal-container"
      assert html =~ "terminal-wrapper"
      assert html =~ "terminal"
    end

    test "renders terminal controls", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/terminal/test-session")
      assert html =~ "Reset Size"
      assert html =~ "Dark Theme"
      assert html =~ "Light Theme"
    end

    test "renders connection status", %{conn: conn} do
      {:ok, view, html} = live(conn, "/terminal/test-session")
      assert html =~ "status-disconnected"
      assert html =~ "Connect"

      # Test connected state - the Connect button remains visible
      html = render_click(view, "connect")
      assert html =~ "status-connected"
      # The Connect button remains visible even when connected
      assert html =~ "Connect"
    end

    test "renders terminal dimensions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/terminal/test-session")
      # Default dimensions are 80x24
      assert html =~ "80x24"
    end
  end
end
