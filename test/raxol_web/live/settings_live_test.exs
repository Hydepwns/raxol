defmodule RaxolWeb.SettingsLiveTest do
  @moduledoc """
  Test module for the SettingsLive LiveView component.
  Tests user settings functionality including profile updates,
  password changes, and authentication requirements.
  """
  use RaxolWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Raxol.Accounts

  describe "Settings page" do
    setup do
      # Create a test user
      {:ok, user} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123"
        })

      # Log in the user
      conn = build_conn()
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
      updated_user = Accounts.get_user(user.id)
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
      {:ok, view, _html} = live(conn, "/settings")
      assert_redirect(view, "/")
    end
  end
end
