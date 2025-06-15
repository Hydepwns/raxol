defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  # Use Accounts context
  alias Raxol.Accounts
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences
  alias Raxol.System.Updater
  alias Raxol.Cloud.Config

  @impl true
  def mount(%{"token" => _token}, _session, socket) do
    # Assume user_id is in session after login (RaxolWeb.UserAuth likely handles this)
    # Example: Adapt to actual session key
    # Get session data passed from connect_info
    connect_params = get_connect_params(socket)
    # Adjust key if needed
    user_id = connect_params["user_id"]

    case user_id && Accounts.get_user(user_id) do
      user when not is_nil(user) ->
        # Get user preferences
        preferences = UserPreferences.default_preferences()

        # Get update settings
        {:ok, update_settings} = Updater.default_update_settings()

        # Get cloud config
        cloud_config = Config.default_config()

        socket = assign(socket, :current_user, user)
        socket = assign(socket, :changeset, %{})
        socket = assign(socket, :page_title, "Account Settings")
        socket = assign(socket, :theme, Theme.current())
        socket = assign(socket, :preferences, preferences)
        socket = assign(socket, :update_settings, update_settings)
        socket = assign(socket, :cloud_config, cloud_config)
        {:ok, socket, temporary_assigns: [changeset: nil]}

      nil ->
        # Handle case where user_id is missing or user not found
        updated_socket =
          socket
          |> put_flash(:error, "You must be logged in to access settings.")
          # Redirect to home or login
          |> redirect(to: "/")

        {:stop, :normal, updated_socket}
    end
  end

  @impl true
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    changeset = Raxol.Auth.User.changeset(user, user_params)

    case Raxol.Repo.update(changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> put_flash(:info, "Profile updated successfully.")
         |> assign(:changeset, changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("update_password", params, socket) do
    user = socket.assigns.current_user
    current_password = params["current_password"]
    new_password = params["user"]["password"]
    password_confirmation = params["user"]["password_confirmation"]

    with {:ok, _} <- validate_current_password(current_password),
         {:ok, _} <- validate_new_password(new_password),
         {:ok, _} <-
           validate_password_confirmation(new_password, password_confirmation) do
      update_user_password(socket, user.id, current_password, new_password)
    else
      {:error, field, message, error_text} ->
        {:noreply, create_error_response(socket, field, message, error_text)}
    end
  end

  # Extracted validation functions
  defp validate_current_password(nil),
    do:
      {:error, :current_password, "Current password is required.",
       "Current password is required"}

  defp validate_current_password(""),
    do:
      {:error, :current_password, "Current password is required.",
       "Current password is required"}

  defp validate_current_password(_password), do: {:ok, :valid}

  defp validate_new_password(nil),
    do:
      {:error, :password, "New password must be at least 6 characters.",
       "Password must be at least 6 characters"}

  defp validate_new_password(password) when byte_size(password) < 6,
    do:
      {:error, :password, "New password must be at least 6 characters.",
       "Password must be at least 6 characters"}

  defp validate_new_password(_password), do: {:ok, :valid}

  defp validate_password_confirmation(password, confirmation)
       when password != confirmation,
       do:
         {:error, :password_confirmation, "Passwords do not match.",
          "Passwords do not match"}

  defp validate_password_confirmation(_password, _confirmation),
    do: {:ok, :valid}

  # Handle password update logic
  defp update_user_password(socket, user_id, current_password, new_password) do
    case Accounts.update_password(user_id, current_password, new_password) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully")
         |> assign(:changeset, %{})}

      {:error, :invalid_current_password} ->
        {:noreply,
         create_error_response(
           socket,
           :current_password,
           "Current password is incorrect.",
           "Invalid current password"
         )}

      {:error, reason} ->
        {:noreply,
         create_error_response(
           socket,
           :password,
           "Failed to update password.",
           "Failed to update password: #{inspect(reason)}"
         )}
    end
  end

  # Common error response builder
  defp create_error_response(socket, field, flash_message, error_message) do
    socket
    |> put_flash(:error, flash_message)
    |> assign(:changeset, %{
      errors: [{field, {error_message, []}}]
    })
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    changeset = Raxol.Auth.User.changeset(user, user_params)
    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("toggle_theme", _params, socket) do
    current_theme = socket.assigns.theme

    new_theme =
      if current_theme.id == :dark,
        do: Theme.default_theme(),
        else: Theme.dark_theme()

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> put_flash(:info, "Theme updated successfully.")}
  end

  @impl true
  def handle_event("update_preferences", params, socket) do
    preferences = socket.assigns.preferences

    # Update preferences based on form data
    updated_preferences =
      Map.merge(preferences, %{
        "terminal" => %{
          "font_size" => String.to_integer(params["font_size"]),
          "font_family" => params["font_family"],
          "line_height" => String.to_float(params["line_height"]),
          "cursor_style" => params["cursor_style"],
          "scrollback_size" => String.to_integer(params["scrollback_size"])
        },
        "editor" => %{
          "tab_size" => String.to_integer(params["tab_size"]),
          "insert_spaces" => params["insert_spaces"] == "true",
          "word_wrap" => params["word_wrap"] == "true",
          "line_numbers" => params["line_numbers"] == "true"
        }
      })

    # Save preferences
    UserPreferences.set_preferences(updated_preferences)

    {:noreply,
     socket
     |> assign(:preferences, updated_preferences)
     |> put_flash(:info, "Preferences updated successfully.")}
  end

  @impl true
  def handle_event("update_auto_check", %{"enabled" => enabled}, socket) do
    enabled = enabled == "true"
    Updater.set_auto_check(enabled)

    {:noreply,
     socket
     |> assign(
       :update_settings,
       Map.put(socket.assigns.update_settings, "auto_check", enabled)
     )
     |> put_flash(:info, "Auto-update settings updated successfully.")}
  end

  @impl true
  def handle_event("update_cloud_config", params, socket) do
    cloud_config = socket.assigns.cloud_config

    # Update cloud config based on form data
    updated_config =
      Map.merge(cloud_config, %{
        "auto_sync" => params["auto_sync"] == "true",
        "sync_interval" => String.to_integer(params["sync_interval"]),
        "notifications" => params["notifications"] == "true",
        "error_reporting" => params["error_reporting"] == "true"
      })

    # Save cloud config
    Config.set_config(updated_config)

    {:noreply,
     socket
     |> assign(:cloud_config, updated_config)
     |> put_flash(:info, "Cloud settings updated successfully.")}
  end
end
