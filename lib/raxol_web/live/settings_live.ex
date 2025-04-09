defmodule RaxolWeb.SettingsLive do
  use RaxolWeb, :live_view
  # alias Raxol.Accounts # Accounts context likely missing

  @impl true
  def mount(%{"token" => _token}, _session, socket) do
    # TODO: Implement user fetching and profile form setup using Accounts context
    # socket
    # |> assign(:current_password, nil)
    # |> assign(:password_confirmation, nil)
    # |> assign_user_and_token(token)
    # |> assign(:changeset, Accounts.change_user(socket.assigns.current_user))
    {:ok, assign(socket, :page_title, "Account Settings"), temporary_assigns: [changeset: nil]}
  end

  @impl true
  def handle_event("update_profile", %{"user" => _user_params}, socket) do
    # TODO: Implement profile update using Accounts context
    # user = socket.assigns.current_user
    #
    # case Accounts.update_user(user, user_params) do
    #   {:ok, user} ->
    #     {:noreply,
    #      socket
    #      |> put_flash(:info, "Profile updated successfully")
    #      |> assign(:changeset, Accounts.change_user(user))
    #      |> assign(:current_user, user)}
    #
    #   {:error, changeset} ->
    #     {:noreply, assign(socket, :changeset, changeset)}
    # end
    {:noreply, put_flash(socket, :error, "Profile update not implemented yet.")}
  end

  @impl true
  def handle_event("update_password", %{"user" => _user_params}, socket) do
    # TODO: Implement password update using Accounts context
    # user = socket.assigns.current_user
    # current_password = user_params["current_password"]
    # user_params = Map.drop(user_params, ["current_password"])
    #
    # case Accounts.update_user_password(user, current_password, user_params) do
    #   {:ok, user} ->
    #     {:noreply,
    #      socket
    #      |> put_flash(:info, "Password updated successfully")
    #      |> assign(:changeset, Accounts.change_user(user, :update_password))
    #      |> assign(:current_password, nil)
    #      |> assign(:password_confirmation, nil)}
    #
    #   {:error, changeset} ->
    #     {:noreply, assign(socket, changeset: changeset)}
    # end
    {:noreply, put_flash(socket, :error, "Password update not implemented yet.")}
  end

  @impl true
  def handle_event("validate", %{"user" => _user_params}, socket) do
    # TODO: Accounts context is unavailable
    # changeset =
    #   socket.assigns.user
    #   |> Accounts.change_user(user_params)
    #   |> Map.put(:action, :validate)
    changeset = Ecto.Changeset.change(socket.assigns.current_user || %Raxol.Auth.User{}) # Use user struct

    {:noreply, assign(socket, changeset: changeset)}
  end

  # defp assign_user_and_token(socket, token) do
  #   case Accounts.get_user_by_session_token(token) do
  #     nil ->
  #       socket
  #       |> put_flash(:error, "Invalid session token. Please log in again.")
  #       |> redirect(to: Routes.user_session_path(socket, :new))

  #     user ->
  #       socket
  #       |> assign(:current_user, user)
  #       |> assign(:token, token)
  #   end
  # end
end
