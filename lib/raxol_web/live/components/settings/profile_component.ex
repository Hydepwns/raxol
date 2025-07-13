defmodule RaxolWeb.Settings.ProfileComponent do
  use RaxolWeb, :live_component
  alias Raxol.Accounts

  def render(assigns) do
    ~H"""
    <div class="settings-section">
      <h2 class="settings-section-title">Profile Information</h2>
      <.form
        for={@changeset}
        id="profile-form"
        phx-submit="update_profile"
        phx-change="validate"
        phx-target={@myself}
        class="settings-form"
      >
        <.form_group
          name="email"
          label="Email"
          type="email"
          value={@changeset[:email].value}
          required
        />
        <.form_group
          name="username"
          label="Username"
          type="text"
          value={@changeset[:username].value}
          required
        />

        <div class="mt-4">
          <.button type="submit" class="settings-button">
            Update Profile
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    # Sanitize input
    case RaxolWeb.InputSanitizer.sanitize_form_input(user_params, [
           :email,
           :username
         ]) do
      {:ok, sanitized_params} ->
        changeset = Raxol.Auth.User.changeset(user, sanitized_params)

        case Raxol.Repo.update(changeset) do
          {:ok, updated_user} ->
            send(self(), {:profile_updated, updated_user})

            {:noreply,
             socket
             |> put_flash(:info, "Profile updated successfully.")
             |> assign(:changeset, changeset)}

          {:error, changeset} ->
            {:noreply, assign(socket, changeset: changeset)}
        end

      {:error, :invalid_input} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid input detected.")
         |> assign(:changeset, %{errors: [{"email", {"Invalid input", []}}]})}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    changeset = Raxol.Auth.User.changeset(user, user_params)
    {:noreply, assign(socket, changeset: changeset)}
  end
end
