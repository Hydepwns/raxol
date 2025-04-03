defmodule RaxolWeb.LoginLive do
  use RaxolWeb, :live_view
  alias Raxol.Auth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      username: "",
      password: "",
      error: nil
    )}
  end

  @impl true
  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    case Auth.authenticate_user(username, password) do
      {:ok, session} ->
        {:noreply, 
          socket
          |> put_flash(:info, "Login successful")
          |> redirect(to: "/terminal/#{session.session_id}?token=#{session.token}")
        }
      
      {:error, :invalid_credentials} ->
        {:noreply, assign(socket, 
          error: "Invalid username or password",
          password: ""
        )}
    end
  end

  @impl true
  def handle_event("validate", %{"username" => username, "password" => password}, socket) do
    {:noreply, assign(socket, 
      username: username,
      password: password,
      error: nil
    )}
  end
end 