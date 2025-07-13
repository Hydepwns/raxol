defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  # Use Accounts context
  alias Raxol.Accounts
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences
  alias Raxol.System.Updater
  alias Raxol.Cloud.Config
  import Raxol.Guards

  @impl Phoenix.LiveView
  def mount(%{"token" => _token}, _session, socket) do
    # Assume user_id is in session after login (RaxolWeb.UserAuth likely handles this)
    # Example: Adapt to actual session key
    # Get session data passed from connect_info
    connect_params = get_connect_params(socket)
    # Adjust key if needed
    user_id = connect_params["user_id"]

    case user_id && Accounts.get_user(user_id) do
      user when not nil?(user) ->
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

  @impl Phoenix.LiveView
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

  # Handle messages from child components
  @impl Phoenix.LiveView
  def handle_info({:profile_updated, updated_user}, socket) do
    {:noreply, assign(socket, :current_user, updated_user)}
  end

  @impl Phoenix.LiveView
  def handle_info({:preferences_updated, updated_preferences}, socket) do
    {:noreply, assign(socket, :preferences, updated_preferences)}
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
          />

          <.live_component
            module={RaxolWeb.Settings.PreferencesComponent}
            id="preferences"
            preferences={@preferences}
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
