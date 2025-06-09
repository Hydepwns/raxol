defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  # Use Accounts context
  alias Raxol.Accounts

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
        socket = assign(socket, :current_user, user)

        # Use a simple map for the "changeset" for now, as Accounts doesn't provide one
        # Empty map placeholder
        socket = assign(socket, :changeset, %{})
        socket = assign(socket, :page_title, "Account Settings")
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
    # Assuming nested structure from form
    new_password = params["user"]["password"]
    # password_confirmation = params["user"]["password_confirmation"]

    # Basic validation (add more if needed)
    # Example minimum length
    if is_nil(current_password) or String.length(current_password) == 0 or
         is_nil(new_password) or String.length(new_password) < 6 do
      # if new_password != password_confirmation do ... end
      # Mock changeset error
      changeset = %{
        errors: [password: {"Password update failed validation", []}]
      }

      {:noreply, assign(socket, changeset: changeset)}
    else
      case Accounts.update_password(user.id, current_password, new_password) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "Password updated successfully")
           # Clear password fields on success (how depends on form implementation)
           # Clear mock changeset errors
           |> assign(:changeset, %{})}

        {:error, :invalid_current_password} ->
          # Mock changeset error
          changeset = %{
            errors: [current_password: {"Invalid current password", []}]
          }

          {:noreply, assign(socket, changeset: changeset)}

        {:error, reason} ->
          # Generic error
          # Mock changeset error
          changeset = %{
            errors: [
              password: {"Failed to update password: #{inspect(reason)}", []}
            ]
          }

          {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    changeset = Raxol.Auth.User.changeset(user, user_params)
    {:noreply, assign(socket, changeset: changeset)}
  end
end
