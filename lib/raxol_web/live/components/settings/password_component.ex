defmodule RaxolWeb.Settings.PasswordComponent do
  @moduledoc """
  Password change component for settings page.
  """

  use RaxolWeb, :live_component
  alias Raxol.Accounts

  def render(assigns) do
    ~H"""
    <div class="settings-section">
      <h2 class="settings-section-title">Change Password</h2>
      <.form
        for={@password_changeset}
        id="password-form"
        phx-submit="update_password"
        phx-change="validate_password"
        phx-target={@myself}
        class="settings-form"
      >
        <div class="form-group">
          <label for="current_password">Current Password</label>
          <input
            type="password"
            name="current_password"
            id="current_password"
            required
          />
          <%= if @password_changeset.errors[:current_password] do %>
            <div class="error-message">
              <%= elem(@password_changeset.errors[:current_password], 0) %>
            </div>
          <% end %>
        </div>
        <div class="form-group">
          <label for="password">New Password</label>
          <input
            type="password"
            name="user[password]"
            id="password"
            required
          />
          <%= if @password_changeset.errors[:password] do %>
            <div class="error-message">
              <%= elem(@password_changeset.errors[:password], 0) %>
            </div>
          <% end %>
        </div>
        <div class="form-group">
          <label for="password_confirmation">Confirm New Password</label>
          <input
            type="password"
            name="user[password_confirmation]"
            id="password_confirmation"
            required
          />
          <%= if @password_changeset.errors[:password_confirmation] do %>
            <div class="error-message">
              <%= elem(@password_changeset.errors[:password_confirmation], 0) %>
            </div>
          <% end %>
        </div>

        <div class="mt-4">
          <button type="submit" class="settings-button">
            Update Password
          </button>
        </div>
      </.form>
    </div>
    """
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
    case new_password != password_confirmation do
      true ->
        error_changeset = %Ecto.Changeset{
          data: %Raxol.Auth.User{},
          errors: [password_confirmation: {"does not match", []}],
          valid?: false
        }

        {:noreply,
         socket
         |> put_flash(:error, "Password confirmation does not match.")
         |> assign(:password_changeset, error_changeset)}
      false ->
        # Update password using Accounts module
        case Accounts.update_password(user.id, current_password, new_password) do
          {:ok, updated_user} ->
            send(self(), {:password_updated, updated_user})

            {:noreply,
             socket
             |> put_flash(:info, "Password updated successfully.")
             |> redirect(to: "/settings")}

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
              errors: [password: {"update failed", []}],
              valid?: false
            }

            {:noreply,
             socket
             |> put_flash(:error, "Failed to update password: #{inspect(reason)}")
             |> assign(:password_changeset, error_changeset)}
        end
    end
  end

  def handle_event("validate_password", _params, socket) do
    {:noreply, socket}
  end
end
