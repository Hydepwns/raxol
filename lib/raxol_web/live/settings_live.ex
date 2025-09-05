defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  # Use Accounts context
  alias Raxol.Accounts
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences
  alias Raxol.System.Updater
  alias Raxol.Cloud.Config

  @impl Phoenix.LiveView
  def mount(%{"token" => token}, _session, socket) do
    # Validate the token and get user_id
    case Phoenix.Token.verify(RaxolWeb.Endpoint, "user socket", token,
           max_age: 86_400
         ) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          {:ok, user} when not is_nil(user) ->
            # Get user preferences
            preferences = UserPreferences.default_preferences()

            # Get update settings
            update_settings =
              case Updater.default_update_settings() do
                {:ok, settings} -> settings
                settings when is_map(settings) -> settings
                _ -> %{}
              end

            # Get cloud config
            cloud_config = Config.default_config()

            # Create a valid changeset for the user
            changeset = Raxol.Auth.User.changeset(user, %{})

            # Create a password changeset for password updates
            password_changeset = Raxol.Auth.User.changeset(user, %{})

            socket = assign(socket, :current_user, user)
            socket = assign(socket, :changeset, changeset)
            socket = assign(socket, :password_changeset, password_changeset)
            socket = assign(socket, :page_title, "Account Settings")
            socket = assign(socket, :theme, Theme.current())
            socket = assign(socket, :preferences, preferences)
            socket = assign(socket, :preferences_changeset, %{})
            socket = assign(socket, :update_settings, update_settings)
            socket = assign(socket, :cloud_config, cloud_config)
            {:ok, socket}

          {:error, _reason} ->
            updated_socket =
              socket
              |> put_flash(:error, "User not found.")
              |> redirect(to: "/")

            {:ok, updated_socket}
        end

      {:error, _reason} ->
        # Handle case where token is invalid
        updated_socket =
          socket
          |> put_flash(:error, "You must be logged in to access settings.")
          |> redirect(to: "/")

        {:ok, updated_socket}
    end
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # Handle case where no token is provided
    updated_socket =
      socket
      |> put_flash(:error, "You must be logged in to access settings.")
      |> redirect(to: "/")

    {:ok, updated_socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_theme", _params, socket) do
    current_theme = socket.assigns.theme
    new_theme = select_theme(current_theme.id == :dark)

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> put_flash(:info, "Theme updated successfully.")}
  end

  @impl Phoenix.LiveView
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

  @impl Phoenix.LiveView
  def handle_event("update_cloud_config", params, socket) do
    cloud_config = socket.assigns.cloud_config

    # Sanitize input
    case RaxolWeb.InputSanitizer.sanitize_form_input(params, [
           "auto_sync",
           "sync_interval",
           "notifications",
           "error_reporting"
         ]) do
      {:ok, sanitized_params} ->
        # Update cloud config based on form data
        updated_config =
          Map.merge(cloud_config, %{
            "auto_sync" => sanitized_params["auto_sync"] == "true",
            "sync_interval" =>
              String.to_integer(sanitized_params["sync_interval"]),
            "notifications" => sanitized_params["notifications"] == "true",
            "error_reporting" => sanitized_params["error_reporting"] == "true"
          })

        # Save cloud config
        Config.set_config(updated_config)

        {:noreply,
         socket
         |> assign(:cloud_config, updated_config)
         |> put_flash(:info, "Cloud settings updated successfully.")}

      {:error, :invalid_input} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid input detected.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    # Sanitize input
    case RaxolWeb.InputSanitizer.sanitize_form_input(user_params, [
           "email",
           "username"
         ]) do
      {:ok, sanitized_params} when map_size(sanitized_params) > 0 ->
        changeset = Raxol.Auth.User.changeset(user, sanitized_params)
        handle_profile_validation(changeset.valid?, changeset, user, sanitized_params, socket)

      {:ok, _empty_params} ->
        changeset = Raxol.Auth.User.changeset(user, user_params)
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, :invalid_input} ->
        changeset = Raxol.Auth.User.changeset(user, user_params)
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event(
        "update_password",
        %{"current_password" => current_password, "user" => user_params},
        socket
      ) do
    user = socket.assigns.current_user
    new_password = user_params["password"]
    password_confirmation = user_params["password_confirmation"]

    # Validate password confirmation
    handle_password_confirmation(new_password != password_confirmation, user, current_password, new_password, socket)
  end

  # Handle messages from child components
  @impl Phoenix.LiveView
  def handle_info({:profile_updated, updated_user}, socket) do
    {:noreply, assign(socket, :current_user, updated_user)}
  end

  @impl Phoenix.LiveView
  def handle_info(:redirect_after_profile_update, socket) do
    {:noreply, push_navigate(socket, to: "/settings")}
  end

  @impl Phoenix.LiveView
  def handle_info({:password_updated, updated_user}, socket) do
    {:noreply, assign(socket, :current_user, updated_user)}
  end

  @impl Phoenix.LiveView
  def handle_info({:preferences_updated, updated_preferences}, socket) do
    {:noreply, assign(socket, :preferences, updated_preferences)}
  end

  defp select_theme(true) do
    Theme.default_theme()
  end

  defp select_theme(false) do
    Theme.dark_theme()
  end

  defp handle_profile_validation(false, changeset, _user, _sanitized_params, socket) do
    {:noreply, assign(socket, :changeset, changeset)}
  end

  defp handle_profile_validation(true, _changeset, user, sanitized_params, socket) do
    # Update the user in the agent storage
    updated_user = %{
      user
      | email: sanitized_params["email"],
        username: sanitized_params["username"]
    }

    Agent.update(Raxol.Accounts, fn users ->
      Map.put(users, user.email, updated_user)
    end)

    {:noreply,
     push_navigate(
       socket |> put_flash(:info, "Profile updated successfully."),
       to: "/settings"
     )}
  end

  defp handle_password_confirmation(true, _user, _current_password, _new_password, socket) do
    error_changeset = %Ecto.Changeset{
      data: %Raxol.Auth.User{},
      errors: [password_confirmation: {"does not match", []}],
      valid?: false
    }

    {:noreply,
     socket
     |> put_flash(:error, "Password confirmation does not match.")
     |> assign(:password_changeset, error_changeset)}
  end

  defp handle_password_confirmation(false, user, current_password, new_password, socket) do
    # Update password using Accounts module
    case Accounts.update_password(user.id, current_password, new_password) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully.")
         |> push_navigate(to: "/settings")
         |> assign(:current_user, updated_user)}

      {:error, :invalid_current_password} ->
        error_changeset = %Ecto.Changeset{
          data: %Raxol.Auth.User{},
          errors: [current_password: {"is incorrect", []}],
          valid?: false
        }

        {:noreply,
         socket
         |> put_flash(:error, "Current password is incorrect.")
         |> assign(:password_changeset, error_changeset)}

      {:error, changeset} when is_map(changeset) ->
        {:noreply, assign(socket, :password_changeset, changeset)}

      {:error, reason} ->
        error_changeset = %Ecto.Changeset{
          data: %Raxol.Auth.User{},
          errors: [password: {"failed to update", []}],
          valid?: false
        }

        {:noreply,
         socket
         |> put_flash(:error, "Failed to update password: #{inspect(reason)}")
         |> assign(:password_changeset, error_changeset)}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="settings-container">
      <div class="settings-box">
        <h1 class="settings-title">User Settings</h1>

        <.live_component
          module={RaxolWeb.ErrorBoundaryComponent}
          id="settings-error-boundary"
        >
          <.live_component
            module={RaxolWeb.Settings.ProfileComponent}
            id="profile"
            current_user={@current_user}
            changeset={@changeset}
            live_view_pid={self()}
          />

          <.live_component
            module={RaxolWeb.Settings.PasswordComponent}
            id="password"
            current_user={@current_user}
            password_changeset={@password_changeset}
          />

          <.live_component
            module={RaxolWeb.Settings.PreferencesComponent}
            id="preferences"
            preferences={@preferences}
            preferences_changeset={@preferences_changeset}
          />
        </.live_component>

        <!-- Rest of your existing settings content -->
        <div class="settings-section">
          <h2 class="settings-section-title">Theme Settings</h2>
          <button phx-click="toggle_theme" class="settings-button">
            Toggle Theme
          </button>
        </div>

        <div class="settings-section">
          <h2 class="settings-section-title">Update Settings</h2>
          <button phx-click="update_auto_check" phx-value-enabled="true" class="settings-button">
            Enable Auto Updates
          </button>
        </div>
      </div>
    </div>
    """
  end
end
