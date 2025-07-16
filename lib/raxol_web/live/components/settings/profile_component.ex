defmodule RaxolWeb.Settings.ProfileComponent do
  @moduledoc """
  Profile component for settings page.
  """

  use RaxolWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="settings-section">
      <h2 class="settings-section-title">Profile Information</h2>
      <form
        id="profile-form"
        phx-submit="update_profile"
        phx-change="validate"
        class="settings-form"
        autocomplete="off"
      >
        <div class="form-group">
          <label for="email">Email</label>
          <input
            type="email"
            name="user[email]"
            value={Ecto.Changeset.get_field(@changeset, :email) || ""}
            required
          />
          <%= if @changeset.errors[:email] do %>
            <div class="error-message">
              <%= elem(@changeset.errors[:email], 0) %>
            </div>
          <% end %>
        </div>
        <div class="form-group">
          <label for="username">Username</label>
          <input
            type="text"
            name="user[username]"
            value={Ecto.Changeset.get_field(@changeset, :username) || ""}
            required
          />
          <%= if @changeset.errors[:username] do %>
            <div class="error-message">
              <%= elem(@changeset.errors[:username], 0) %>
            </div>
          <% end %>
        </div>
        <button type="submit">Update Profile</button>
      </form>
    </div>
    """
  end

  # Only keep the validate event handler
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Raxol.Auth.User.changeset(socket.assigns.current_user, user_params)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end
