defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  alias Raxol.Auth

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    changeset = Auth.change_user(user)

    {:ok, assign(socket,
      user: user,
      changeset: changeset,
      error: nil,
      success: nil
    )}
  end

  @impl true
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    case Auth.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply, assign(socket,
          user: user,
          changeset: Auth.change_user(user),
          success: "Profile updated successfully",
          error: nil
        )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket,
          changeset: changeset,
          error: "Failed to update profile",
          success: nil
        )}
    end
  end

  @impl true
  def handle_event("update_password", %{"user" => user_params}, socket) do
    case Auth.update_user_password(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply, assign(socket,
          user: user,
          changeset: Auth.change_user(user),
          success: "Password updated successfully",
          error: nil
        )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket,
          changeset: changeset,
          error: "Failed to update password",
          success: nil
        )}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Auth.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end
end 