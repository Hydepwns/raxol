defmodule RaxolWeb.SettingsLiveTest do
  @moduledoc """
  Test module for the SettingsLive LiveView component.
  Tests user settings functionality including profile updates,
  password changes, and authentication requirements.
  """
  use RaxolWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Raxol.Accounts

  setup_all do
    # Start the session manager if not already running
    unless Process.whereis(Raxol.Web.Session.Manager) do
      start_supervised!({Raxol.Web.Session.Manager, []})
    end
    # Start the accounts agent globally if not already running
    unless Process.whereis(Raxol.Accounts) do
      start_supervised!({Raxol.Accounts, []})
    end
    # Register the test user globally
    Accounts.register_user(%{
      email: "test@example.com",
      password: "password123"
    })
    :ok
  end

  describe "Settings page" do
    setup %{conn: conn} do
      # Check if agent is running
      agent_pid = Process.whereis(Raxol.Accounts)
      IO.inspect(agent_pid, label: "Agent PID")

      # Register the test user in the current process
      reg_result = Accounts.register_user(%{
        email: "test@example.com",
        password: "password123"
      })
      IO.inspect(reg_result, label: "register_user result")

      # Check agent state after registration
      agent_state = Agent.get(Raxol.Accounts, fn users -> users end)
      IO.inspect(agent_state, label: "Agent state after registration")

      # Fetch the user by email to get the correct struct and id
      find_result = Accounts.find_user_by_email("test@example.com")
      IO.inspect(find_result, label: "find_user_by_email result")
      {:ok, user} = find_result
      # Log in the user using the conn from ConnCase setup
      conn = log_in_user(conn, user)
      # Create a token for the live view
      token = Phoenix.Token.sign(RaxolWeb.Endpoint, "user socket", user.id)
      %{user: user, conn: conn, token: token}
    end

    test "renders settings page", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, "/settings?token=#{token}")
      assert has_element?(view, "h1", "User Settings")
      assert has_element?(view, "h2", "Profile Information")
      assert has_element?(view, "h2", "Change Password")
    end

    test "updates profile information", %{conn: conn, user: user, token: token} do
      {:ok, view, _html} = live(conn, "/settings?token=#{token}")

      # Fill in the profile form
      view
      |> element("#profile-form")
      |> render_submit(%{
        "user" => %{
          "email" => "updated@example.com",
          "username" => "updated_user"
        }
      })

      # Verify the update was successful
      assert_redirect(view, "/settings")
      {:ok, updated_user} = Accounts.get_user(user.id)
      assert updated_user.email == "updated@example.com"
    end

    test "validates profile information", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, "/settings?token=#{token}")

      # Submit invalid email
      view
      |> element("#profile-form")
      |> render_submit(%{
        "user" => %{
          "email" => "invalid-email",
          "username" => "test_user"
        }
      })

      assert has_element?(view, ".error-message")
    end

    test "changes password", %{conn: conn, user: user, token: token} do
      {:ok, view, _html} = live(conn, "/settings?token=#{token}")

      # Fill in the password form
      view
      |> element("#password-form")
      |> render_submit(%{
        "current_password" => "password123",
        "user" => %{
          "password" => "newpassword123",
          "password_confirmation" => "newpassword123"
        }
      })

      # Verify the password was changed
      assert_redirect(view, "/settings")

      # Try to authenticate with new password
      assert {:ok, _} = Accounts.authenticate_user(user.email, "newpassword123")
    end

    test "validates password change", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, "/settings?token=#{token}")

      # Submit mismatched passwords
      view
      |> element("#password-form")
      |> render_submit(%{
        "current_password" => "password123",
        "user" => %{
          "password" => "newpassword123",
          "password_confirmation" => "differentpassword"
        }
      })

      assert has_element?(view, ".error-message")
    end

    test "requires authentication", %{conn: conn} do
      # Try to access settings page without token
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/settings")
    end
  end
end
