defmodule RaxolWeb.LoginLive do
  use RaxolWeb, :live_view
  alias Raxol.Accounts

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       username: "",
       password: "",
       error: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "login",
        %{"username" => username, "password" => password},
        socket
      ) do
    case Accounts.authenticate_user(username, password) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Login attempt successful. Redirecting...")
         |> redirect(to: "/")}

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           error: "Invalid username or password",
           password: ""
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(
        "validate",
        %{"username" => username, "password" => password},
        socket
      ) do
    {:noreply,
     assign(socket,
       username: username,
       password: password,
       error: nil
     )}
  end
end
