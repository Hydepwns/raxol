defmodule RaxolWeb.PlaygroundLive do
  use Phoenix.LiveView

  @moduledoc """
  A LiveView for a code playground that allows users to write, edit, and run code snippets.
  """

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       code: "",
       language: "elixir",
       output: nil,
       error: nil
     )}
  end

  def handle_event("update_code", %{"code" => code}, socket) do
    {:noreply, assign(socket, code: code)}
  end

  def handle_event("change_language", %{"language" => language}, socket) do
    {:noreply, assign(socket, language: language)}
  end

  def handle_event("run_code", _params, socket) do
    case execute_code(socket.assigns.code, socket.assigns.language) do
      {:ok, output} ->
        {:noreply, assign(socket, output: output, error: nil)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, output: nil)}
    end
  end

  defp execute_code(code, language) do
    case language do
      "elixir" ->
        try do
          result = Code.eval_string(code)
          {:ok, inspect(result)}
        rescue
          e -> {:error, Exception.message(e)}
        end

      _ ->
        {:error, "Unsupported language: #{language}"}
    end
  end

  # Example handle_event, adjust as needed based on original intent
  # def handle_event("new_snippet", %{"code" => _code, "language" => _language}, socket) do
  #   {:noreply, socket}
  # end
end
